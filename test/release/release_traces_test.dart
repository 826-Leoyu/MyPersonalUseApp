// M-41：release 包里找开发电脑痕迹的逻辑（tool/release_check）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_check/release_traces.dart';

void main() {
  group('collectTraces', () {
    test('从环境变量里取用户名、用户目录和 OneDrive 目录；电脑名和空的不要', () {
      final traces = collectTraces(
        env: {
          'USERNAME': 'devuser',
          'COMPUTERNAME': 'DEV-PC',
          'USERPROFILE': r'C:\Users\devuser',
          'OneDrive': r'C:\Users\devuser\OneDrive',
          'OneDriveCommercial': ' ',
          'PATH': r'C:\Windows',
        },
        dartExecutable: r'C:\tools\dart.exe',
      );

      expect(traces.map((t) => t.value), [
        'devuser',
        r'C:\Users\devuser',
        r'C:\Users\devuser\OneDrive',
      ]);
    });

    test('从 dart 的位置找出 Flutter SDK 目录', () {
      final traces = collectTraces(
        env: const {},
        dartExecutable: r'D:\Dev\flutter\bin\cache\dart-sdk\bin\dart.exe',
      );

      expect(traces.single.value, r'D:\Dev\flutter');
    });

    test('git 邮箱、key.properties 的密码和本地清单都算；密码和密钥标成凭据', () {
      final traces = collectTraces(
        env: const {'ANTHROPIC_API_KEY': 'sk-ant-xyz'},
        dartExecutable: 'dart',
        gitEmail: 'dev@example.com\n',
        keyProperties:
            'storePassword=s3cret=1\nkeyPassword=k3y\nkeyAlias=dailycanvas\n',
        localList: '# 测试邮箱\ntest.mailbox@example.edu\n\n  devuser@onedrive.example  \n',
      );

      expect(
        [for (final t in traces) (t.value, t.secret)],
        [
          ('sk-ant-xyz', true),
          ('dev@example.com', false),
          ('s3cret=1', true),
          ('k3y', true),
          ('test.mailbox@example.edu', false),
          ('devuser@onedrive.example', false),
        ],
      );
    });

    test('凭据在报告里不显示内容', () {
      const trace = Trace(
        'key.properties storePassword',
        's3cret',
        secret: true,
      );

      expect('$trace', isNot(contains('s3cret')));
    });
  });

  group('findTraces', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('release_traces'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String name, List<int> bytes) => (File(
      '${dir.path}/$name',
    )..createSync(recursive: true)).writeAsBytesSync(bytes);

    const profile = Trace('USERPROFILE', r'C:\Users\devuser');

    test('没有痕迹时什么都不报', () {
      write('app.so', utf8.encode(r'file:///E:/MyPersonalUseApp/main.dart'));

      expect(findTraces(dir, [profile]), isEmpty);
    });

    test('找得到不同写法的路径：反斜杠、斜杠、JSON 转义、大小写不同', () {
      write('a.json', utf8.encode(r'"C:\\Users\\devuser\\x.dll"'));
      write('b.so', utf8.encode('file:///c:/users/DEVUSER/a.dart'));
      write('c.txt', utf8.encode(r'C:\Users\devuser'));

      expect(findTraces(dir, [profile]).map((h) => h.path), [
        'a.json',
        'b.so',
        'c.txt',
      ]);
    });

    test('找得到 exe、dll 里的 UTF-16 字符串', () {
      final utf16 = [
        for (final unit in r'C:\Users\devuser'.codeUnits) ...[unit, 0],
      ];
      write('Dailynote.exe', [0, 1, 2, ...utf16, 3]);

      expect(findTraces(dir, [profile]).single.path, 'Dailynote.exe');
    });

    test('子目录里的文件也查，路径用斜杠', () {
      write('data/flutter_assets/NOTICES', utf8.encode('mail dev@example.com'));

      expect(
        findTraces(dir, [
          const Trace('git user.email', 'dev@example.com'),
        ]).single.path,
        'data/flutter_assets/NOTICES',
      );
    });
  });
}
