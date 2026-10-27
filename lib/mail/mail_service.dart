import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../planner/card_time.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import '../storage/planner_database.dart';
import 'body_text.dart';
import 'export_parser.dart';
import 'mail_analyzer.dart';
import 'mail_items.dart';
import 'mail_preview.dart';
import 'mail_states.dart';

/// 导入一个导出文件的结果。
sealed class ImportOutcome {
  const ImportOutcome(this.fileName);

  final String fileName;
}

/// 文件里的新邮件都入库了。
class Imported extends ImportOutcome {
  const Imported(
    super.fileName, {
    required this.mailCount,
    required this.newMailCount,
    required this.skippedCount,
  });

  /// 文件里有邮件键的邮件数。
  final int mailCount;

  /// 其中以前没有、这次新入库的邮件数。
  final int newMailCount;

  /// 缺少邮件键、被跳过的邮件数。
  final int skippedCount;
}

/// 同样内容的文件以前导入过，什么都没做。
class AlreadyImported extends ImportOutcome {
  const AlreadyImported(super.fileName);
}

/// 裸数组格式，设置里又没有邮箱地址：文件记为 `needsMailbox`，邮件不入库。
class NeedsMailbox extends ImportOutcome {
  const NeedsMailbox(super.fileName);
}

/// 文件格式错误，数据库不变。
class InvalidFile extends ImportOutcome {
  const InvalidFile(super.fileName, this.error);

  final ExportFormatError error;
}

/// 文件读不出来，数据库不变。
class UnreadableFile extends ImportOutcome {
  const UnreadableFile(super.fileName);
}

/// 邮件业务门面。和 [PlannerService] 共用同一个数据库，每个写操作是一个事务。
///
/// 日志里只能出现邮件的内部 id、文件名、状态和错误类型，不能出现主题、
/// 发件人和正文（spec 0002"日志与隐私"）。
class MailService {
  /// 没有分析器时邮件只入库，不分析。[timeZoneName] 是发给分析器的
  /// 时区名字，默认取系统的。
  MailService({
    required PlannerService planner,
    this._analyzer,
    this._clock = const Clock(),
    String Function()? generateId,
    String Function()? timeZoneName,
  }) : _planner = planner,
       _db = planner.database,
       _generateId = generateId ?? const Uuid().v4,
       _timeZoneName = timeZoneName ?? (() => clock.now().timeZoneName);

  static const _mailboxAddressKey = 'mailboxAddress';

  /// "可能相关的现有事项"里，不在同一讨论的事项最多看多久以前的。
  static const relatedItemWindow = Duration(days: 30);

  /// "可能相关的现有事项"最多给多少条。
  static const maxRelatedItems = 50;

  final PlannerService _planner;
  final PlannerDatabase _db;
  final MailAnalyzer? _analyzer;
  final Clock _clock;
  final String Function() _generateId;
  final String Function() _timeZoneName;

  /// 手动选择一个导出文件导入。走和自动扫描一样的解析和入库规则，但不检查
  /// 文件名和文件是否稳定。
  ///
  /// 格式错误、读不出来时数据库不变；写入失败时抛出 [StorageFailure]，
  /// 事务整体回滚，再导入一次能完整成功。
  Future<ImportOutcome> importFile(String path) async {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final List<int> bytes;
    final FileStat stat;
    try {
      final file = File(path);
      bytes = await file.readAsBytes();
      stat = await file.stat();
    } on FileSystemException {
      return UnreadableFile(fileName);
    }
    final ExportBatch batch;
    try {
      batch = parseExport(bytes);
    } on InvalidExportFile catch (e) {
      return InvalidFile(fileName, e.error);
    }
    final outcome = await _write(
      () => _import(
        batch,
        fileName: fileName,
        contentHash: sha256.convert(bytes).toString(),
        fileSize: bytes.length,
        fileModifiedAt: stat.modified.toUtc().millisecondsSinceEpoch,
      ),
    );
    // 新入库的邮件自动分析（M-13），不等分析结束。
    if (outcome case Imported(newMailCount: > 0)) unawaited(analyzePending());
    return outcome;
  }

