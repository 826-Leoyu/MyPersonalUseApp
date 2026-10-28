// M-41：检查 release 打包目录里有没有开发电脑的痕迹。在 Windows 一侧的
// 仓库根目录运行（步骤见 docs/RELEASE.md）：
//
//     dart run tool/release_check/check_release.dart build\windows\x64\runner\Release
//
// 测试邮箱、OneDrive 账号这些从本机查不出来的，一行一个写进
// tool/release_check/local_traces.txt（不进仓库）。没有这个文件时不检查，
// 直接退出。
// ignore_for_file: avoid_print
import 'dart:io';

import 'release_traces.dart';

const _localListPath = 'tool/release_check/local_traces.txt';

void main(List<String> args) {
  if (args.length != 1) {
    print('用法：dart run tool/release_check/check_release.dart <release 目录>');
    exit(2);
  }
  final dir = Directory(args.single);
  if (!dir.existsSync()) {
    print('找不到 ${dir.path}，先运行 flutter build windows --release');
    exit(2);
  }
  final localList = File(_localListPath);
  if (!localList.existsSync()) {
    print('找不到 $_localListPath。把测试邮箱和 OneDrive 账号一行一个写进去再运行。');
    exit(2);
  }

  final git = Process.runSync('git', ['config', 'user.email']);
  final keyProperties = File('android/key.properties');
  final traces = collectTraces(
    env: Platform.environment,
    dartExecutable: Platform.resolvedExecutable,
    gitEmail: git.exitCode == 0 ? '${git.stdout}' : null,
    keyProperties: keyProperties.existsSync()
        ? keyProperties.readAsStringSync()
        : null,
    localList: localList.readAsStringSync(),
  );

  print('要找的痕迹：');
  for (final trace in traces) {
    print('  $trace');
  }
  final hits = findTraces(dir, traces);
  if (hits.isEmpty) {
    print('✅ ${dir.path} 里没有找到开发电脑的痕迹');
    return;
  }
  print('❌ 找到 ${hits.length} 处开发电脑的痕迹：');
  for (final hit in hits) {
    print('  $hit');
  }
  exit(1);
}
