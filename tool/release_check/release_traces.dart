/// M-41：release 包里不能有开发电脑的痕迹。
///
/// 要找的字符串在运行时从本机收集，不写进仓库（仓库是公开的）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 开发电脑上的一个痕迹。
class Trace {
  const Trace(this.source, this.value, {this.secret = false});

  /// 从哪里来的，比如 `USERPROFILE`。
  final String source;

  /// 要找的字符串。
  final String value;

  /// 是凭据时为 true，报告里不打印 [value]。
  final bool secret;

  @override
  String toString() => secret ? '$source（凭据）' : '$source：$value';
}

/// 在 release 包的一个文件里找到了 [trace]。
class TraceHit {
  const TraceHit(this.path, this.trace);

  /// 相对 release 目录的路径。
  final String path;
  final Trace trace;

  @override
  String toString() => '$path  ←  $trace';
}

/// 环境变量里的用户名和指向用户目录、OneDrive 的那些。电脑名不查：常常是
/// 一个普通单词（比如 RAIN），在 dll 里到处都是。
const _envKeys = [
  'USERNAME',
  'USERPROFILE',
  'OneDrive',
  'OneDriveCommercial',
  'OneDriveConsumer',
  'PUB_CACHE',
];

/// 环境变量里可能放着的密钥。
const _secretEnvKeys = ['ANTHROPIC_API_KEY', 'CLAUDE_CODE_OAUTH_TOKEN'];

/// 收集开发电脑的痕迹：
///
/// - [env] 里的用户名、用户目录、OneDrive 目录、pub 缓存和密钥；
/// - [dartExecutable] 所在的 Flutter SDK 目录；
/// - [gitEmail]：git 提交用的邮箱；
/// - [keyProperties]：`android/key.properties` 的内容，取里面的密码；
/// - [localList]：本地清单 `local_traces.txt` 的内容，一行一个，`#` 开头是注释。
///   测试邮箱和 OneDrive 账号写在这里。
List<Trace> collectTraces({
  required Map<String, String> env,
  required String dartExecutable,
  String? gitEmail,
  String? keyProperties,
  String? localList,
}) {
  final traces = <Trace>[
    for (final key in _envKeys)
      if (env[key] case final value? when value.trim().isNotEmpty)
        Trace(key, value.trim()),
    for (final key in _secretEnvKeys)
      if (env[key] case final value? when value.trim().isNotEmpty)
        Trace(key, value.trim(), secret: true),
  ];

  final sdk = _flutterRoot(dartExecutable);
  if (sdk != null) traces.add(Trace('Flutter SDK', sdk));

  if (gitEmail != null && gitEmail.trim().isNotEmpty) {
    traces.add(Trace('git user.email', gitEmail.trim()));
  }

  for (final line in LineSplitter.split(keyProperties ?? '')) {
    final eq = line.indexOf('=');
    if (eq < 0) continue;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key.endsWith('Password') && value.isNotEmpty) {
      traces.add(Trace('key.properties $key', value, secret: true));
    }
  }

  for (final line in LineSplitter.split(localList ?? '')) {
    final value = line.trim();
    if (value.isNotEmpty && !value.startsWith('#')) {
      traces.add(Trace('local_traces.txt', value));
    }
  }
  return traces;
}

/// `D:\flutter\bin\cache\dart-sdk\bin\dart.exe` → `D:\flutter`。
/// 不在 Flutter SDK 里时为 null。
String? _flutterRoot(String dartExecutable) {
  final match = RegExp(r'^(.+?)[\\/]bin[\\/]cache[\\/]dart-sdk[\\/]')
      .firstMatch(dartExecutable);
  return match?.group(1);
}

/// 在 [dir] 下所有文件里找 [traces]。不分大小写，UTF-8 和 UTF-16LE 都找；
/// 路径的 `\`、`/` 和 JSON 里转义的 `\\` 都算。
List<TraceHit> findTraces(Directory dir, List<Trace> traces) {
  final needles = [
    for (final trace in traces)
      for (final variant in _variants(trace.value))
        for (final bytes in [utf8.encode(variant), _utf16le(variant)])
          (trace, _lowerAscii(bytes)),
  ];

  final hits = <TraceHit>[];
  final files = dir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final haystack = _lowerAscii(file.readAsBytesSync());
    final path = file.path.substring(dir.path.length + 1).replaceAll(r'\', '/');
    final found = <Trace>{};
    for (final (trace, needle) in needles) {
      if (!found.contains(trace) && haystack.contains(needle)) {
        found.add(trace);
        hits.add(TraceHit(path, trace));
      }
    }
  }
  return hits;
}

Iterable<String> _variants(String value) => {
  value,
  value.replaceAll(r'\', '/'),
  value.replaceAll('/', r'\'),
  value.replaceAll('/', r'\').replaceAll(r'\', r'\\'),
};

List<int> _utf16le(String value) => [
  for (final unit in value.codeUnits) ...[unit & 0xff, unit >> 8],
];

/// 把 A-Z 换成 a-z，再按 latin1 变成字符串，好用 [String.contains] 找字节。
String _lowerAscii(List<int> bytes) {
  final lower = Uint8List.fromList(bytes);
  for (var i = 0; i < lower.length; i++) {
    if (lower[i] >= 0x41 && lower[i] <= 0x5a) lower[i] += 0x20;
  }
  return latin1.decode(lower);
}
