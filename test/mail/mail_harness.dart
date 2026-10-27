import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/storage/planner_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/failing_storage.dart';
import 'fake_analyzer.dart';
import 'mail_fixtures.dart';

/// 切入点 3 的测试环境：真实的 [MailService] 和 [PlannerService] + 内存
/// SQLite + 假时钟 + 临时目录 + 假分析器。
///
/// 底层的内存数据库在 [reopen] 之后仍然保留，用来模拟"重启 App"。
class MailHarness {
  MailHarness()
    : _sqlite = sqlite3.openInMemory(),
      directory = Directory.systemTemp.createTempSync('mail_harness_') {
    _open();
  }

  final Database _sqlite;
  final _failingStorage = FailingStorage();
  late PlannerDatabase _database;
  late MailService mail;
  late PlannerService planner;

  /// 按脚本返回结果的分析器，[reopen] 之后还是同一个。
  final analyzer = FakeAnalyzer();

  /// 放导出文件的临时目录。
  final Directory directory;

  /// 假时钟的当前时间（本地时间），可以直接修改来模拟时间流逝。
  DateTime now = DateTime(2026, 10, 20, 9);

  DayKey get today => DayKey.fromDateTime(now);

  /// 打开后，所有写入都会报错；读取不受影响。
  set failWrites(bool value) =>
      _failingStorage.writesBeforeFailure = value ? 0 : null;

  /// 之后的 [count] 次写入成功，再往后的写入都报错，用来模拟事务中途失败。
  void failWritesAfter(int count) =>
      _failingStorage.writesBeforeFailure = count;

  void _open() {
    _database = PlannerDatabase(
      NativeDatabase.opened(
        _sqlite,
        closeUnderlyingOnClose: false,
      ).interceptWith(_failingStorage),
    );
    final clock = Clock(() => now);
    planner = PlannerService(database: _database, clock: clock);
    mail = MailService(
      planner: planner,
      analyzer: analyzer,
      clock: clock,
      timeZoneName: () => 'Eastern Daylight Time',
    );
  }

  /// 关闭当前连接，在同一个内存数据库上重新建立数据库连接和 service。
  Future<void> reopen() async {
    await mail.waitForAnalysis();
    await _database.close();
    _open();
  }

  /// 在临时目录里写一个文件，返回它的路径。[content] 是 JSON 值或者字节。
  String writeFile(String name, Object? content) {
    final file = File('${directory.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(content is List<int> ? content : encode(content));
    return file.path;
  }

  /// 扫描两次邮件文件夹，中间隔一分钟：第一次看到的文件第二次才会读取。
  Future<void> scanTwice() async {
    await mail.scanFolder();
    now = now.add(const Duration(minutes: 1));
    await mail.scanFolder();
  }

  /// 写一个文件并导入。
  Future<ImportOutcome> importJson(String name, Object? content) =>
      mail.importFile(writeFile(name, content));

  /// 预览列表里所有邮件的主题。
  Future<List<String>> subjects() async =>
      (await mail.watchMails().first).map((m) => m.subject).toList();

  Future<void> dispose() async {
    await mail.waitForAnalysis();
    await _database.close();
    _sqlite.close();
    directory.deleteSync(recursive: true);
  }
}
