import 'package:drift/drift.dart';

import '../mail/mail_states.dart';
import '../planner/card_time.dart';
import '../planner/link_kind.dart';
import '../planner/task_card.dart';

part 'planner_database.g.dart';

// 所有 ID 都是 UUID v4 文本；所有时间都是 UTC 毫秒整数；
// dayKey 是本地时区的 `YYYY-MM-DD` 文本。
//
// 例外：卡片的活动时间和截止时间（schemaVersion 2 新增）是文本，精度为
// dateTime 时存 UTC 的 ISO 8601 时间，精度为 date 时存本地的 dayKey。
// 原因见 docs/adr/0001-card-times-stored-as-text.md。邮件事项的两个时间
// （schemaVersion 3 新增）和卡片的结构一样。

@DataClassName('TaskCardRow')
@TableIndex(name: 'task_cards_day_key', columns: {#dayKey})
class TaskCards extends Table {
  TextColumn get id => text()();
  TextColumn get dayKey => text()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  IntColumn get zIndex => integer()();
  IntColumn get colorArgb => integer()();
  TextColumn get status => textEnum<CardStatus>()();
  IntColumn get completedAt => integer().nullable()();
  BoolColumn get carriedOver => boolean()();
  TextColumn get originalDayKey => text()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  // ---- schemaVersion 2 ----
  TextColumn get eventTime => text().nullable()();
  TextColumn get eventTimePrecision =>
      textEnum<CardTimePrecision>().nullable()();
  BoolColumn get eventTimePending =>
      boolean().withDefault(const Constant(false))();
  TextColumn get dueTime => text().nullable()();
  TextColumn get dueTimePrecision => textEnum<CardTimePrecision>().nullable()();
  BoolColumn get dueTimePending =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同一对卡片之间（不管方向）最多只有一条未删除的连线。
@DataClassName('LinkRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX links_one_active_per_pair ON links '
  '(min(from_card_id, to_card_id), max(from_card_id, to_card_id)) '
  'WHERE deleted_at IS NULL',
)
class Links extends Table {
  TextColumn get id => text()();
  TextColumn get fromCardId => text().references(TaskCards, #id)();
  TextColumn get toCardId => text().references(TaskCards, #id)();
  TextColumn get kind => textEnum<LinkKind>()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 顺延时在出发那一天留下的只读快照。只追加，所以没有软删除字段。
@DataClassName('CarryOverRecordRow')
@TableIndex(name: 'carry_over_records_from_day_key', columns: {#fromDayKey})
class CarryOverRecords extends Table {
  TextColumn get id => text()();
  TextColumn get cardId => text().references(TaskCards, #id)();
  TextColumn get fromDayKey => text()();
  TextColumn get toDayKey => text()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  TextColumn get titleSnapshot => text()();
  IntColumn get colorArgb => integer()();
  IntColumn get carriedAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---- schemaVersion 3：邮件。字段的含义见 spec 0002 的"数据模型" ----

/// 导出文件。同一个内容哈希只处理一次。
@DataClassName('MailExportFileRow')
class MailExportFiles extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get fileModifiedAt => integer().nullable()();
  TextColumn get contentHash => text().unique()();
  TextColumn get status => textEnum<MailExportFileStatus>()();
  TextColumn get errorType => text().nullable()();
  TextColumn get mailbox => text().nullable()();
  IntColumn get exportedAt => integer().nullable()();
  IntColumn get earliestReceivedAt => integer().nullable()();
  IntColumn get latestReceivedAt => integer().nullable()();
  IntColumn get mailCount => integer().nullable()();
  IntColumn get newMailCount => integer().nullable()();

  /// 缺少邮件键、被跳过的邮件数。
  IntColumn get skippedCount => integer().nullable()();
  IntColumn get firstSeenAt => integer()();
  IntColumn get importedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 邮件。同一个邮箱里同一个邮件键只有一封。
@DataClassName('MailRow')
@TableIndex(name: 'mails_received_at', columns: {#receivedAt})
class Mails extends Table {
  TextColumn get id => text()();
  TextColumn get mailbox => text()();
  TextColumn get mailKey => text()();
  TextColumn get mailKeyKind => textEnum<MailKeyKind>()();
  TextColumn get outlookId => text().nullable()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get subject => text()();
  TextColumn get senderName => text().nullable()();
  TextColumn get senderAddress => text().nullable()();
  IntColumn get receivedAt => integer().nullable()();
  TextColumn get importance => text().nullable()();
  BoolColumn get hasAttachments =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hasInlineImages =>
      boolean().withDefault(const Constant(false))();
  TextColumn get bodyText => text().nullable()();
  BoolColumn get bodyPossiblyIncomplete =>
      boolean().withDefault(const Constant(false))();

  /// JSON 数组，分析结果用下标引用。
  TextColumn get links => text().nullable()();
  IntColumn get bodyExpiresAt => integer().nullable()();
  IntColumn get bodyClearedAt => integer().nullable()();
  TextColumn get analysisStatus => textEnum<MailAnalysisStatus>()();
  TextColumn get analysisFailureType => text().nullable()();
  IntColumn get analysisFailureCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get categoryReason => text().nullable()();
  BoolColumn get markedUseful => boolean().withDefault(const Constant(false))();
  TextColumn get sourceFileId => text().references(MailExportFiles, #id)();
  IntColumn get importedAt => integer()();
  IntColumn get analyzedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {mailbox, mailKey},
  ];
}

/// 邮件事项。
@DataClassName('MailItemRow')
class MailItems extends Table {
  TextColumn get id => text()();
  TextColumn get mailId => text().references(Mails, #id)();
  TextColumn get conversationId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();

  /// 要做的事，JSON 数组。
  TextColumn get actions => text().nullable()();
  TextColumn get location => text().nullable()();

  /// 引用的邮件链接下标，JSON 数组。
  TextColumn get linkRefs => text().nullable()();
  TextColumn get eventTime => text().nullable()();
  TextColumn get eventTimePrecision =>
      textEnum<CardTimePrecision>().nullable()();
  BoolColumn get eventTimePending =>
      boolean().withDefault(const Constant(false))();
  TextColumn get dueTime => text().nullable()();
  TextColumn get dueTimePrecision => textEnum<CardTimePrecision>().nullable()();
  BoolColumn get dueTimePending =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get optional => boolean().withDefault(const Constant(false))();
  BoolColumn get hasUnanalyzedAttachments =>
      boolean().withDefault(const Constant(false))();
  TextColumn get status => textEnum<MailItemStatus>()();

  /// 卡片被永久删除时置空。
  TextColumn get cardId => text().nullable().references(
    TaskCards,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get updated => boolean().withDefault(const Constant(false))();
  TextColumn get relatedItemId =>
      text().nullable().references(MailItems, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 邮件事项的更新建议。
@DataClassName('MailItemUpdateRow')
class MailItemUpdates extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(MailItems, #id)();
  TextColumn get mailId => text().references(Mails, #id)();

  /// 字段名到新值，JSON 对象。
  TextColumn get changes => text()();
  TextColumn get status => textEnum<MailItemUpdateStatus>()();
  IntColumn get createdAt => integer()();
  IntColumn get resolvedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 键值表：`lastMaintenanceDay`、`schemaVersion`、`mailboxAddress`。
@DataClassName('AppMetaEntry')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 本地数据存储。只有 `PlannerService` 和 `MailService` 调用它。
@DriftDatabase(
  tables: [
    TaskCards,
    Links,
    CarryOverRecords,
    AppMeta,
    MailExportFiles,
    Mails,
    MailItems,
    MailItemUpdates,
  ],
)
class PlannerDatabase extends _$PlannerDatabase {
  PlannerDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appMeta).insert(
        AppMetaCompanion.insert(key: 'schemaVersion', value: '$schemaVersion'),
      );
    },
    onUpgrade: (m, from, to) async {
      // 只新增表和可为空或有默认值的列，旧数据不受影响。
      if (from < 2) {
        for (final column in [
          taskCards.eventTime,
          taskCards.eventTimePrecision,
          taskCards.eventTimePending,
          taskCards.dueTime,
          taskCards.dueTimePrecision,
          taskCards.dueTimePending,
        ]) {
          await m.addColumn(taskCards, column);
        }
      }
      if (from < 3) {
        for (final table in <TableInfo>[
          mailExportFiles,
          mails,
          mailItems,
          mailItemUpdates,
        ]) {
          await m.createTable(table);
        }
        await m.createIndex(mailsReceivedAt);
      }
      await into(appMeta).insertOnConflictUpdate(
        AppMetaCompanion.insert(key: 'schemaVersion', value: '$to'),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