  Future<ImportOutcome> _import(
    ExportBatch batch, {
    required String fileName,
    required String contentHash,
    required int fileSize,
    required int fileModifiedAt,
  }) async {
    final existing = await (_db.select(
      _db.mailExportFiles,
    )..where((f) => f.contentHash.equals(contentHash))).getSingleOrNull();
    if (existing?.status == MailExportFileStatus.imported) {
      return AlreadyImported(fileName);
    }
    final now = _nowMillis;
    final fileId = existing?.id ?? _generateId();
    final fileRow = MailExportFilesCompanion(
      id: Value(fileId),
      fileName: Value(fileName),
      fileSize: Value(fileSize),
      fileModifiedAt: Value(fileModifiedAt),
      contentHash: Value(contentHash),
      exportedAt: Value(batch.exportedAt?.millisecondsSinceEpoch),
      firstSeenAt: Value(existing?.firstSeenAt ?? now),
    );
    final mailbox = batch.mailbox ?? await _mailboxAddress();
    if (mailbox == null) {
      await _db
          .into(_db.mailExportFiles)
          .insertOnConflictUpdate(
            fileRow.copyWith(
              status: const Value(MailExportFileStatus.needsMailbox),
            ),
          );
      return NeedsMailbox(fileName);
    }

    // 新邮件：数据库里没有的，并且同一个文件里重复出现的只算第一次。
    final keys = {for (final mail in batch.mails) mail.key};
    final known = await _knownKeys(mailbox, keys);
    final newMails = <ExportedMail>[];
    for (final mail in batch.mails) {
      if (known.add(mail.key)) newMails.add(mail);
    }

    final received = [
      for (final mail in batch.mails)
        if (mail.receivedAt case final at?) at.millisecondsSinceEpoch,
    ]..sort();
    await _db
        .into(_db.mailExportFiles)
        .insertOnConflictUpdate(
          fileRow.copyWith(
            status: const Value(MailExportFileStatus.imported),
            mailbox: Value(mailbox),
            earliestReceivedAt: Value(received.firstOrNull),
            latestReceivedAt: Value(received.lastOrNull),
            mailCount: Value(batch.mails.length),
            newMailCount: Value(newMails.length),
            skippedCount: Value(batch.skippedCount),
            importedAt: Value(now),
          ),
        );
    for (final mail in newMails) {
      await _db
          .into(_db.mails)
          .insert(
            MailsCompanion.insert(
              id: _generateId(),
              mailbox: mailbox,
              mailKey: mail.key,
              mailKeyKind: mail.keyKind,
              outlookId: Value(mail.outlookId),
              conversationId: Value(mail.conversationId),
              subject: mail.subject,
              senderName: Value(mail.senderName),
              senderAddress: Value(mail.senderAddress),
              receivedAt: Value(mail.receivedAt?.millisecondsSinceEpoch),
              importance: Value(mail.importance),
              hasAttachments: Value(mail.hasAttachments),
              hasInlineImages: Value(mail.body.hasInlineImages),
              bodyText: Value(mail.body.text),
              bodyPossiblyIncomplete: Value(mail.body.possiblyIncomplete),
              links: Value(_encodeLinks(mail.body.links)),
              analysisStatus: MailAnalysisStatus.pending,
              sourceFileId: fileId,
              importedAt: now,
            ),
          );
    }
    return Imported(
      fileName,
      mailCount: batch.mails.length,
      newMailCount: newMails.length,
      skippedCount: batch.skippedCount,
    );
  }

