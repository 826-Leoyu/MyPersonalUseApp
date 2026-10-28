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
import 'export_source.dart';
import 'import_status.dart';
import 'item_changes.dart';
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
    ExportSource Function(String folder)? openFolder,
  }) : _planner = planner,
       _openFolder = openFolder ?? DirectoryExportSource.new,
       _db = planner.database,
       _generateId = generateId ?? const Uuid().v4,
       _timeZoneName = timeZoneName ?? (() => clock.now().timeZoneName);

  static const _mailboxAddressKey = 'mailboxAddress';
  static const _mailFolderKey = 'mailFolder';
  static const _mailFolderChosenAtKey = 'mailFolderChosenAt';
  static const _lastImportAtKey = 'lastImportAt';
  static const _lastImportNewMailsKey = 'lastImportNewMails';
  static const _firstSetupAtKey = 'mailFirstSetupAt';
  static const _autoAnalysisDayKey = 'autoAnalysisDay';
  static const _autoAnalysisCountKey = 'autoAnalysisCount';
  static const _autoAnalysisResumedDayKey = 'autoAnalysisResumedDay';

  /// 云端流程每次导出多少封（流程里的 Top）。文件里正好这么多封时算满的。
  static const exportBatchSize = 200;

  /// 首次设置时只自动分析这么久以内收到的邮件，更早的不自动分析。
  static const firstSetupLookback = Duration(days: 14);

  /// 导入以后多久删除导出文件。
  static const keepExportFilesFor = Duration(days: 14);

  /// 多久没有新的导出文件就提醒检查流程。
  static const noNewFilesAfter = Duration(days: 2);

  /// "可能相关的现有事项"里，不在同一讨论的事项最多看多久以前的。
  static const relatedItemWindow = Duration(days: 30);

  /// "可能相关的现有事项"最多给多少条。
  static const maxRelatedItems = 50;

  /// 每个本地日最多自动分析多少封。手动重试不算。
  static const dailyAutoAnalysisLimit = 100;

  /// 输出格式不对累计多少次以后标为失败。
  static const maxInvalidOutputs = 3;

  /// 邮件正文已经清除时的提示。
  static const bodyClearedMessage = '原文已清理，请在 Outlook 中查看';

  final PlannerService _planner;
  final PlannerDatabase _db;
  final MailAnalyzer? _analyzer;
  final Clock _clock;
  final String Function() _generateId;
  final String Function() _timeZoneName;
  final ExportSource Function(String folder) _openFolder;

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
    final outcome = await _importBytes(
      bytes,
      fileName: fileName,
      fileModifiedAt: stat.modified.toUtc().millisecondsSinceEpoch,
    );
    // 导入了文件就分析新入库的邮件（M-13），也重试之前失败的，不等分析结束。
    if (outcome is Imported) unawaited(analyzePending());
    return outcome;
  }

  /// [scanRow] 是扫描邮件文件夹时这个文件的那一行；手动导入时为 null。
  Future<ImportOutcome> _importBytes(
    List<int> bytes, {
    required String fileName,
    required int fileModifiedAt,
    MailExportFileRow? scanRow,
  }) async {
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
        fileModifiedAt: fileModifiedAt,
        scanRow: scanRow,
      ),
    );
  }

  // ---- 邮件文件夹 ----

  /// 设置里的邮件文件夹，没有选择时为 null。
  Future<String?> mailFolder() => _read(() => _meta(_mailFolderKey));

  /// 检查 [path] 能不能作为邮件文件夹，不改动任何东西。
  Future<FolderCheck> checkFolder(String path) async {
    final List<ExportFileInfo> files;
    try {
      files = await _openFolder(path).list();
    } on ExportFolderUnavailable {
      return const FolderUnavailable();
    }
    return FolderFound(
      fileCount: files.length,
      latestFileAt: files
          .map((f) => f.modifiedAt)
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
    );
  }

  /// 选择邮件文件夹。路径只存在本机的数据库里。
  ///
  /// 换了文件夹时，旧文件夹里还没导入的文件和格式错误的文件不再记着；导入
  /// 过的文件留着去重和检查空档用，但不再按文件名对应新文件夹里的文件。
  Future<void> setMailFolder(String path) => _write(() async {
    if (await _meta(_mailFolderKey) case final old? when old != path) {
      final files = _db.mailExportFiles;
      await (_db.delete(files)..where(
            (f) =>
                f.unchangedSince.isNotNull() &
                f.status.isInValues([
                  MailExportFileStatus.seen,
                  MailExportFileStatus.needsMailbox,
                  MailExportFileStatus.invalid,
                ]),
          ))
          .go();
      await (_db.update(files)..where((f) => f.unchangedSince.isNotNull()))
          .write(const MailExportFilesCompanion(unchangedSince: Value(null)));
    }
    await _setMeta(_mailFolderKey, path);
    await _setMeta(_mailFolderChosenAtKey, '$_nowMillis');
    await _firstSetupAtOrNow();
  });

  /// 首次设置时间：第一次选择邮件文件夹或者第一次导入的时间，之后不再变。
  /// 还没有时把现在记下来，作为首次设置时间。
  Future<int> _firstSetupAtOrNow() async {
    if (await _meta(_firstSetupAtKey) case final at?) return int.parse(at);
    await _setMeta(_firstSetupAtKey, '$_nowMillis');
    return _nowMillis;
  }

  /// 解析失败的文件稳定多久以后算格式错误；之前当作还在同步。
  static const invalidAfter = Duration(minutes: 10);

  Future<void>? _scanRun;

  /// 上一次扫描时邮件文件夹不可用。
  bool _folderMissing = false;

  /// 每次扫描结束时发出一个事件。
  final _scanned = StreamController<void>.broadcast(sync: true);

  /// 扫描邮件文件夹，导入可以读的导出文件（spec 0002"导入规则"）。正在
  /// 扫描时不另开一次，返回正在进行的这一次。
  ///
  /// 第一次看到的文件、大小或修改时间和上次扫描时不一样的文件只记下来，
  /// 下一次扫描才读取；看到过的文件记在数据库里，重启后也算数。
  Future<void> scanFolder() => _scanRun ??= _scan().whenComplete(() {
    _scanRun = null;
    _scanned.add(null);
  });

  Future<void> _scan() async {
    final folder = await mailFolder();
    if (folder == null) return;
    final source = _openFolder(folder);
    final List<ExportFileInfo> files;
    try {
      files = await source.list();
      _folderMissing = false;
    } on ExportFolderUnavailable {
      _folderMissing = true;
      return;
    }
    final rows = {for (final row in await _read(_scanRows)) row.fileName: row};
    // 还没读过的或格式错误的文件不见了：不再记着它。
    final names = {for (final file in files) file.name};
    final vanished = [
      for (final row in rows.values)
        if (!names.contains(row.fileName) &&
            (row.status == MailExportFileStatus.seen ||
                row.status == MailExportFileStatus.needsMailbox ||
                row.status == MailExportFileStatus.invalid))
          row.id,
    ];
    if (vanished.isNotEmpty) {
      await _write(
        () => (_db.delete(
          _db.mailExportFiles,
        )..where((f) => f.id.isIn(vanished))).go(),
      );
    }
    var importedFiles = 0;
    var newMails = 0;
    for (final file in files) {
      final size = file.size;
      final modifiedAt = file.modifiedAt.millisecondsSinceEpoch;
      final row = rows[file.name];
      if (row == null) {
        final now = _nowMillis;
        await _write(
          () => _db
              .into(_db.mailExportFiles)
              .insert(
                MailExportFilesCompanion.insert(
                  id: _generateId(),
                  fileName: file.name,
                  fileSize: Value(size),
                  fileModifiedAt: Value(modifiedAt),
                  status: MailExportFileStatus.seen,
                  firstSeenAt: now,
                  unchangedSince: Value(now),
                ),
              ),
        );
        continue;
      }
      if (row.status
          case MailExportFileStatus.imported ||
              MailExportFileStatus.invalid ||
              MailExportFileStatus.deleted) {
        continue;
      }
      if (row.fileSize != size || row.fileModifiedAt != modifiedAt) {
        await _updateFile(
          row.id,
          MailExportFilesCompanion(
            fileSize: Value(size),
            fileModifiedAt: Value(modifiedAt),
            unchangedSince: Value(_nowMillis),
          ),
        );
        continue;
      }
      final List<int> bytes;
      try {
        bytes = await source.read(file.name);
      } on ExportFileUnreadable {
        continue;
      }
      final outcome = await _importBytes(
        bytes,
        fileName: file.name,
        fileModifiedAt: modifiedAt,
        scanRow: row,
      );
      switch (outcome) {
        case Imported(:final newMailCount):
          importedFiles++;
          newMails += newMailCount;
        case InvalidFile(:final error)
            when _nowMillis - row.unchangedSince! >=
                invalidAfter.inMilliseconds:
          await _updateFile(
            row.id,
            MailExportFilesCompanion(
              status: const Value(MailExportFileStatus.invalid),
              errorType: Value(error.name),
            ),
          );
        default:
      }
    }
    if (importedFiles > 0) {
      await _write(() async {
        await _setMeta(_lastImportAtKey, '$_nowMillis');
        await _setMeta(_lastImportNewMailsKey, '$newMails');
      });
    }
    await _deleteOldFiles(source);
    if (importedFiles > 0) unawaited(analyzePending());
  }

  /// 删除导入超过 14 天、其中的邮件都不再待分析的导出文件。格式错误的文件
  /// 留给人看，不删。删不掉的下次再试。
  Future<void> _deleteOldFiles(ExportSource source) async {
    final before = _nowMillis - keepExportFilesFor.inMilliseconds;
    final files = _db.mailExportFiles;
    final pending = _db.mails.analysisStatus.equalsValue(
      MailAnalysisStatus.pending,
    );
    final old = await _read(
      () =>
          (_db.select(files)..where(
                (f) =>
                    f.unchangedSince.isNotNull() &
                    f.status.equalsValue(MailExportFileStatus.imported) &
                    f.importedAt.isSmallerThanValue(before) &
                    notExistsQuery(
                      _db.select(
                        _db.mails,
                      )..where((m) => m.sourceFileId.equalsExp(f.id) & pending),
                    ),
              ))
              .get(),
    );
    for (final file in old) {
      try {
        await source.delete(file.fileName);
      } on ExportFileUnreadable {
        continue;
      }
      await _updateFile(
        file.id,
        const MailExportFilesCompanion(
          status: Value(MailExportFileStatus.deleted),
        ),
      );
    }
  }

  /// 导入和分析情况的变化：先发出现在的，之后数据库里的导入记录、邮件变了，
  /// 或者扫描结束时再发出。
  Stream<MailImportStatus> watchImportStatus() => _watchTables(
    [_db.mailExportFiles, _db.mails, _db.appMeta],
    importStatus,
    alsoOn: _scanned.stream,
  );

  /// 先发出 [read] 现在的结果，之后 [tables] 里的表变了、或者 [alsoOn] 有
  /// 事件时再读一次发出。
  Stream<T> _watchTables<T>(
    List<TableInfo> tables,
    Future<T> Function() read, {
    Stream<void>? alsoOn,
  }) {
    late final StreamController<T> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var latest = Future<void>.value();
    // 一次一次按顺序读，后读的结果不会被先读的盖掉。
    void refresh() => latest = latest.then(
      (_) => read().then(controller.add, onError: controller.addError),
    );
    controller = StreamController(
      onListen: () {
        refresh();
        subscriptions.add(
          _db
              .tableUpdates(TableUpdateQuery.onAllTables(tables))
              .listen((_) => refresh()),
        );
        if (alsoOn != null) subscriptions.add(alsoOn.listen((_) => refresh()));
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await latest;
      },
    );
    return controller.stream;
  }

  /// 现在的导入情况。
  Future<MailImportStatus> importStatus() => _read(() async {
    if (await _meta(_mailFolderKey) == null) {
      return const MailImportStatus(notices: [FolderNotSet()]);
    }
    // 找不到文件夹时，文件的提示都不算了；分析的提示和文件夹无关，照样列出。
    if (_folderMissing) {
      return MailImportStatus(
        notices: [const FolderMissing(), ...await _analysisNotices()],
      );
    }
    final rows = await _scanRows();
    final invalid = [
      for (final row in rows)
        if (row.status == MailExportFileStatus.invalid) row.fileName,
    ]..sort();
    // 格式错误的文件不算新文件，它另有提示。
    final lastNewFileAt = [
      for (final row in rows)
        if (row.status != MailExportFileStatus.invalid) row.firstSeenAt,
      if (await _meta(_mailFolderChosenAtKey) case final chosen?)
        int.parse(chosen),
    ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    final lastImportAt = await _meta(_lastImportAtKey);
    return MailImportStatus(
      notices: [
        if (rows.any((r) => r.status == MailExportFileStatus.seen))
          const FilesSyncing(),
        if (invalid.isNotEmpty) FormatErrors(invalid),
        if (lastNewFileAt != null &&
            _nowMillis - lastNewFileAt > noNewFilesAfter.inMilliseconds)
          NoNewFiles(_fromMillis(lastNewFileAt)!),
        if (await _hasGap()) const PossiblyMissedMails(),
        ...await _analysisNotices(),
      ],
      lastImportAt: _fromMillis(int.tryParse(lastImportAt ?? '')),
      lastImportNewMailCount: int.parse(
        await _meta(_lastImportNewMailsKey) ?? '0',
      ),
    );
  });

  /// 分析的情况，按状态行的顺序。
  Future<List<ImportNotice>> _analysisNotices() async {
    final count = _db.mails.id.count();
    final rows =
        await (_db.selectOnly(_db.mails)
              ..addColumns([
                _db.mails.analysisStatus,
                _db.mails.analysisFailureType,
                count,
              ])
              ..where(
                _db.mails.analysisStatus.isInValues([
                  MailAnalysisStatus.pending,
                  MailAnalysisStatus.failed,
                ]),
              )
              ..groupBy([
                _db.mails.analysisStatus,
                _db.mails.analysisFailureType,
              ]))
            .get();
    final pendingFailures = <String?>{};
    var failed = 0;
    for (final row in rows) {
      final status = _db.mails.analysisStatus.converter.fromSql(
        row.read(_db.mails.analysisStatus)!,
      );
      if (status == MailAnalysisStatus.failed) {
        failed += row.read(count)!;
      } else {
        pendingFailures.add(row.read(_db.mails.analysisFailureType));
      }
    }
    bool waiting(AnalysisFailureType type) =>
        pendingFailures.contains(type.name);
    // 暂停了、还有邮件在等着自动分析时才算暂停。
    final paused =
        await _autoAnalysisPaused() &&
        await (_db.select(_db.mails)
                  ..where(
                    (m) =>
                        m.analysisStatus.equalsValue(
                          MailAnalysisStatus.pending,
                        ) &
                        _waitsForUser(m).not(),
                  )
                  ..limit(1))
                .getSingleOrNull() !=
            null;
    return [
      if (paused) const AnalysisPaused(),
      if (waiting(AnalysisFailureType.notInstalled)) const ClaudeNotInstalled(),
      if (waiting(AnalysisFailureType.notLoggedIn)) const ClaudeNotLoggedIn(),
      if (waiting(AnalysisFailureType.quotaExhausted))
        const ClaudeQuotaExhausted(),
      if (failed > 0) AnalysisFailures(failed),
    ];
  }

  /// 按收件时间排开所有导入过的文件，有一个文件最早的邮件比它前面所有
  /// 文件最晚的邮件还晚，并且这两个文件都是满的（spec 0002"导入规则·空档
  /// 检查"）。后面那个文件导入超过 14 天以后不再算；补读的文件把空档盖住
  /// 以后也不再算。
  Future<bool> _hasGap() async {
    final files =
        await (_db.select(_db.mailExportFiles)
              ..where(
                (f) =>
                    f.earliestReceivedAt.isNotNull() &
                    f.status.isInValues([
                      MailExportFileStatus.imported,
                      MailExportFileStatus.deleted,
                    ]),
              )
              ..orderBy([
                (f) => OrderingTerm.asc(f.earliestReceivedAt),
                (f) => OrderingTerm.desc(f.latestReceivedAt),
              ]))
            .get();
    final recent = _nowMillis - keepExportFilesFor.inMilliseconds;
    // 到目前为止收件时间最晚的那个文件。
    MailExportFileRow? reach;
    for (final file in files) {
      if (reach != null &&
          file.earliestReceivedAt! > reach.latestReceivedAt! &&
          file.importedAt! >= recent &&
          file.mailCount == exportBatchSize &&
          reach.mailCount == exportBatchSize) {
        return true;
      }
      if (reach == null || file.latestReceivedAt! > reach.latestReceivedAt!) {
        reach = file;
      }
    }
    return false;
  }

  /// 扫描邮件文件夹时记下的文件，一个文件名一行。
  Future<List<MailExportFileRow>> _scanRows() => (_db.select(
    _db.mailExportFiles,
  )..where((f) => f.unchangedSince.isNotNull())).get();

  Future<void> _updateFile(String id, MailExportFilesCompanion changes) =>
      _write(
        () => (_db.update(
          _db.mailExportFiles,
        )..where((f) => f.id.equals(id))).write(changes),
      );

  Future<ImportOutcome> _import(
    ExportBatch batch, {
    required String fileName,
    required String contentHash,
    required int fileSize,
    required int fileModifiedAt,
    MailExportFileRow? scanRow,
  }) async {
    final sameContent = await (_db.select(
      _db.mailExportFiles,
    )..where((f) => f.contentHash.equals(contentHash))).get();
    final now = _nowMillis;
    if (sameContent.any((f) => f.status == MailExportFileStatus.imported)) {
      // 扫描到的副本也记为已导入，以后不再读取，到时候一起清理。
      if (scanRow != null) {
        await (_db.update(
          _db.mailExportFiles,
        )..where((f) => f.id.equals(scanRow.id))).write(
          MailExportFilesCompanion(
            contentHash: Value(contentHash),
            status: const Value(MailExportFileStatus.imported),
            newMailCount: const Value(0),
            importedAt: Value(now),
          ),
        );
      }
      return AlreadyImported(fileName);
    }
    // 手动导入时沿用同一内容以前手动导入的那一行（比如之前停在需要邮箱）。
    final existing =
        scanRow ??
        sameContent.where((f) => f.unchangedSince == null).firstOrNull;
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
    // 首次设置时间 14 天以前收到的邮件不自动分析（M-21）。
    final analyzeSince =
        await _firstSetupAtOrNow() - firstSetupLookback.inMilliseconds;
    for (final mail in newMails) {
      final receivedAt = mail.receivedAt?.millisecondsSinceEpoch;
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
              receivedAt: Value(receivedAt),
              importance: Value(mail.importance),
              hasAttachments: Value(mail.hasAttachments),
              hasInlineImages: Value(mail.body.hasInlineImages),
              bodyText: Value(mail.body.text),
              bodyPossiblyIncomplete: Value(mail.body.possiblyIncomplete),
              links: Value(_encodeLinks(mail.body.links)),
              analysisStatus: receivedAt != null && receivedAt < analyzeSince
                  ? MailAnalysisStatus.deferredOld
                  : MailAnalysisStatus.pending,
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

  /// 这一轮里分析过的邮件，这一轮里不再分析。
  final _tried = <String>{};

  /// 点 [重试] 重新变回待分析、还没分析的邮件：不计入每天的上限，暂停时
  /// 也分析。分析过一次就拿掉；这一轮提前停下时留给下一轮。只记在内存里，
  /// 重启以后再分析就计入上限。
  final _manuallyRetried = <String>{};

  /// 分析所有待分析的邮件：一次一封，收件时间新的在前。正在分析时不另开
  /// 一轮，返回正在进行的这一轮，它结束前会再看一遍有没有新的待分析邮件。
  ///
  /// 一封失败不影响其他邮件，这一轮里不再重试它（spec 0002"有类型的失败"）：
  /// 输出格式不对累计 [maxInvalidOutputs] 次后标为失败，其他失败还是待分析。
  /// 未安装、未登录时要等她处理，之后的自动分析跳过这些邮件。未安装、
  /// 未登录、额度用完时后面的邮件也会失败，这一轮直接停下。读写数据库失败
  /// 时也停下，邮件保持待分析。不会抛出异常。
  ///
  /// 每个本地日自动分析到 [dailyAutoAnalysisLimit] 封时暂停，直到第二天或者
  /// [resumeAnalysis]（M-22）。
  Future<void> analyzePending() {
    if (_analyzer == null) return Future.value();
    if (_analysisRun case final running?) {
      _analyzeAgain = true;
      return running;
    }
    return _analysisRun = _analyzeAll().whenComplete(() {
      _analysisRun = null;
      _tried.clear();
      // 这一轮停下以后才来的请求（导入、[重试]）：再来一轮。
      if (_analyzeAgain) unawaited(analyzePending());
    });
  }

  Future<void> _analyzeAll() async {
    try {
      do {
        _analyzeAgain = false;
        while (true) {
          final paused = await _read(_autoAnalysisPaused);
          final mail = await _read(
            () => _nextPending(only: paused ? _manuallyRetried : null),
          );
          if (mail == null) break;
          _tried.add(mail.id);
          final counts =
              !_manuallyRetried.remove(mail.id) && !mail.markedUseful;
          if (!await _analyzeOne(mail, countsTowardLimit: counts)) {
            // Claude 现在用不了，这一轮里来的请求再试也一样失败。
            _analyzeAgain = false;
            return;
          }
        }
      } while (_analyzeAgain);
    } catch (_) {
      // 读写数据库失败，或者分析期间数据库被关掉了：邮件保持待分析，下一轮
      // 再来。这一轮在后台运行，没有人等它的结果，所以什么错误都不往外抛。
    }
  }

  /// 今天自动分析了多少封；今天还没分析过时为 0。
  Future<int> _autoAnalyzedToday() async {
    if (await _meta(_autoAnalysisDayKey) != '$_today') return 0;
    return int.parse(await _meta(_autoAnalysisCountKey) ?? '0');
  }

  Future<void> _countAutoAnalysis() async {
    final count = await _autoAnalyzedToday();
    await _setMeta(_autoAnalysisDayKey, '$_today');
    await _setMeta(_autoAnalysisCountKey, '${count + 1}');
  }

  /// 今天自动分析到了上限，并且今天没点过 [继续分析]。
  Future<bool> _autoAnalysisPaused() async =>
      await _autoAnalyzedToday() >= dailyAutoAnalysisLimit &&
      await _meta(_autoAnalysisResumedDayKey) != '$_today';

  DayKey get _today => DayKey.fromDateTime(_clock.now());

  /// 状态行上的 [继续分析]：解除今天的暂停，接着分析。写入失败时什么都
  /// 不变，不会抛出异常。
  Future<void> resumeAnalysis() async {
    try {
      await _write(() => _setMeta(_autoAnalysisResumedDayKey, '$_today'));
    } on StorageFailure {
      return;
    }
    await analyzePending();
  }

  /// 状态行上的 [重试]：分析失败的邮件和等着装好、登录 Claude Code 的
  /// 邮件重新变回待分析，然后马上分析；它们不计入每天的上限，暂停时也
  /// 分析。额度用完和临时错误的邮件也跟着再试一次，但要计入上限，暂停时
  /// 不试。写入失败时什么都不变，不会抛出异常。
  Future<void> retryAnalysis() async {
    final List<String> ids;
    try {
      ids = await _write(() async {
        final mails = _db.mails;
        final retried =
            await (_db.selectOnly(mails)
                  ..addColumns([mails.id])
                  ..where(
                    mails.analysisStatus.equalsValue(
                          MailAnalysisStatus.failed,
                        ) |
                        (mails.analysisStatus.equalsValue(
                              MailAnalysisStatus.pending,
                            ) &
                            _waitsForUser(mails)),
                  ))
                .map((row) => row.read(mails.id)!)
                .get();
        await (_db.update(mails)..where(
              (m) => m.analysisStatus.equalsValue(MailAnalysisStatus.failed),
            ))
            .write(
              const MailsCompanion(
                analysisStatus: Value(MailAnalysisStatus.pending),
                analysisFailureType: Value(null),
                analysisFailureCount: Value(0),
              ),
            );
        await _forgetFailures(_userFixableFailures);
        return retried;
      });
    } on StorageFailure {
      return;
    }
    _manuallyRetried.addAll(ids);
    _tried.removeAll(ids);
    await analyzePending();
  }

  /// "已过滤的邮件"里的 [这封有用]：这封邮件重新分析，要求按需要行动处理
  /// （M-19）。不计入每天的上限，暂停时也分析。只改 DailyNote 里的记录，
  /// 不动 Outlook。
  ///
  /// 正文已经清除时抛出 [InvalidState]，提示 [bodyClearedMessage]，邮件不变。
  Future<void> markUseful(String mailId) async {
    await _write(() async {
      final mail = await (_db.select(
        _db.mails,
      )..where((m) => m.id.equals(mailId))).getSingleOrNull();
      if (mail == null) throw NotFound('找不到邮件 $mailId');
      if (mail.bodyClearedAt != null) {
        throw const InvalidState(bodyClearedMessage);
      }
      await (_db.update(_db.mails)..where((m) => m.id.equals(mailId))).write(
        const MailsCompanion(
          markedUseful: Value(true),
          analysisStatus: Value(MailAnalysisStatus.pending),
          analysisFailureType: Value(null),
          analysisFailureCount: Value(0),
        ),
      );
    });
    _tried.remove(mailId);
    await analyzePending();
  }

  /// 等正在进行的这一轮分析结束；没有在分析时马上完成。关闭数据库前调用。
  Future<void> waitForAnalysis() => _analysisRun ?? Future.value();

  /// 下一封要分析的邮件。[only] 不为 null 时只在这些邮件和点了
  /// [这封有用] 的邮件里找。
  Future<MailRow?> _nextPending({Set<String>? only}) =>
      (_db.select(_db.mails)
            ..where(
              (m) =>
                  m.analysisStatus.equalsValue(MailAnalysisStatus.pending) &
                  _waitsForUser(m).not() &
                  m.id.isNotIn(_tried) &
                  (only == null
                      ? const Constant(true)
                      : m.id.isIn(only) | m.markedUseful),
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

  /// 没安装或没登录 Claude Code 时失败的邮件：要等她处理，不自动重试。
  /// 点 [重试]、或者别的邮件分析成功以后才再分析。
  static Expression<bool> _waitsForUser($MailsTable m) =>
      m.analysisFailureType.isNotNull() &
      m.analysisFailureType.isIn(_userFixableFailures);

  static final _userFixableFailures = [
    AnalysisFailureType.notInstalled.name,
    AnalysisFailureType.notLoggedIn.name,
  ];

  /// 待分析的邮件不再记着 [types] 这几种失败。
  Future<void> _forgetFailures(List<String> types) =>
      (_db.update(_db.mails)..where(
            (m) =>
                m.analysisStatus.equalsValue(MailAnalysisStatus.pending) &
                m.analysisFailureType.isIn(types),
          ))
          .write(const MailsCompanion(analysisFailureType: Value(null)));

  /// 分析一封邮件并保存结果。返回这一轮要不要接着分析下一封。
  ///
  /// [countsTowardLimit] 时，Claude 给出了输出（成功，或者输出格式不对）就
  /// 计入今天的上限；没用到额度的失败不算。
  Future<bool> _analyzeOne(
    MailRow mail, {
    required bool countsTowardLimit,
  }) async {
    final request = await _read(() => _requestFor(mail));
    final AnalysisResult result;
    try {
      result = await _analyzer!.analyze(request);
    } on AnalysisFailed catch (e) {
      await _write(() async {
        await _saveFailure(mail.id, e.type);
        if (countsTowardLimit && e.type == AnalysisFailureType.invalidOutput) {
          await _countAutoAnalysis();
        }
      });
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
    await _write(() async {
      await _saveAnalysis(mail, result);
      if (countsTowardLimit) await _countAutoAnalysis();
    });
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

  /// 记下分析失败。失败次数只数输出格式不对，到 [maxInvalidOutputs] 次
  /// 时标为 `failed`，不再自动重试。
  Future<void> _saveFailure(String mailId, AnalysisFailureType type) async {
    final mail = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(mailId))).getSingle();
    final count = type == AnalysisFailureType.invalidOutput
        ? mail.analysisFailureCount + 1
        : mail.analysisFailureCount;
    await (_db.update(_db.mails)..where((m) => m.id.equals(mailId))).write(
      MailsCompanion(
        analysisFailureType: Value(type.name),
        analysisFailureCount: Value(count),
        analysisStatus: Value(
          count >= maxInvalidOutputs
              ? MailAnalysisStatus.failed
              : MailAnalysisStatus.pending,
        ),
      ),
    );
  }

  /// 保存分析结果。需要行动和可选活动的事项成为候选事项。点了 [这封有用]
  /// 的邮件不看分类，事项都成为候选；一个事项也没有时生成一个以邮件主题为
  /// 标题的候选。
  ///
  /// 结果里引用现有事项的事项（`updates`）按那个事项现在的状态处理，见
  /// [_followUp]。
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
    // 分析成功说明 Claude Code 装好了、登录了、有额度：等着的邮件接着分析。
    await _forgetFailures([
      ..._userFixableFailures,
      AnalysisFailureType.quotaExhausted.name,
    ]);
    // 分析期间这封邮件已经不是待分析了：不重复生成事项。
    if (updated == 0) return;
    // 分析期间可能点了 [这封有用]：看数据库里现在的。
    final markedUseful =
        await (_db.selectOnly(_db.mails)
              ..addColumns([_db.mails.markedUseful])
              ..where(_db.mails.id.equals(mail.id)))
            .map((row) => row.read(_db.mails.markedUseful)!)
            .getSingle();
    final List<AnalyzedItem> analyzed;
    if (markedUseful) {
      analyzed = result.items.isNotEmpty ? result.items : [_subjectItem(mail)];
    } else if (result.category.producesCandidates) {
      analyzed = result.items;
    } else {
      return;
    }
    for (final item in analyzed) {
      final target = switch (item.updates) {
        final id? => await (_db.select(
          _db.mailItems,
        )..where((i) => i.id.equals(id))).getSingleOrNull(),
        null => null,
      };
      if (target == null) {
        await _insertCandidate(mail, item, now: now);
        continue;
      }
      await _followUp(target, mail, item, now: now);
    }
  }

  /// 后续邮件 [mail] 的事项 [item] 更新现有事项 [target]（spec 0002"更新
  /// 建议的规则"）：候选直接改写；已加入、卡片还在画布上没完成的生成更新
  /// 建议；其他情况生成一条指向 [target] 的新候选。
  Future<void> _followUp(
    MailItemRow target,
    MailRow mail,
    AnalyzedItem item, {
    required int now,
  }) async {
    switch (target.status) {
      case MailItemStatus.candidate:
        final fields = _itemFields(item, _decodeLinks(mail.links));
        final before = await _knownFields(target);
        if (ItemChanges.between(before, fields).isEmpty) return;
        await (_db.update(
          _db.mailItems,
        )..where((i) => i.id.equals(target.id))).write(
          _itemColumns(item).copyWith(
            mailId: Value(mail.id),
            conversationId: Value(mail.conversationId),
            updated: const Value(true),
            updatedAt: Value(now),
          ),
        );
      case MailItemStatus.accepted when await _openCard(target.cardId) != null:
        // 和卡片上采用过的不一样、也不是她不用过的，才算改动。
        final after = _itemFields(item, _decodeLinks(mail.links));
        final rejectedToo = ItemChanges.between(
          await _knownFields(target),
          after,
        );
        final applied = ItemChanges.between(
          await _knownFields(target, withRejected: false),
          after,
        );
        final changes = ItemChanges(
          rejectedToo.fields.intersection(applied.fields),
          after,
        );
        // 这封邮件比之前的建议新：之前的建议不管怎样都被替代。
        final updates = _db.mailItemUpdates;
        await (_db.update(updates)..where(
              (u) =>
                  u.itemId.equals(target.id) &
                  u.status.equalsValue(MailItemUpdateStatus.pending),
            ))
            .write(
              MailItemUpdatesCompanion(
                status: const Value(MailItemUpdateStatus.superseded),
                resolvedAt: Value(now),
              ),
            );
        if (changes.isEmpty) return;
        await _db
            .into(updates)
            .insert(
              MailItemUpdatesCompanion.insert(
                id: _generateId(),
                itemId: target.id,
                mailId: mail.id,
                changes: changes.encode(),
                status: MailItemUpdateStatus.pending,
                createdAt: now,
              ),
            );
      case MailItemStatus.accepted || MailItemStatus.ignored:
        await _insertCandidate(mail, item, now: now, relatedItemId: target.id);
    }
  }

  /// 卡片 [cardId]，要在画布上、没完成、不在回收站；否则为 null。
  Future<TaskCardRow?> _openCard(String? cardId) async {
    if (cardId == null) return null;
    final card = await (_db.select(
      _db.taskCards,
    )..where((c) => c.id.equals(cardId))).getSingleOrNull();
    return card != null &&
            card.status == CardStatus.active &&
            card.deletedAt == null
        ? card
        : null;
  }

  Future<void> _insertCandidate(
    MailRow mail,
    AnalyzedItem item, {
    required int now,
    String? relatedItemId,
  }) => _db
      .into(_db.mailItems)
      .insert(
        _itemColumns(item).copyWith(
          id: Value(_generateId()),
          mailId: Value(mail.id),
          conversationId: Value(mail.conversationId),
          status: const Value(MailItemStatus.candidate),
          relatedItemId: Value(relatedItemId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  /// 事项里来自分析结果的那些列。
  static MailItemsCompanion _itemColumns(AnalyzedItem item) {
    final event = cardTimeToColumns(item.eventTime);
    final due = cardTimeToColumns(item.dueTime);
    return MailItemsCompanion(
      title: Value(item.title),
      summary: Value(item.summary),
      actions: Value(item.actions.isEmpty ? null : jsonEncode(item.actions)),
      location: Value(item.location),
      linkRefs: Value(item.linkRefs.isEmpty ? null : jsonEncode(item.linkRefs)),
      eventTime: Value(event.value),
      eventTimePrecision: Value(event.precision),
      eventTimePending: Value(event.pending),
      dueTime: Value(due.value),
      dueTimePrecision: Value(due.precision),
      dueTimePending: Value(due.pending),
      optional: Value(item.optional),
      hasUnanalyzedAttachments: Value(item.unanalyzedAttachments),
    );
  }

  /// 分析结果里的事项 [item] 的可更新字段；[links] 是它所在邮件的链接列表。
  static ItemFields _itemFields(AnalyzedItem item, List<String> links) =>
      ItemFields(
        title: item.title,
        summary: item.summary,
        actions: item.actions,
        location: item.location,
        links: [
          for (final ref in item.linkRefs)
            if (ref >= 1 && ref <= links.length) links[ref - 1],
        ],
        eventTime: item.eventTime,
        dueTime: item.dueTime,
      );

  /// 事项 [item] 现在已知的可更新字段：事项本身的，再按顺序叠上她采用过
  /// 的更新建议；[withRejected] 时也叠上她不用的，同样的改动以后不再提。
  /// 不叠不用的时候，就是卡片备注里来自邮件的那些内容。
  Future<ItemFields> _knownFields(
    MailItemRow item, {
    bool withRejected = true,
  }) async {
    final mail = await (_db.select(
      _db.mails,
    )..where((m) => m.id.equals(item.mailId))).getSingle();
    var fields = _rowFields(item, _decodeLinks(mail.links));
    final resolved =
        await (_db.select(_db.mailItemUpdates)
              ..where(
                (u) =>
                    u.itemId.equals(item.id) &
                    u.status.isInValues([
                      MailItemUpdateStatus.applied,
                      if (withRejected) MailItemUpdateStatus.rejected,
                    ]),
              )
              ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
            .get();
    for (final update in resolved) {
      fields = fields.overlay(ItemChanges.decode(update.changes));
    }
    return fields;
  }

  /// 点了 [这封有用]、又分析不出事项时，以邮件主题为标题的那个事项。
  AnalyzedItem _subjectItem(MailRow mail) => AnalyzedItem(
    updates: null,
    title: _preview(mail).displaySubject,
    summary: null,
    actions: const [],
    location: null,
    linkRefs: const [],
    eventTime: null,
    dueTime: null,
    optional: false,
    unanalyzedAttachments: false,
  );

  // ---- 候选事项、加入和忽略 ----

  /// "新邮件事项"栏里的候选事项：需要行动在前，可选活动在后；同类里按截止
  /// 时间（没有时看活动时间）从近到远，没有时间的排在最后。
  Stream<List<MailItemCandidate>> watchCandidates() {
    final items = _db.mailItems;
    final mails = _db.mails;
    final related = _db.alias(_db.mailItems, 'related');
    final relatedCards = _db.alias(_db.taskCards, 'related_card');
    final query = _db.select(items).join([
      innerJoin(mails, mails.id.equalsExp(items.mailId)),
      leftOuterJoin(related, related.id.equalsExp(items.relatedItemId)),
      leftOuterJoin(relatedCards, relatedCards.id.equalsExp(related.cardId)),
    ])..where(items.status.equalsValue(MailItemStatus.candidate));
    return query.watch().map((rows) {
      final entries = [
        for (final row in rows)
          (
            item: row.readTable(items),
            mail: row.readTable(mails),
            relatedHint: _relatedHint(
              row.readTableOrNull(related),
              row.readTableOrNull(relatedCards),
            ),
          ),
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
        for (final (:item, :mail, :relatedHint) in entries)
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
            updated: item.updated,
            relatedHint: relatedHint,
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

  /// 新候选和相关事项 [related] 的关系，栏里注明；[card] 是它的卡片。
  static String? _relatedHint(MailItemRow? related, TaskCardRow? card) {
    if (related == null) return null;
    final title = related.title;
    return switch (related.status) {
      MailItemStatus.ignored => '和你忽略过的《$title》有关',
      MailItemStatus.accepted when card?.status == CardStatus.completed =>
        '可能和已完成的《$title》有关',
      MailItemStatus.accepted when card == null || card.deletedAt != null =>
        '可能和已删除的《$title》有关',
      _ => '可能和《$title》有关',
    };
  }

  /// "已过滤的邮件"：分类为仅供参考或低价值的邮件（点了 [这封有用] 的除外）、
  /// 首次设置时较早没分析的邮件、分析失败的邮件和被忽略的事项，收件
  /// 时间新的在前（spec 0002"候选事项、加入和忽略"）。邮件或事项变了时
  /// 重新发出。
  Stream<List<FilteredEntry>> watchFiltered() =>
      _watchTables([_db.mails, _db.mailItems], () => _read(_filtered));

  Future<List<FilteredEntry>> _filtered() async {
    final mails = _db.mails;
    final items = _db.mailItems;
    final filteredMails =
        await (_db.select(mails)..where(
              (m) =>
                  (m.analysisStatus.equalsValue(MailAnalysisStatus.done) &
                      m.markedUseful.not() &
                      m.category.isIn([
                        MailCategory.informational.name,
                        MailCategory.lowValue.name,
                      ])) |
                  m.analysisStatus.isInValues([
                    MailAnalysisStatus.deferredOld,
                    MailAnalysisStatus.failed,
                  ]),
            ))
            .get();
    final ignored = await (_db.select(items).join([
      innerJoin(mails, mails.id.equalsExp(items.mailId)),
    ])..where(items.status.equalsValue(MailItemStatus.ignored))).get();
    final entries = [
      for (final mail in filteredMails) _filteredMail(mail),
      for (final row in ignored)
        _filteredEntry(
          row.readTable(mails),
          kind: FilteredKind.ignoredItem,
          id: row.readTable(items).id,
          title: row.readTable(items).title,
          reason: '你忽略了这个事项',
        ),
    ];
    entries.sort((a, b) {
      final byTime = switch ((a.receivedAt, b.receivedAt)) {
        (final x?, final y?) => y.compareTo(x),
        (_?, null) => -1,
        (null, _?) => 1,
        (null, null) => 0,
      };
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return entries;
  }

  FilteredEntry _filteredMail(MailRow mail) {
    final (kind, reason) = switch (mail.analysisStatus) {
      MailAnalysisStatus.deferredOld => (
        FilteredKind.notAnalyzed,
        '较早的邮件，没有自动分析',
      ),
      MailAnalysisStatus.failed => (FilteredKind.analysisFailed, '分析失败'),
      _ when mail.category == MailCategory.lowValue.name => (
        FilteredKind.lowValue,
        mail.categoryReason ?? '',
      ),
      _ => (FilteredKind.informational, mail.categoryReason ?? ''),
    };
    return _filteredEntry(
      mail,
      kind: kind,
      id: mail.id,
      title: _preview(mail).displaySubject,
      reason: reason,
    );
  }

  /// 来自邮件 [mail] 的一条：发件人、日期和正文是否已清除取自这封邮件。
  FilteredEntry _filteredEntry(
    MailRow mail, {
    required FilteredKind kind,
    required String id,
    required String title,
    required String reason,
  }) => FilteredEntry(
    kind: kind,
    id: id,
    title: title,
    mailId: mail.id,
    sender: _preview(mail).displaySender,
    receivedAt: _fromMillis(mail.receivedAt),
    reason: reason,
    bodyCleared: mail.bodyClearedAt != null,
  );

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
    await _setItemStatus(itemId, MailItemStatus.ignored);
  });

  /// [恢复]：被忽略的事项回到栏里。事项不是被忽略的时抛出 [InvalidState]。
  Future<void> restoreItem(String itemId) => _write(() async {
    await _requireItem(itemId, MailItemStatus.ignored, '这个事项没有被忽略');
    await _setItemStatus(itemId, MailItemStatus.candidate);
  });

  Future<void> _setItemStatus(String itemId, MailItemStatus status) =>
      (_db.update(_db.mailItems)..where((i) => i.id.equals(itemId))).write(
        MailItemsCompanion(status: Value(status), updatedAt: Value(_nowMillis)),
      );

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

  // ---- 更新建议 ----

  /// 卡片上要显示的更新建议，按卡片 id。只有画布上没完成的卡片；同一张
  /// 卡片只有最新的一条（旧的已经被替代）。
  Stream<Map<String, CardUpdate>> watchCardUpdates() {
    final updates = _db.mailItemUpdates;
    final items = _db.mailItems;
    final cards = _db.taskCards;
    final query =
        _db.select(updates).join([
          innerJoin(items, items.id.equalsExp(updates.itemId)),
          innerJoin(cards, cards.id.equalsExp(items.cardId)),
        ])..where(
          updates.status.equalsValue(MailItemUpdateStatus.pending) &
              cards.status.equalsValue(CardStatus.active) &
              cards.deletedAt.isNull(),
        );
    return query.watch().map((rows) {
      return {
        for (final row in rows)
          row.readTable(cards).id: CardUpdate(
            id: row.readTable(updates).id,
            cardId: row.readTable(cards).id,
            changes: ItemChanges.decode(row.readTable(updates).changes),
            cardTimes: _cardTimes(row.readTable(cards)),
          ),
      };
    });
  }

  /// [采用]：只把建议里列出的字段写到卡片上，她改过的其他内容不变；备注里
  /// 只换掉对应的那一部分，找不到时把新内容加在最后。卡片和建议在同一个
  /// 事务里修改。
  ///
  /// 建议已经处理过或被替代、卡片已经不在画布上时抛出 [InvalidState]。
  Future<void> applyUpdate(String updateId) => _write(() async {
    final update = await _requirePendingUpdate(updateId);
    final item = await (_db.select(
      _db.mailItems,
    )..where((i) => i.id.equals(update.itemId))).getSingle();
    final card = await _openCard(item.cardId);
    if (card == null) throw const InvalidState('卡片已经不在画布上了');
    final changes = ItemChanges.decode(update.changes);
    final before = _noteParts(await _knownFields(item, withRejected: false));
    final after = _noteParts(changes.values);
    var note = card.note ?? '';
    for (final field in after.keys) {
      if (changes.fields.contains(field)) {
        note = _replaceNotePart(note, before[field], after[field]);
      }
    }
    final times = _cardTimes(card);
    final changed = changes.fields;
    await _planner.updateCardContentInTransaction(
      card.id,
      title: changed.contains(ItemField.title)
          ? _truncate(changes.values.title, PlannerService.maxTitleLength)
          : card.title,
      note: note.trim().isEmpty
          ? null
          : _truncate(note, PlannerService.maxNoteLength),
      times: (
        event: changed.contains(ItemField.eventTime)
            ? changes.values.eventTime
            : times.event,
        due: changed.contains(ItemField.dueTime)
            ? changes.values.dueTime
            : times.due,
      ),
    );
    await _resolveUpdate(updateId, MailItemUpdateStatus.applied);
  });

  /// [不用]：建议不再显示，同样的改动以后也不再提。建议已经处理过或被
  /// 替代时抛出 [InvalidState]。
  Future<void> rejectUpdate(String updateId) => _write(() async {
    await _requirePendingUpdate(updateId);
    await _resolveUpdate(updateId, MailItemUpdateStatus.rejected);
  });

  Future<MailItemUpdateRow> _requirePendingUpdate(String updateId) async {
    final update = await (_db.select(
      _db.mailItemUpdates,
    )..where((u) => u.id.equals(updateId))).getSingleOrNull();
    if (update == null) throw NotFound('找不到更新建议 $updateId');
    if (update.status != MailItemUpdateStatus.pending) {
      throw const InvalidState('这条更新已经处理过了');
    }
    return update;
  }

  Future<void> _resolveUpdate(String updateId, MailItemUpdateStatus status) =>
      (_db.update(
        _db.mailItemUpdates,
      )..where((u) => u.id.equals(updateId))).write(
        MailItemUpdatesCompanion(
          status: Value(status),
          resolvedAt: Value(_nowMillis),
        ),
      );

  /// 在备注 [note] 里把 [before] 换成 [after]：[after] 为 null 时删掉
  /// [before] 那一段；备注里没有 [before] 时把 [after] 加在最后。
  static String _replaceNotePart(String note, String? before, String? after) {
    if (before != null && note.contains(before)) {
      if (after != null) return note.replaceFirst(before, after);
      for (final part in ['$before\n', '\n$before', before]) {
        if (note.contains(part)) return note.replaceFirst(part, '');
      }
    }
    if (after == null) return note;
    return note.isEmpty ? after : '$note\n$after';
  }

  static CardTimes _cardTimes(TaskCardRow card) => (
    event: cardTimeFromColumns(
      card.eventTime,
      card.eventTimePrecision,
      card.eventTimePending,
    ),
    due: cardTimeFromColumns(
      card.dueTime,
      card.dueTimePrecision,
      card.dueTimePending,
    ),
  );

  Future<MailItemRow> _requireCandidate(String itemId) =>
      _requireItem(itemId, MailItemStatus.candidate, '这个事项已经处理过了');

  /// 状态是 [status] 的事项 [itemId]。没有这个事项时抛出 [NotFound]，状态
  /// 不对时抛出 [InvalidState]，提示 [wrongStatus]。
  Future<MailItemRow> _requireItem(
    String itemId,
    MailItemStatus status,
    String wrongStatus,
  ) async {
    final item = await (_db.select(
      _db.mailItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) throw NotFound('找不到事项 $itemId');
    if (item.status != status) throw InvalidState(wrongStatus);
    return item;
  }

  /// 卡片的备注：依次是摘要、要做的事、地点、第一个链接；都没有时为 null。
  static String? _cardNote(MailItemRow item, List<String> links) {
    final parts = [..._noteParts(_rowFields(item, links)).values.nonNulls];
    if (parts.isEmpty) return null;
    return _truncate(parts.join('\n'), PlannerService.maxNoteLength);
  }

  /// 卡片备注里来自事项各个字段的那一段，按备注里的顺序；没有时为 null。
  /// [采用] 时按它找到备注里要换掉的部分。
  static Map<ItemField, String?> _noteParts(ItemFields fields) => {
    ItemField.summary: fields.summary,
    ItemField.actions: fields.actions.isEmpty
        ? null
        : [for (final action in fields.actions) '- $action'].join('\n'),
    ItemField.location: switch (fields.location) {
      final location? => '地点：$location',
      null => null,
    },
    ItemField.links: fields.links.firstOrNull,
  };

  /// 事项 [item] 本身的可更新字段；[links] 是它的来源邮件的链接列表。
  static ItemFields _rowFields(MailItemRow item, List<String> links) =>
      ItemFields(
        title: item.title,
        summary: item.summary,
        actions: _itemActions(item),
        location: item.location,
        links: _itemLinks(item, links),
        eventTime: _itemEventTime(item),
        dueTime: _itemDueTime(item),
      );

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

  Future<String?> _mailboxAddress() => _meta(_mailboxAddressKey);

  Future<String?> _meta(String key) async {
    final row = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) => _db
      .into(_db.appMeta)
      .insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));

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
        await _setMeta(_mailboxAddressKey, clean);
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
