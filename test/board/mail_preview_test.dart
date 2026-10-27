// 切入点 2：手动导入导出文件、邮件预览和设置里的邮箱地址（M-4、M-5、M-8、M-12）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/mail/mail_preview_page.dart';
import 'package:my_personal_use_app/settings/settings_page.dart';

import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;
  late Directory directory;

  setUp(() {
    harness = BoardHarness();
    directory = Directory.systemTemp.createTempSync('mail_preview_');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  /// 在 Windows 上跑的测试。平台要在测试结束前改回来，否则测试框架报错。
  void windowsTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  /// 在临时目录里写一个导出文件，下次「导入文件」时选中它。
  void pick(String name, Object? content) {
    final file = File('${directory.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(content is List<int> ? content : encode(content));
    harness.pickedMailFile = file.path;
  }

  /// 等文件读写和数据库写入跑完，直到 [text] 出现。
  Future<void> waitForText(WidgetTester tester, String text) async {
    await harness.pumpData(
      tester,
      rounds: 50,
      until: () => find.text(text).evaluate().isNotEmpty,
    );
    expect(find.text(text), findsOneWidget);
  }

  Future<void> openMailPreview(WidgetTester tester) async {
    await harness.launch(tester);
    await tester.tap(find.byKey(BoardPage.mailButtonKey));
    await harness.settle(tester);
  }

  Future<void> tapImport(WidgetTester tester) async {
    await tester.tap(find.byKey(MailPreviewPage.importButtonKey));
    await tester.pump();
  }

  // 收件时间按本地时区显示，所以用本地时间造数据。
  final received = DateTime(2026, 10, 19, 9, 15).toUtc().toIso8601String();

  windowsTest('导入信封格式的文件，预览里能看到主题、发件人和收件时间', (tester) async {
    await openMailPreview(tester);
    expect(find.text('还没有导入邮件'), findsOneWidget);
    pick(
      'mail-1.json',
      fakeEnvelope([
        fakeMessage(
          subject: '周五组会改到 3 点',
          from: {
            'emailAddress': {'name': '李明', 'address': 'li.ming@example.com'},
          },
          receivedDateTime: received,
        ),
      ]),
    );

    await tapImport(tester);
    await waitForText(tester, '已导入 mail-1.json：新邮件 1 封');
    await harness.settle(tester);

    expect(find.text('周五组会改到 3 点'), findsOneWidget);
    expect(find.text('李明 · Oct 19 09:15'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('点开一封邮件，看到转换后的正文和编号的链接', (tester) async {
    await openMailPreview(tester);
    pick(
      'mail-1.json',
      fakeEnvelope([
        fakeMessage(
          subject: '秋季招聘会',
          body:
              '<p>请在周五前<a href="https://example.com/signup">报名</a>。</p>'
              '<blockquote>招聘会在哪里？</blockquote>'
              '<img src="cid:poster@01DB" alt="海报">',
        ),
        fakeMessage(
          internetMessageId: '<b@example.com>',
          subject: '图书馆通知',
          body: '',
          bodyPreview: '图书馆周六闭馆',
        ),
      ]),
    );
    await tapImport(tester);
    await waitForText(tester, '已导入 mail-1.json：新邮件 2 封');
    await harness.settle(tester);

    await tester.tap(find.text('秋季招聘会'));
    await harness.settle(tester);

    expect(
      find.text('请在周五前报名 [1]。\n\n[引用]\n招聘会在哪里？\n[/引用]\n\n[图片: 海报]'),
      findsOneWidget,
    );
    expect(find.text('[1] https://example.com/signup'), findsOneWidget);
    expect(find.text('有内嵌图片'), findsOneWidget);
    expect(find.text('正文可能不完整'), findsNothing);

    await tester.pageBack();
    await harness.settle(tester);
    await tester.tap(find.text('图书馆通知'));
    await harness.settle(tester);

    expect(find.text('图书馆周六闭馆'), findsOneWidget);
    expect(find.text('正文可能不完整'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('格式错误的文件提示文件名，列表不变', (tester) async {
    await openMailPreview(tester);
    pick('mail-bad.json', 'not json'.codeUnits);

    await tapImport(tester);
    await waitForText(tester, '文件 mail-bad.json 格式错误，已跳过');

    expect(find.text('还没有导入邮件'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('取消选择文件时什么都不做', (tester) async {
    await openMailPreview(tester);

    await tapImport(tester);
    await harness.settle(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('还没有导入邮件'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('裸数组需要邮箱地址：去设置里填写以后再导入，邮件入库', (tester) async {
    await openMailPreview(tester);
    pick('mail-old.json', [fakeMessage(subject: 'Library books due')]);

    await tapImport(tester);
    await waitForText(tester, 'mail-old.json 没有写明邮箱，请先在设置里填写邮箱地址');
    expect(find.text('还没有导入邮件'), findsOneWidget);
    await harness.settle(tester);

    await tester.tap(find.text('去设置'));
    await harness.settle(tester);
    await tester.tap(find.byKey(SettingsPage.mailboxTileKey));
    await harness.settle(tester);
    await tester.enterText(
      find.byKey(SettingsPage.mailboxFieldKey),
      'Her@Example.com',
    );
    await tester.tap(find.text('保存'));
    await waitForText(tester, 'her@example.com');

    await tester.pageBack();
    await harness.settle(tester);
    await tapImport(tester);
    await waitForText(tester, '已导入 mail-old.json：新邮件 1 封');
    await harness.settle(tester);

    expect(find.text('Library books due'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('邮箱地址格式不对时留在对话框里提示', (tester) async {
    await harness.launch(tester);
    await tester.tap(find.byKey(BoardPage.settingsButtonKey));
    await harness.settle(tester);
    await tester.tap(find.byKey(SettingsPage.mailboxTileKey));
    await harness.settle(tester);

    await tester.enterText(find.byKey(SettingsPage.mailboxFieldKey), 'nope');
    await tester.tap(find.text('保存'));
    await waitForText(tester, '邮箱地址格式不对');

    expect(find.byType(AlertDialog), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('Android 上没有邮件和设置的入口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await harness.launch(tester);

      expect(find.byKey(BoardPage.mailButtonKey), findsNothing);
      expect(find.byKey(BoardPage.settingsButtonKey), findsNothing);
      await harness.dispose(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