  /// [keys] 里已经在 [mailbox] 里入库的邮件键。
  Future<Set<String>> _knownKeys(String mailbox, Set<String> keys) async {
    final known = <String>{};
    // SQLite 一条语句的参数个数有上限，分批查。
    final list = keys.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, min(i + 500, list.length));
      final rows =
          await (_db.selectOnly(_db.mails)
                ..addColumns([_db.mails.mailKey])
                ..where(
                  _db.mails.mailbox.equals(mailbox) &
                      _db.mails.mailKey.isIn(chunk),
                ))
              .get();
      known.addAll(rows.map((r) => r.read(_db.mails.mailKey)!));
    }
    return known;
  }

  // ---- 分析 ----

  Future<void>? _analysisRun;
  bool _analyzeAgain = false;

  /// 分析所有待分析的邮件：一次一封，收件时间新的在前。正在分析时不另开
  /// 一轮，返回正在进行的这一轮，它结束前会再看一遍有没有新的待分析邮件。
  ///
  /// 一封失败不影响其他邮件，失败的邮件还是待分析，这一轮里不再重试。
  /// 未安装、未登录、额度用完时后面的邮件也会失败，这一轮直接停下。
  /// 读写数据库失败时也停下，邮件保持待分析。不会抛出异常。
  Future<void> analyzePending() {
    if (_analyzer == null) return Future.value();
    if (_analysisRun case final running?) {
      _analyzeAgain = true;
      return running;
    }
    return _analysisRun = _analyzeAll().whenComplete(() => _analysisRun = null);
  }

  Future<void> _analyzeAll() async {
    final tried = <String>{};
    try {
      do {
        _analyzeAgain = false;
        while (true) {
          final mail = await _read(() => _nextPending(tried));
          if (mail == null) break;
          tried.add(mail.id);
          if (!await _analyzeOne(mail)) return;
        }
      } while (_analyzeAgain);
    } catch (_) {
      // 读写数据库失败，或者分析期间数据库被关掉了：邮件保持待分析，下一轮
      // 再来。这一轮在后台运行，没有人等它的结果，所以什么错误都不往外抛。
    }
  }

  /// 等正在进行的这一轮分析结束；没有在分析时马上完成。关闭数据库前调用。
  Future<void> waitForAnalysis() => _analysisRun ?? Future.value();

  Future<MailRow?> _nextPending(Set<String> tried) =>
      (_db.select(_db.mails)
            ..where(
              (m) =>
                  m.analysisStatus.equalsValue(MailAnalysisStatus.pending) &
                  m.id.isNotIn(tried),
            )
            ..orderBy([
              (m) => OrderingTerm(
                expression: m.receivedAt,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
              (m) => OrderingTerm.asc(m.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// 分析一封邮件并保存结果。返回这一轮要不要接着分析下一封。
  Future<bool> _analyzeOne(MailRow mail) async {
    final request = await _read(() => _requestFor(mail));
    final AnalysisResult result;
    try {
      result = await _analyzer!.analyze(request);
    } on AnalysisFailed catch (e) {
      await _write(() => _saveFailure(mail.id, e.type));
      return switch (e.type) {
        AnalysisFailureType.notInstalled ||
        AnalysisFailureType.notLoggedIn ||
        AnalysisFailureType.quotaExhausted => false,
        AnalysisFailureType.invalidOutput ||
        AnalysisFailureType.temporary => true,
      };
    } on Exception {
      await _write(() => _saveFailure(mail.id, AnalysisFailureType.temporary));
      return true;
    }
    await _write(() => _saveAnalysis(mail, result));
    return true;
  }

  Future<AnalysisRequest> _requestFor(MailRow mail) async => AnalysisRequest(
    subject: mail.subject,
    senderName: mail.senderName,
    senderAddress: mail.senderAddress,
    receivedAt: _fromMillis(mail.receivedAt)?.toLocal(),
    importance: mail.importance,
    bodyText: mail.bodyText,
    links: _decodeLinks(mail.links),
    hasAttachments: mail.hasAttachments,
    hasInlineImages: mail.hasInlineImages,
    bodyPossiblyIncomplete: mail.bodyPossiblyIncomplete,
    timeZone: _timeZoneName(),
    relatedItems: await _relatedItems(mail),
    markedUseful: mail.markedUseful,
  );

  /// 可能相关的现有事项：同一讨论里已经生成的所有事项，加上最近 30 天由
  /// 邮件生成、还没完成的事项（候选，或者卡片还在画布上没完成）。
  Future<List<RelatedItem>> _relatedItems(MailRow mail) async {
    final since = _nowMillis - relatedItemWindow.inMilliseconds;
    final items = _db.mailItems;
    final cards = _db.taskCards;
    final sameConversation = switch (mail.conversationId) {
      final id? => items.conversationId.equals(id),
      null => const Constant(false),
    };
    final rows =
        await (_db.select(items).join([
                leftOuterJoin(cards, cards.id.equalsExp(items.cardId)),
              ])
              ..where(
                sameConversation |
                    (items.createdAt.isBiggerOrEqualValue(since) &
                        items.status.isNotValue(MailItemStatus.ignored.name)),
              )
              ..orderBy([OrderingTerm.desc(items.createdAt)]))
            .get();
    final related = <RelatedItem>[];
    for (final row in rows) {
      final item = row.readTable(items);
      final card = row.readTableOrNull(cards);
      final open = switch (item.status) {
        MailItemStatus.candidate => true,
        MailItemStatus.accepted =>
          card != null &&
              card.status == CardStatus.active &&
              card.deletedAt == null,
        MailItemStatus.ignored => false,
      };
      if (!open && item.conversationId != mail.conversationId) continue;
      related.add(
        RelatedItem(
          id: item.id,
          title: item.title,
          eventTime: _itemEventTime(item),
          dueTime: _itemDueTime(item),
          status: item.status,
        ),
      );
      if (related.length == maxRelatedItems) break;
    }
    return related;
  }

  Future<void> _saveFailure(String mailId, AnalysisFailureType type) async {
    final mail = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(mailId))).getSingle();
    await (_db.update(_db.mails)..where((m) => m.id.equals(mailId))).write(
      MailsCompanion(
        analysisFailureType: Value(type.name),
        analysisFailureCount: Value(mail.analysisFailureCount + 1),
      ),
    );
  }

  /// 保存分析结果。需要行动和可选活动的事项成为候选事项。
  ///
  /// 结果里引用现有事项的更新（`updates`）现在也先当作新的候选，记下相关
  /// 事项；按事项状态处理更新的规则在 #88。
  Future<void> _saveAnalysis(MailRow mail, AnalysisResult result) async {
    final now = _nowMillis;
    final updated =
        await (_db.update(_db.mails)..where(
              (m) =>
                  m.id.equals(mail.id) &
                  m.analysisStatus.equalsValue(MailAnalysisStatus.pending),
            ))
            .write(
              MailsCompanion(
                analysisStatus: const Value(MailAnalysisStatus.done),
                analysisFailureType: const Value(null),
                category: Value(result.category.name),
                categoryReason: Value(result.reason),
                analyzedAt: Value(now),
              ),
            );
    // 分析期间这封邮件已经不是待分析了：不重复生成事项。
    if (updated == 0 || !result.category.producesCandidates) return;
    for (final item in result.items) {
      final event = cardTimeToColumns(item.eventTime);
      final due = cardTimeToColumns(item.dueTime);
      await _db
          .into(_db.mailItems)
          .insert(
            MailItemsCompanion.insert(
              id: _generateId(),
              mailId: mail.id,
              conversationId: Value(mail.conversationId),
              title: item.title,
              summary: Value(item.summary),
              actions: Value(
                item.actions.isEmpty ? null : jsonEncode(item.actions),
              ),
              location: Value(item.location),
              linkRefs: Value(
                item.linkRefs.isEmpty ? null : jsonEncode(item.linkRefs),
              ),
              eventTime: Value(event.value),
              eventTimePrecision: Value(event.precision),
              eventTimePending: Value(event.pending),
              dueTime: Value(due.value),
              dueTimePrecision: Value(due.precision),
              dueTimePending: Value(due.pending),
              optional: Value(item.optional),
              hasUnanalyzedAttachments: Value(item.unanalyzedAttachments),
              status: MailItemStatus.candidate,
              relatedItemId: Value(item.updates),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  // ---- 候选事项、加入和忽略 ----

  /// "新邮件事项"栏里的候选事项：需要行动在前，可选活动在后；同类里按截止
  /// 时间（没有时看活动时间）从近到远，没有时间的排在最后。
  Stream<List<MailItemCandidate>> watchCandidates() {
    final items = _db.mailItems;
    final mails = _db.mails;
    final query = _db.select(items).join([
      innerJoin(mails, mails.id.equalsExp(items.mailId)),
    ])..where(items.status.equalsValue(MailItemStatus.candidate));
    return query.watch().map((rows) {
      final entries = [
        for (final row in rows)
          (item: row.readTable(items), mail: row.readTable(mails)),
      ];
      entries.sort((a, b) {
        if (a.item.optional != b.item.optional) return a.item.optional ? 1 : -1;
        final byTime = switch ((_sortTime(a.item), _sortTime(b.item))) {
          (final x?, final y?) => x.compareTo(y),
          (_?, null) => -1,
          (null, _?) => 1,
          (null, null) => 0,
        };
        if (byTime != 0) return byTime;
        final byCreated = a.item.createdAt.compareTo(b.item.createdAt);
        return byCreated != 0 ? byCreated : a.item.id.compareTo(b.item.id);
      });
      return [
        for (final (:item, :mail) in entries)
          MailItemCandidate(
            id: item.id,
            title: item.title,
            summary: item.summary,
            actions: _itemActions(item),
            location: item.location,
            links: _itemLinks(item, _decodeLinks(mail.links)),
            eventTime: _itemEventTime(item),
            dueTime: _itemDueTime(item),
            optional: item.optional,
            // 邮件有附件或图片时一律提示，不只看分析结果。
            hasUnanalyzedAttachments:
                item.hasUnanalyzedAttachments ||
                mail.hasAttachments ||
                mail.hasInlineImages,
            mailId: mail.id,
            mailSubject: _preview(mail).displaySubject,
            sender: _preview(mail).displaySender,
            receivedAt: _fromMillis(mail.receivedAt),
          ),
      ];
    });
  }

  /// 排序用的时间：截止时间，没有时用活动时间；只有日期时取那天 0 点。
  static DateTime? _sortTime(MailItemRow item) {
    final time = _itemDueTime(item) ?? _itemEventTime(item);
    if (time?.time case final at?) return at;
    if (time?.day case final day?) {
      return DateTime(day.year, day.month, day.day);
    }
    return null;
  }

  /// [加入]：把候选事项变成 [day] 画布上 ([x], [y]) 处的一张卡片。新建卡片
  /// 和事项状态在同一个事务里，任何一步失败都整体回滚，事项还是候选（M-17）。
  ///
  /// [day] 是过去的日子、事项已经不是候选时抛出 [InvalidState]。
  Future<TaskCard> acceptItem(
    String itemId, {
    required DayKey day,
    required double x,
    required double y,
  }) => _write(() async {
    final item = await _requireCandidate(itemId);
    final mail = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(item.mailId))).getSingle();
    final card = await _planner.createCardInTransaction(
      day,
      x: x,
      y: y,
      title: _truncate(item.title, PlannerService.maxTitleLength),
      note: _cardNote(item, _decodeLinks(mail.links)),
      times: (event: _itemEventTime(item), due: _itemDueTime(item)),
    );
    await (_db.update(_db.mailItems)..where((i) => i.id.equals(itemId))).write(
      MailItemsCompanion(
        status: const Value(MailItemStatus.accepted),
        cardId: Value(card.id),
        updatedAt: Value(_nowMillis),
      ),
    );
    return card;
  });

  /// [忽略]：事项从栏里消失。事项已经不是候选时抛出 [InvalidState]。
  Future<void> ignoreItem(String itemId) => _write(() async {
    await _requireCandidate(itemId);
    await (_db.update(_db.mailItems)..where((i) => i.id.equals(itemId))).write(
      MailItemsCompanion(
        status: const Value(MailItemStatus.ignored),
        updatedAt: Value(_nowMillis),
      ),
    );
  });

  /// 事项现在的状态；没有这个事项时为 null。
  Future<MailItemStatus?> itemStatus(String itemId) => _read(() async {
    final item = await (_db.select(
      _db.mailItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    return item?.status;
  });

  /// 由邮件事项加入的卡片的 id，给卡片上的信封图标用。
  Stream<Set<String>> watchMailCardIds() {
    final query = _db.selectOnly(_db.mailItems)
      ..addColumns([_db.mailItems.cardId])
      ..where(_db.mailItems.cardId.isNotNull());
    return query.watch().map(
      (rows) => {for (final row in rows) row.read(_db.mailItems.cardId)!},
    );
  }

  /// 卡片的来源邮件的 id；不是从邮件来的卡片为 null。
  Future<String?> sourceMailOfCard(String cardId) => _read(() async {
    final item =
        await (_db.select(_db.mailItems)
              ..where((i) => i.cardId.equals(cardId))
              ..limit(1))
            .getSingleOrNull();
    return item?.mailId;
  });

  Future<MailItemRow> _requireCandidate(String itemId) async {
    final item = await (_db.select(
      _db.mailItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) throw NotFound('找不到事项 $itemId');
    if (item.status != MailItemStatus.candidate) {
      throw const InvalidState('这个事项已经处理过了');
    }
    return item;
  }

  /// 卡片的备注：依次是摘要、要做的事、地点、第一个链接；都没有时为 null。
  static String? _cardNote(MailItemRow item, List<String> links) {
    final lines = [
      ?item.summary,
      for (final action in _itemActions(item)) '- $action',
      if (item.location case final location?) '地点：$location',
      ?_itemLinks(item, links).firstOrNull,
    ];
    if (lines.isEmpty) return null;
    return _truncate(lines.join('\n'), PlannerService.maxNoteLength);
  }

  /// 事项要做的事。
  static List<String> _itemActions(MailItemRow item) => switch (item.actions) {
    final json? => (jsonDecode(json) as List<Object?>).cast<String>(),
    null => const [],
  };

  /// 事项引用的链接，按引用的顺序；[links] 是邮件的链接列表。
  static List<String> _itemLinks(MailItemRow item, List<String> links) {
    final refs = switch (item.linkRefs) {
      final json? => (jsonDecode(json) as List<Object?>).cast<int>(),
      null => const <int>[],
    };
    return [
      for (final ref in refs)
        if (ref >= 1 && ref <= links.length) links[ref - 1],
    ];
  }

  static String _truncate(String text, int maxCharacters) {
    final characters = text.characters;
    return characters.length <= maxCharacters
        ? text
        : characters.take(maxCharacters).toString();
  }

  static CardTime? _itemEventTime(MailItemRow item) => cardTimeFromColumns(
    item.eventTime,
    item.eventTimePrecision,
    item.eventTimePending,
  );

  static CardTime? _itemDueTime(MailItemRow item) => cardTimeFromColumns(
    item.dueTime,
    item.dueTimePrecision,
    item.dueTimePending,
  );

  static DateTime? _fromMillis(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  // ---- 邮件预览 ----

  /// 已入库的邮件，收件时间最新的在前；没有收件时间的排在最后。
  Stream<List<MailPreview>> watchMails() {
    final query = _db.select(_db.mails)
      ..orderBy([
        (m) => OrderingTerm(
          expression: m.receivedAt,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (m) => OrderingTerm.asc(m.id),
      ]);
    return query.watch().map((rows) => [for (final row in rows) _preview(row)]);
  }

  /// 一封邮件的正文和链接；没有这封邮件时为 null。
  Future<MailDetail?> mailDetail(String id) => _read(() async {
    final row = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return MailDetail(
      preview: _preview(row),
      body: MailBody(
        text: row.bodyText,
        links: _decodeLinks(row.links),
        hasInlineImages: row.hasInlineImages,
        possiblyIncomplete: row.bodyPossiblyIncomplete,
      ),
    );
  });

  MailPreview _preview(MailRow row) => MailPreview(
    id: row.id,
    subject: row.subject,
    senderName: row.senderName,
    senderAddress: row.senderAddress,
    receivedAt: _fromMillis(row.receivedAt),
  );

  /// 设置里的邮箱地址，没有填写时为 null。
  Future<String?> mailboxAddress() => _read(_mailboxAddress);

  Future<String?> _mailboxAddress() async {
    final row = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(_mailboxAddressKey))).getSingleOrNull();
    return row?.value;
  }

  /// 修改设置里的邮箱地址；为 null 或空白时清空。保存规范形式
  /// （见 [normalizeMailbox]）。格式不对时抛出 [InvalidInput]。
  Future<void> setMailboxAddress(String? address) async {
    final clean = address == null || address.trim().isEmpty
        ? null
        : normalizeMailbox(address);
    if (clean != null && !RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(clean)) {
      throw const InvalidInput('邮箱地址格式不对');
    }
    await _write(() async {
      if (clean == null) {
        await (_db.delete(
          _db.appMeta,
        )..where((m) => m.key.equals(_mailboxAddressKey))).go();
      } else {
        await _db
            .into(_db.appMeta)
            .insertOnConflictUpdate(
              AppMetaCompanion.insert(key: _mailboxAddressKey, value: clean),
            );
      }
    });
  }

  Future<T> _read<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Exception catch (e) {
      throw StorageFailure('读取失败', e);
    }
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await _db.transaction(action);
    } on PlannerException {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('保存失败', e);
    }
  }

  int get _nowMillis => _clock.now().toUtc().millisecondsSinceEpoch;
}

/// 邮件的链接列存成 URL 的 JSON 数组；没有链接时为 null。
String? _encodeLinks(List<String> links) =>
    links.isEmpty ? null : jsonEncode(links);

List<String> _decodeLinks(String? json) => switch (json) {
  final json? => (jsonDecode(json) as List<Object?>).cast<String>(),
  null => const [],
};
