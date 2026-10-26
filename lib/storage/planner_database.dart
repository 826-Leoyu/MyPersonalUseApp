import 'package:drift/drift.dart';

import '../planner/card_time.dart';
import '../planner/link_kind.dart';
import '../planner/task_card.dart';

part 'planner_database.g.dart';

// 所有 ID 都是 UUID v4 文本；所有时间都是 UTC 毫秒整数；
// dayKey 是本地时区的 `YYYY-MM-DD` 文本。
//
// 例外：卡片的活动时间和截止时间（schemaVersion 2 新增）是文本，精度为
// dateTime 时存 UTC 的 ISO 8601 时间，精度为 date 时存本地的 dayKey。

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

/// 键值表：`lastMaintenanceDay`、`schemaVersion`。
@DataClassName('AppMetaEntry')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 本地数据存储。只有 `PlannerService` 调用它。
@DriftDatabase(tables: [TaskCards, Links, CarryOverRecords, AppMeta])
class PlannerDatabase extends _$PlannerDatabase {
  PlannerDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appMeta).insert(
        AppMetaCompanion.insert(key: 'schemaVersion', value: '$schemaVersion'),
      );
    },
    onUpgrade: (m, from, to) async {
      // 只新增可为空或有默认值的列，旧数据不受影响。
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
      await into(appMeta).insertOnConflictUpdate(
        AppMetaCompanion.insert(key: 'schemaVersion', value: '$to'),
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
