// 数据库迁移（M-1）：用 v1、v2、v3 的数据库升级，旧数据通过 PlannerService 读回来
// 都一样。
//
// generated_migrations/ 和 drift_schemas/ 由 drift_dev 生成。改了表结构、
// 升了 schemaVersion 以后重新生成：
//   dart run drift_dev schema dump lib/storage/planner_database.dart drift_schemas/
//   dart run drift_dev schema generate drift_schemas/ test/storage/generated_migrations/
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/link_kind.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/planner/task_card.dart';
import 'package:my_personal_use_app/storage/planner_database.dart';

import '../mail/mail_fixtures.dart';
import 'generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  final now = DateTime(2026, 10, 20, 9);
  final today = DayKey.fromDateTime(now);
  final yesterday = today.addDays(-1);
  int millis(DateTime time) => time.toUtc().millisecondsSinceEpoch;
  final created = millis(now.subtract(const Duration(days: 2)));

  for (final from in [1, 2, 3]) {
    test('结构从 v$from 升级到 v4 后和新建的 v4 数据库一样', () async {
      final schema = await verifier.schemaAt(from);
      final db = PlannerDatabase(schema.newConnection());

      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });
  }

  test('从 v1 升级到最新版后，卡片、连线、历史记录、回收站和 AppMeta 都和升级前一样', () async {
    final schema = await verifier.schemaAt(1);
    // 用 v1 的表结构直接写入旧数据。
    final v1 = schema.rawDatabase;
    void card(
      String id, {
      required DayKey day,
      String status = 'active',
      String? note,
      int? completedAt,
      int carriedOver = 0,
      DayKey? originalDay,
      int? deletedAt,
    }) => v1.execute(
      'INSERT INTO task_cards (id, day_key, title, note, x, y, width, height, '
      'z_index, color_argb, status, completed_at, carried_over, '
      'original_day_key, deleted_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, 10.5, 20.5, 200, 100, 3, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        '$day',
        '标题 $id',
        note,
        0xFFCDEBC5,
        status,
        completedAt,
        carriedOver,
        '${originalDay ?? day}',
        deletedAt,
        created,
        created + 1,
      ],
    );
    card(
      'carried',
      day: today,
      note: '备注\n第二行',
      carriedOver: 1,
      originalDay: yesterday,
    );
    card('plain', day: today);
    card('done', day: today, status: 'completed', completedAt: created + 5);
    card(
      'trashed',
      day: today,
      deletedAt: millis(now) - Duration.millisecondsPerDay,
    );
    // 昨天没完成的卡片：AppMeta 里的维护日期保留下来时，今天不会再顺延它。
    card('left', day: yesterday);
    v1.execute(
      'INSERT INTO links (id, from_card_id, to_card_id, kind, deleted_at, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, NULL, ?, ?)',
      ['link', 'carried', 'plain', 'visual', created, created],
    );
    v1.execute(
      'INSERT INTO carry_over_records (id, card_id, from_day_key, to_day_key, '
      'x, y, width, height, title_snapshot, color_argb, carried_at, '
      'created_at, updated_at) '
      'VALUES (?, ?, ?, ?, 1, 2, 180, 88, ?, ?, ?, ?, ?)',
      [
        'record',
        'carried',
        '$yesterday',
        '$today',
        '旧标题',
        0xFFFFF0B8,
        created,
        created,
        created,
      ],
    );
    v1.execute(
      "INSERT INTO app_meta (key, value) VALUES ('schemaVersion', '1'), "
      "('lastMaintenanceDay', '$today')",
    );

    final db = PlannerDatabase(schema.newConnection());
    final service = PlannerService(database: db, clock: Clock(() => now));
    await service.open();

    final board = await service.watchDay(today).first;
    expect(board.cards.map((c) => c.id), unorderedEquals(['carried', 'plain']));
    final carried = board.cards.singleWhere((c) => c.id == 'carried');
    expect(carried.title, '标题 carried');
    expect(carried.note, '备注\n第二行');
    expect(
      (carried.x, carried.y, carried.width, carried.height, carried.zIndex),
      (10.5, 20.5, 200, 100, 3),
    );
    expect(carried.colorArgb, 0xFFCDEBC5);
    expect(carried.status, CardStatus.active);
    expect(carried.carriedOver, isTrue);
    expect(carried.originalDayKey, yesterday);
    expect(carried.createdAt.millisecondsSinceEpoch, created);
    expect(carried.updatedAt.millisecondsSinceEpoch, created + 1);
    // 旧卡片没有时间。
    expect(carried.eventTime, isNull);
    expect(carried.dueTime, isNull);

    expect(board.links.single.id, 'link');
    expect(board.links.single.kind, LinkKind.visual);
    expect(board.completedCount, 1);

    final done = await service.watchCompleted(today).first;
    expect(done.single.id, 'done');
    expect(done.single.completedAt!.millisecondsSinceEpoch, created + 5);

    final trash = await service.watchTrash().first;
    expect(trash.single.card.id, 'trashed');
    expect(trash.single.daysLeft, 9);

    final record =
        (await service.watchDay(yesterday).first).carryOverRecords.single;
    expect(record.id, 'record');
    expect(record.titleSnapshot, '旧标题');
    expect(record.toDayKey, today);

    final summary = await service.runDailyMaintenance();
    expect(summary.carriedCount, 0);
    expect((await service.watchDay(yesterday).first).cards.map((c) => c.id), [
      'left',
    ]);

    final version = await (db.select(
      db.appMeta,
    )..where((m) => m.key.equals('schemaVersion'))).getSingle();
    expect(version.value, '${db.schemaVersion}');

    // 升级后的旧卡片可以设时间。
    await service.updateCardContent(
      'plain',
      title: '标题 plain',
      note: null,
      times: (event: null, due: CardTime.date(today.addDays(3))),
    );
    final plain = (await service.watchDay(today).first).cards.singleWhere(
      (c) => c.id == 'plain',
    );
    expect(plain.dueTime, CardTime.date(today.addDays(3)));

    await db.close();
  });

  test('从 v2 升级到最新版后，卡片的时间和 AppMeta 都和升级前一样', () async {
    final schema = await verifier.schemaAt(2);
    final v2 = schema.rawDatabase;
    v2.execute(
      'INSERT INTO task_cards (id, day_key, title, x, y, width, height, '
      'z_index, color_argb, status, carried_over, original_day_key, '
      'created_at, updated_at, event_time, event_time_precision, '
      'event_time_pending, due_time, due_time_precision, due_time_pending) '
      "VALUES ('timed', ?, '有时间', 0, 0, 180, 88, 1, ?, 'active', 0, ?, ?, ?, "
      "'2026-10-21T13:00:00.000Z', 'dateTime', 0, ?, 'date', 1)",
      ['$today', 0xFFCDEBC5, '$today', created, created, '${today.addDays(5)}'],
    );
    v2.execute(
      "INSERT INTO app_meta (key, value) VALUES ('schemaVersion', '2'), "
      "('lastMaintenanceDay', '$today')",
    );

    final db = PlannerDatabase(schema.newConnection());
    final service = PlannerService(database: db, clock: Clock(() => now));
    await service.open();

    final card = (await service.watchDay(today).first).cards.single;
    expect(card.eventTime, CardTime.dateTime(DateTime.utc(2026, 10, 21, 13)));
    expect(card.dueTime, CardTime.date(today.addDays(5), pending: true));
    final meta = await db.select(db.appMeta).get();
    expect(
      {for (final m in meta) m.key: m.value},
      {'schemaVersion': '${db.schemaVersion}', 'lastMaintenanceDay': '$today'},
    );

    await db.close();
  });

  test('从 v3 升级到 v4 后，导入过的文件和邮件都还在，同一个文件不会再导入', () async {
    final schema = await verifier.schemaAt(3);
    final v3 = schema.rawDatabase;
    final bytes = encode(fakeEnvelope([fakeMessage(subject: '旧邮件')]));
    v3.execute(
      'INSERT INTO mail_export_files (id, file_name, file_size, '
      'file_modified_at, content_hash, status, mailbox, mail_count, '
      'new_mail_count, skipped_count, first_seen_at, imported_at) '
      "VALUES ('file', 'mail-1.json', ?, ?, ?, 'imported', "
      "'her@example.com', 1, 1, 0, ?, ?)",
      [
        bytes.length,
        created,
        sha256.convert(bytes).toString(),
        created,
        created,
      ],
    );
    v3.execute(
      'INSERT INTO mails (id, mailbox, mail_key, mail_key_kind, subject, '
      'analysis_status, source_file_id, imported_at) '
      "VALUES ('mail', 'her@example.com', '<default@example.com>', "
      "'internetMessageId', '旧邮件', 'done', 'file', ?)",
      [created],
    );
    v3.execute(
      "INSERT INTO app_meta (key, value) VALUES ('schemaVersion', '3')",
    );

    final db = PlannerDatabase(schema.newConnection());
    final planner = PlannerService(database: db, clock: Clock(() => now));
    await planner.open();
    final mail = MailService(planner: planner, clock: Clock(() => now));

    expect((await mail.watchMails().first).map((m) => m.subject), ['旧邮件']);
    final directory = Directory.systemTemp.createTempSync('migration_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/mail-1.json')..writeAsBytesSync(bytes);
    expect(await mail.importFile(file.path), isA<AlreadyImported>());

    await db.close();
  });
}
