// AC-39 代码审查部分的守卫：release 版不申请网络权限，代码里没有网络请求。
// 插件在 manifest 合并时带进来的权限这里查不到，打包后要再看一次 APK。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 主 manifest 没有申请 INTERNET 权限', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('lib 里没有网络请求', () {
    final network = RegExp(
      r'''\b(HttpClient|HttpServer|WebSocket|Socket|RawSocket|SecureSocket)\b'''
      r'''|package:(http|dio|web_socket_channel)/''',
    );
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            network.hasMatch(file.readAsStringSync()))
          file.path,
    ];

    expect(offenders, isEmpty);
  });
}
