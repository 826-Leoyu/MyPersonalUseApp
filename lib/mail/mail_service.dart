import 'dart:math';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../planner/planner_exceptions.dart';
import '../storage/planner_database.dart';
import 'export_parser.dart';
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

/// 邮件业务门面。和 `PlannerService` 共用同一个数据库，每个写操作是一个事务。
///
/// 日志里只能出现邮件的内部 id、文件名、状态和错误类型，不能出现主题、
/// 发件人和正文（spec 0002"日志与隐私"）。
class MailService {
  MailService({
    required PlannerDatabase database,
    this._clock = const Clock(),
    String Function()? generateId,
  }) : _db = database,
       _generateId = generateId ?? const Uuid().v4;

  static const _mailboxAddressKey = 'mailboxAddress';

  final PlannerDatabase _db;
  final Clock _clock;
  final String Function() _generateId;

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
    return _write(
      () => _import(
        batch,
        fileName: fileName,
        contentHash: sha256.convert(bytes).toString(),
        fileSize: bytes.length,
        fileModifiedAt: stat.modified.toUtc().millisecondsSinceEpoch,
      ),
    );
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
              // HTML 转文本以后再做（#84），这一步先原样保存。
              bodyText: Value(mail.body.isEmpty ? null : mail.body),
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
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          MailPreview(
            id: row.id,
            subject: row.subject,
            senderName: row.senderName,
            senderAddress: row.senderAddress,
            receivedAt: switch (row.receivedAt) {
              final at? => DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
              null => null,
            },
          ),
      ],
    );
  }

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
