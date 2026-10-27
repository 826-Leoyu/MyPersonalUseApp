// 切入点 3：自动扫描邮件文件夹（M-31 ～ M-37）。邮件文件夹是一个真实的临时
// 目录。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/import_status.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';

import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() async {
    h = MailHarness();
    await h.mail.setMailFolder(h.directory.path);
  });
  tearDown(() => h.dispose());

  Map<String, Object?> mail(String key, {String? at}) => fakeMessage(
    internetMessageId: '<$key@example.com>',
    id: 'AAMk-$key',
    subject: 'Mail $key',
    receivedDateTime: at ?? '2026-10-19T14:30:00Z',
  );

  group('扫描（M-32）', () {
    test('只读取 mail-*.json', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      h.writeFile('notes.json', fakeEnvelope([mail('b')]));
      h.writeFile('mail-2.txt', fakeEnvelope([mail('c')]));
      h.writeFile('old-mail-3.json', fakeEnvelope([mail('d')]));

      await h.scanTwice();

      expect(await h.subjects(), ['Mail a']);
    });
  });

  group('文件稳定（M-33）', () {
    test('第一次看到的文件不读取，下一次扫描才读取', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));

      await h.mail.scanFolder();
      expect(await h.subjects(), isEmpty);

      h.now = h.now.add(const Duration(minutes: 5));
      await h.mail.scanFolder();
      expect(await h.subjects(), ['Mail a']);
    });

    test('大小或修改时间还在变的文件不读取，不变以后才读取', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();

      h.writeFile('mail-1.json', fakeEnvelope([mail('a'), mail('b')]));
      await h.mail.scanFolder();
      expect(await h.subjects(), isEmpty);

      await h.mail.scanFolder();
      expect(await h.subjects(), unorderedEquals(['Mail a', 'Mail b']));
    });

    test('只改了修改时间的文件也要等下一次', () async {
      final path = h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();

      File(path).setLastModifiedSync(DateTime(2026, 10, 20, 8));
      await h.mail.scanFolder();
      expect(await h.subjects(), isEmpty);

      await h.mail.scanFolder();
      expect(await h.subjects(), ['Mail a']);
    });
  });

  group('App 关着时同步过来的文件（M-34）', () {
    test('上次看到的文件，重启后第一次扫描就导入并分析', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();

      await h.reopen();
      await h.mail.scanFolder();
      await h.mail.waitForAnalysis();

      expect(await h.subjects(), ['Mail a']);
      expect(h.analyzer.analyzedSubjects, ['Mail a']);
    });
  });

  group('解析失败（M-33）', () {
    test('稳定不到 10 分钟时算正在同步，下次扫描再试', () async {
      h.writeFile('mail-1.json', utf8.encode('{"format": "dailynote-mail'));
      await h.scanTwice();

      expect((await h.mail.importStatus()).notices, [const FilesSyncing()]);

      // 同步完成：同一个文件写完整了。
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      expect(await h.subjects(), ['Mail a']);
      expect((await h.mail.importStatus()).notices, isEmpty);
    });

    test('稳定超过 10 分钟还解析不了时算格式错误，跳过它，不影响其他文件', () async {
      h.writeFile('mail-1.json', utf8.encode('not json'));
      h.writeFile('mail-2.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();
      h.now = h.now.add(const Duration(minutes: 10));
      await h.mail.scanFolder();

      expect(await h.subjects(), ['Mail a']);
      expect((await h.mail.importStatus()).notices, [
        const FormatErrors(['mail-1.json']),
      ]);
    });

    // 只在 Windows 上跑：Linux、macOS 的文件锁只是约定，别的程序照样读得到。
    test('被别的程序锁住、读不出来的文件算正在同步，解锁后导入', () async {
      final path = h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();
      final locked = File(path).openSync(mode: FileMode.append)
        ..lockSync(FileLock.exclusive);
      h.now = h.now.add(const Duration(minutes: 30));
      await h.mail.scanFolder();

      expect(await h.subjects(), isEmpty);
      expect((await h.mail.importStatus()).notices, [const FilesSyncing()]);

      locked.closeSync();
      await h.mail.scanFolder();
      expect(await h.subjects(), ['Mail a']);
    }, skip: !Platform.isWindows);
  });

  group('文件夹（M-35）', () {
    test('没选择文件夹时提示开始设置，扫描什么都不做', () async {
      final fresh = MailHarness();
      addTearDown(fresh.dispose);

      await fresh.mail.scanFolder();

      expect((await fresh.mail.importStatus()).notices, [const FolderNotSet()]);
    });

    test('文件夹被改名后提示找不到文件夹，改回来以后恢复', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();
      final renamed = h.directory.renameSync('${h.directory.path}-renamed');

      await h.mail.scanFolder();
      expect((await h.mail.importStatus()).notices, [const FolderMissing()]);

      renamed.renameSync(h.directory.path);
      await h.mail.scanFolder();
      expect(await h.subjects(), ['Mail a']);
      expect((await h.mail.importStatus()).notices, isEmpty);
    });

    test('看到过、还没读的文件被删掉以后，不再算正在同步', () async {
      final path = h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.scanFolder();
      File(path).deleteSync();

      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, isEmpty);
    });

    test('格式错误的文件被删掉以后，不再提示格式错误', () async {
      final path = h.writeFile('mail-1.json', utf8.encode('not json'));
      await h.mail.scanFolder();
      h.now = h.now.add(const Duration(minutes: 10));
      await h.mail.scanFolder();
      expect((await h.mail.importStatus()).notices, [
        const FormatErrors(['mail-1.json']),
      ]);
      File(path).deleteSync();

      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, isEmpty);
    });

    test('找不到文件夹时，分析的提示照样列出来', () async {
      h.analyzer.fails('Mail a', AnalysisFailureType.notLoggedIn);
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      await h.mail.analyzePending();
      final renamed = h.directory.renameSync('${h.directory.path}-renamed');
      addTearDown(() => renamed.renameSync(h.directory.path));

      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, [
        const FolderMissing(),
        const ClaudeNotLoggedIn(),
      ]);
    });
  });

  group('状态行（M-35）', () {
    test('上次导入的时间和这次扫描新入库的邮件数', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a'), mail('b')]));
      h.writeFile('mail-2.json', fakeEnvelope([mail('b'), mail('c')]));
      await h.scanTwice();
      final importedAt = h.now;

      // 之后的扫描没有新文件，上次导入不变。
      h.now = h.now.add(const Duration(minutes: 5));
      await h.mail.scanFolder();

      final status = await h.mail.importStatus();
      expect(status.notices, isEmpty);
      expect(status.lastImportAt, importedAt.toUtc());
      expect(status.lastImportNewMailCount, 3);
    });

    test('还没导入过时没有上次导入', () async {
      final status = await h.mail.importStatus();

      expect(status.lastImportAt, isNull);
      expect(status.notices, isEmpty);
    });

    test('超过 2 天没有新文件时提醒检查流程，有新文件以后消失', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      final seenAt = h.now.subtract(const Duration(minutes: 1));

      h.now = seenAt.add(const Duration(days: 2));
      await h.mail.scanFolder();
      expect((await h.mail.importStatus()).notices, isEmpty);

      h.now = h.now.add(const Duration(minutes: 1));
      await h.mail.scanFolder();
      expect((await h.mail.importStatus()).notices, [
        NoNewFiles(seenAt.toUtc()),
      ]);

      h.writeFile('mail-2.json', fakeEnvelope([mail('b')]));
      await h.mail.scanFolder();
      expect(
        (await h.mail.importStatus()).notices,
        isNot(contains(isA<NoNewFiles>())),
      );
    });

    test('选择文件夹以后 2 天都没有文件也提醒', () async {
      final chosenAt = h.now;

      h.now = chosenAt.add(const Duration(days: 2, minutes: 1));
      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, [
        NoNewFiles(chosenAt.toUtc()),
      ]);
    });

    test('格式错误的文件不算有新文件', () async {
      final chosenAt = h.now;
      h.now = chosenAt.add(const Duration(days: 1));
      h.writeFile('mail-1.json', utf8.encode('not json'));
      await h.mail.scanFolder();
      h.now = h.now.add(const Duration(minutes: 10));
      await h.mail.scanFolder();

      h.now = chosenAt.add(const Duration(days: 2, minutes: 1));
      await h.mail.scanFolder();

      expect(
        (await h.mail.importStatus()).notices,
        contains(NoNewFiles(chosenAt.toUtc())),
      );
    });

    test('多个问题时按状态行的顺序排列', () async {
      final chosenAt = h.now;
      h.writeFile('mail-1.json', utf8.encode('not json'));
      await h.mail.scanFolder();
      h.now = h.now.add(const Duration(minutes: 10));
      h.writeFile('mail-2.json', utf8.encode('not json either'));
      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, [
        const FilesSyncing(),
        const FormatErrors(['mail-1.json']),
      ]);

      h.now = h.now.add(const Duration(days: 3));
      await h.mail.scanFolder();

      expect((await h.mail.importStatus()).notices, [
        const FormatErrors(['mail-1.json', 'mail-2.json']),
        NoNewFiles(chosenAt.toUtc()),
      ]);
    });
  });

  group('空档（M-36）', () {
    // 这里一次导入几百封邮件，会碰到每天自动分析的上限；只看导入的提示。
    Future<List<ImportNotice>> importNotices() async => [
      for (final notice in (await h.mail.importStatus()).notices)
        if (notice is! AnalysisPaused) notice,
    ];

    /// 满的导出文件：从 [from] 起每分钟一封，共 [MailService.exportBatchSize]
    /// 封，最新的在前。
    Map<String, Object?> fullFile(String prefix, DateTime from) =>
        fakeEnvelope([
          for (var i = MailService.exportBatchSize - 1; i >= 0; i--)
            mail(
              '$prefix$i',
              at: from.add(Duration(minutes: i)).toUtc().toIso8601String(),
            ),
        ]);

    test('两个满的文件之间有空档时提示可能漏了邮件', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      await h.scanTwice();
      h.writeFile('mail-2.json', fullFile('b', DateTime.utc(2026, 10, 19)));
      await h.scanTwice();

      expect(await importNotices(), [const PossiblyMissedMails()]);
    });

    test('空档后面又来了正常的文件，提示还在', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      await h.scanTwice();
      h.writeFile('mail-2.json', fullFile('b', DateTime.utc(2026, 10, 19)));
      await h.scanTwice();

      h.writeFile(
        'mail-3.json',
        fakeEnvelope([mail('c', at: '2026-10-19T04:00:00Z')]),
      );
      await h.scanTwice();

      expect(await importNotices(), [const PossiblyMissedMails()]);
    });

    test('一次扫描导入好几个文件时，中间的空档也提示', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      h.writeFile('mail-2.json', fullFile('b', DateTime.utc(2026, 10, 19)));
      h.writeFile(
        'mail-3.json',
        fakeEnvelope([mail('c', at: '2026-10-19T04:00:00Z')]),
      );
      await h.scanTwice();

      expect(await importNotices(), [const PossiblyMissedMails()]);
    });

    test('空档后面的文件导入 14 天以后不再提示', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      await h.scanTwice();
      h.writeFile('mail-2.json', fullFile('b', DateTime.utc(2026, 10, 19)));
      await h.scanTwice();
      final importedAt = h.now;

      h.now = importedAt.add(MailService.keepExportFilesFor);
      expect(
        (await h.mail.importStatus()).notices,
        contains(const PossiblyMissedMails()),
      );

      h.now = h.now.add(const Duration(minutes: 1));
      expect(
        (await h.mail.importStatus()).notices,
        isNot(contains(const PossiblyMissedMails())),
      );
    });

    test('有重叠时不提示', () async {
      final from = DateTime.utc(2026, 10, 18);
      h.writeFile('mail-1.json', fullFile('a', from));
      await h.scanTwice();
      h.writeFile(
        'mail-2.json',
        fullFile('b', from.add(const Duration(minutes: 199))),
      );
      await h.scanTwice();

      expect(await importNotices(), isEmpty);
    });

    test('有一个文件不满时不提示', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      await h.scanTwice();
      h.writeFile(
        'mail-2.json',
        fakeEnvelope([mail('b', at: '2026-10-19T12:00:00Z')]),
      );
      await h.scanTwice();

      expect(await importNotices(), isEmpty);
    });

    test('手动补读把空档补上以后不再提示', () async {
      h.writeFile('mail-1.json', fullFile('a', DateTime.utc(2026, 10, 18)));
      await h.scanTwice();
      h.writeFile('mail-2.json', fullFile('b', DateTime.utc(2026, 10, 19)));
      await h.scanTwice();

      // 补读的文件从第一个文件的时间一直到第二个文件。
      h.writeFile(
        'mail-3.json',
        fakeEnvelope([
          mail('fill', at: '2026-10-19T00:30:00Z'),
          mail('a199', at: '2026-10-18T03:19:00Z'),
        ]),
      );
      await h.scanTwice();

      expect(await importNotices(), isEmpty);
    });
  });

  group('清理导出文件（M-37）', () {
    bool exists(String name) => File('${h.directory.path}/$name').existsSync();

    test('导入超过 14 天、邮件都分析过的文件被删除，没到 14 天的留着', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      await h.mail.waitForAnalysis();
      final importedAt = h.now;
      h.now = importedAt.add(const Duration(days: 7));
      h.writeFile('mail-2.json', fakeEnvelope([mail('b')]));
      await h.scanTwice();
      await h.mail.waitForAnalysis();

      h.now = importedAt.add(const Duration(days: 14));
      await h.mail.scanFolder();
      expect(exists('mail-1.json'), isTrue);

      h.now = importedAt.add(const Duration(days: 14, minutes: 1));
      await h.mail.scanFolder();
      expect(exists('mail-1.json'), isFalse);
      expect(exists('mail-2.json'), isTrue);
      // 邮件还在。
      expect(await h.subjects(), unorderedEquals(['Mail a', 'Mail b']));
    });

    test('还有待分析邮件的文件不删除', () async {
      h.analyzer.fails('Mail a', AnalysisFailureType.temporary);
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      await h.mail.waitForAnalysis();

      h.now = h.now.add(const Duration(days: 15));
      await h.mail.scanFolder();

      expect(exists('mail-1.json'), isTrue);
    });

    test('格式错误的文件不删除', () async {
      h.writeFile('mail-1.json', utf8.encode('not json'));
      await h.mail.scanFolder();
      h.now = h.now.add(const Duration(minutes: 10));
      await h.mail.scanFolder();

      h.now = h.now.add(const Duration(days: 30));
      await h.mail.scanFolder();

      expect(exists('mail-1.json'), isTrue);
    });

    test('删除以后，空档检查还算着这个文件', () async {
      Map<String, Object?> full(String prefix, int day) => fakeEnvelope([
        for (var i = MailService.exportBatchSize - 1; i >= 0; i--)
          mail(
            '$prefix$i',
            at: DateTime.utc(2026, 10, day, 0, i).toIso8601String(),
          ),
      ]);
      h.writeFile('mail-1.json', full('a', 1));
      await h.scanTwice();
      await h.mail.waitForAnalysis();
      h.now = h.now.add(const Duration(days: 15));
      await h.mail.scanFolder();
      expect(exists('mail-1.json'), isFalse);

      h.writeFile('mail-2.json', full('b', 18));
      await h.scanTwice();

      expect(
        (await h.mail.importStatus()).notices,
        contains(const PossiblyMissedMails()),
      );
    });
  });

  group('选择文件夹（M-31）', () {
    test('检查结果是导出文件的个数和最新一个的修改时间', () async {
      final first = h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      final second = h.writeFile('mail-2.json', fakeEnvelope([mail('b')]));
      h.writeFile('notes.json', fakeEnvelope([mail('c')]));
      File(first).setLastModifiedSync(DateTime.utc(2026, 10, 20, 11));
      File(second).setLastModifiedSync(DateTime.utc(2026, 10, 19, 20));

      final check = await h.mail.checkFolder(h.directory.path);

      expect(check, isA<FolderFound>());
      check as FolderFound;
      expect(check.fileCount, 2);
      expect(check.latestFileAt, DateTime.utc(2026, 10, 20, 11));
    });

    test('空文件夹：0 个文件，没有最新时间', () async {
      final check = await h.mail.checkFolder(h.directory.path);

      expect(check, isA<FolderFound>().having((c) => c.fileCount, 'count', 0));
      expect((check as FolderFound).latestFileAt, isNull);
    });

    test('不存在的文件夹', () async {
      expect(
        await h.mail.checkFolder('${h.directory.path}-missing'),
        isA<FolderUnavailable>(),
      );
    });

    test('重新选择以后扫描新的文件夹，路径重新打开后还在', () async {
      final other = Directory.systemTemp.createTempSync('mail_folder_other_');
      addTearDown(() => other.deleteSync(recursive: true));
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      File('${other.path}/mail-9.json')
          .writeAsBytesSync(encode(fakeEnvelope([mail('z')])));

      await h.mail.setMailFolder(other.path);
      await h.reopen();
      await h.scanTwice();

      expect(await h.mail.mailFolder(), other.path);
      expect(await h.subjects(), ['Mail z']);
    });

    test('换到新文件夹以后，旧文件夹的记录不影响新文件夹里的同名文件', () async {
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      h.writeFile('mail-2.json', utf8.encode('not json'));
      await h.scanTwice();
      h.now = h.now.add(const Duration(minutes: 10));
      await h.mail.scanFolder();
      final other = Directory.systemTemp.createTempSync('mail_folder_other_');
      addTearDown(() => other.deleteSync(recursive: true));
      File('${other.path}/mail-1.json')
          .writeAsBytesSync(encode(fakeEnvelope([mail('z')])));

      await h.mail.setMailFolder(other.path);
      await h.scanTwice();

      expect(await h.subjects(), unorderedEquals(['Mail a', 'Mail z']));
      expect((await h.mail.importStatus()).notices, isEmpty);
    });
  });

  group('状态的变化', () {
    test('扫描以后推出新的状态，包括找不到文件夹', () async {
      final statuses = <MailImportStatus>[];
      final subscription = h.mail.watchImportStatus().listen(statuses.add);
      addTearDown(subscription.cancel);
      h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.scanTwice();
      await pumpEventQueue();
      expect(statuses.last.lastImportNewMailCount, 1);

      h.directory.renameSync('${h.directory.path}-renamed');
      addTearDown(
        () =>
            Directory('${h.directory.path}-renamed')
                .renameSync(h.directory.path),
      );
      await h.mail.scanFolder();
      await pumpEventQueue();

      expect(statuses.last.notices, [const FolderMissing()]);
    });
  });
}
