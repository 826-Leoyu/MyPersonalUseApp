// ClaudeCodeAnalyzer 的契约（M-28）：用假的进程运行器，检查命令行参数、
// 工作目录、标准输入、环境变量、失败类型和超时。参数和失败提示来自
// docs/research/claude-code-noninteractive.md（#82）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/claude_code_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';

void main() {
  const secret = '只在邮件正文里出现的一句话 7f3a';

  final request = AnalysisRequest(
    subject: 'Assignment 3',
    senderName: 'Dr. Example',
    senderAddress: 'prof@example.edu',
    receivedAt: DateTime.utc(2026, 10, 19, 13),
    importance: 'normal',
    bodyText: 'Submit by Friday. $secret',
    links: const [],
    hasAttachments: false,
    hasInlineImages: false,
    bodyPossiblyIncomplete: false,
    timeZone: 'Eastern Daylight Time',
    relatedItems: const [],
    markedUseful: false,
  );

  const validStructured = {
    'category': 'informational',
    'reason': 'Just a notice.',
    'items': <Object?>[],
  };

  String resultJson({
    bool isError = false,
    String result = '',
    Object? structured = validStructured,
    int? apiErrorStatus,
  }) => jsonEncode({
    'type': 'result',
    'subtype': 'success',
    'is_error': isError,
    'api_error_status': apiErrorStatus,
    'result': result,
    'structured_output': ?structured,
  });

  late FakeProcessStarter starter;
  late ClaudeCodeAnalyzer analyzer;

  ClaudeCodeAnalyzer analyzerWith({
    Map<String, String> environment = const {'PATH': '/usr/bin'},
    Duration timeout = const Duration(seconds: 5),
    Duration statusTimeout = const Duration(seconds: 5),
    String? executable = '/usr/bin/claude',
  }) => ClaudeCodeAnalyzer(
    startProcess: starter.start,
    environment: environment,
    findExecutable: (_) => executable,
    // 不在测试里真的执行 taskkill。
    killProcessTree: (process) async => process.kill(),
    timeout: timeout,
    statusTimeout: statusTimeout,
  );

  setUp(() {
    starter = FakeProcessStarter();
    analyzer = analyzerWith();
  });

  Matcher failsWith(AnalysisFailureType type) =>
      throwsA(isA<AnalysisFailed>().having((f) => f.type, 'type', type));

  group('调用方式', () {
    test('禁用全部工具，按 schema 输出 JSON', () async {
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);

      final args = starter.calls.single.arguments;
      expect(args.first, '-p');
      expect(args, containsAllInOrder(['--tools', '']));
      expect(args, containsAllInOrder(['--disallowedTools', 'mcp__*']));
      expect(args, containsAllInOrder(['--permission-mode', 'dontAsk']));
      expect(args, containsAllInOrder(['--output-format', 'json']));
      expect(args, contains('--json-schema'));
      expect(
        args,
        containsAll([
          '--safe-mode',
          '--strict-mcp-config',
          '--disable-slash-commands',
          '--no-session-persistence',
          '--system-prompt-file',
        ]),
      );
    });

    test('不用 --bare 和 --disallowedTools "*"', () async {
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);

      final args = starter.calls.single.arguments;
      expect(args, isNot(contains('--bare')));
      expect(args, isNot(contains('*')));
    });

    test('邮件内容只走标准输入，不出现在命令行参数里', () async {
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);

      final call = starter.calls.single;
      expect(call.arguments.join(' '), isNot(contains(secret)));
      expect(call.stdin, contains(secret));
      expect(jsonDecode(call.stdin), request.toJson());
    });

    test('提示词文件不在工作目录里，也不包含邮件内容', () async {
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);

      final call = starter.calls.single;
      expect(call.promptFileContent, isNot(contains(secret)));
      expect(call.promptFileContent, contains('不可信'));
      expect(
        File(call.promptFilePath).parent.path,
        isNot(call.workingDirectory),
      );
    });

    test('在新建的空临时目录里运行，用完删除', () async {
      starter.respond(stdout: resultJson());
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);
      await analyzer.analyze(request);

      final [first, second] = starter.calls;
      expect(first.workingDirectoryWasEmpty, isTrue);
      expect(first.workingDirectory, isNot(second.workingDirectory));
      expect(Directory(first.workingDirectory).existsSync(), isFalse);
      expect(File(first.promptFilePath).existsSync(), isFalse);
    });

    test('失败时临时目录也被删除', () async {
      starter.respond(stdout: 'not json', exitCode: 1);

      await expectLater(analyzer.analyze(request), throwsA(anything));

      expect(
        Directory(starter.calls.single.workingDirectory).existsSync(),
        isFalse,
      );
    });

    test('去掉会改变登录方式和父会话留下的环境变量，其他的保留', () async {
      analyzer = analyzerWith(
        environment: {
          'PATH': '/usr/bin',
          'HOME': '/home/her',
          'USERPROFILE': r'C:\Users\her',
          'CLAUDE_CONFIG_DIR': '/home/her/.claude',
          'HTTPS_PROXY': 'http://proxy.example:8080',
          'ANTHROPIC_API_KEY': 'sk-fake',
          'ANTHROPIC_AUTH_TOKEN': 'fake',
          'ANTHROPIC_BASE_URL': 'https://example.invalid',
          'CLAUDECODE': '1',
          'CLAUDE_CODE_ENTRYPOINT': 'cli',
        },
      );
      starter.respond(stdout: resultJson());

      await analyzer.analyze(request);

      expect(starter.calls.single.environment, {
        'PATH': '/usr/bin',
        'HOME': '/home/her',
        'USERPROFILE': r'C:\Users\her',
        'CLAUDE_CONFIG_DIR': '/home/her/.claude',
        'HTTPS_PROXY': 'http://proxy.example:8080',
      });
    });
  });

  group('结果', () {
    test('有 structured_output 时校验后返回', () async {
      starter.respond(stdout: resultJson());

      final result = await analyzer.analyze(request);

      expect(result.category, MailCategory.informational);
      expect(result.reason, 'Just a notice.');
    });

    test('没有 structured_output 时是输出格式不对', () async {
      starter.respond(stdout: resultJson(structured: null));

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.invalidOutput),
      );
    });

    test('structured_output 不符合约定时是输出格式不对', () async {
      starter.respond(stdout: resultJson(structured: {'category': 'urgent'}));

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.invalidOutput),
      );
    });

    test('退出码 0 但输出不是 JSON 时是输出格式不对', () async {
      starter.respond(stdout: 'hello');

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.invalidOutput),
      );
    });
  });

  group('失败类型', () {
    test('找不到 claude 时是未安装，不启动进程', () async {
      analyzer = analyzerWith(executable: null);

      await expectLater(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.notInstalled),
      );
      expect(starter.calls, isEmpty);
    });

    test('进程启动不了时是未安装', () async {
      starter.failToStart();

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.notInstalled),
      );
    });

    for (final message in [
      'Not logged in · Please run /login',
      'Login expired · Please run /login',
      'Invalid API key · Please run /login',
      'OAuth token has expired',
      'Authentication required · Sign in again to continue',
    ]) {
      test('未登录：$message', () async {
        starter.respond(
          exitCode: 1,
          stdout: resultJson(isError: true, result: message, structured: null),
        );

        expect(
          analyzer.analyze(request),
          failsWith(AnalysisFailureType.notLoggedIn),
        );
      });
    }

    for (final message in [
      "You've hit your session limit · resets 3pm",
      "You've hit your weekly limit",
      "You've hit your Opus limit",
    ]) {
      test('额度用完：$message', () async {
        starter.respond(
          exitCode: 1,
          stdout: resultJson(isError: true, result: message, structured: null),
        );

        expect(
          analyzer.analyze(request),
          failsWith(AnalysisFailureType.quotaExhausted),
        );
      });
    }

    test('额度用完：api_error_status 是 429', () async {
      starter.respond(
        exitCode: 1,
        stdout: resultJson(
          isError: true,
          result: 'Request rejected (429)',
          structured: null,
          apiErrorStatus: 429,
        ),
      );

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.quotaExhausted),
      );
    });

    test('认不出的错误按临时错误处理', () async {
      starter.respond(
        exitCode: 1,
        stdout: resultJson(
          isError: true,
          result: 'Something unexpected',
          structured: null,
        ),
      );

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.temporary),
      );
    });

    test('退出码不是 0、输出也不是 JSON 时是临时错误', () async {
      starter.respond(exitCode: 1, stdout: '', stderr: 'Error: boom');

      expect(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.temporary),
      );
    });

    test('超时后结束进程，按临时错误处理', () async {
      analyzer = analyzerWith(timeout: const Duration(milliseconds: 50));
      starter.hang();

      await expectLater(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.temporary),
      );
      expect(starter.calls.single.process.killed, isTrue);
      expect(
        Directory(starter.calls.single.workingDirectory).existsSync(),
        isFalse,
      );
    });

    test('超时后结束的是整个进程树：npm 版经过 cmd.exe，claude 是它的子进程', () async {
      final killed = <Process>[];
      analyzer = ClaudeCodeAnalyzer(
        startProcess: starter.start,
        environment: const {'PATH': r'C:\npm'},
        findExecutable: (_) => r'C:\npm\claude.cmd',
        timeout: const Duration(milliseconds: 50),
        killProcessTree: (process) async {
          killed.add(process);
          process.kill();
        },
      );
      starter.hang();

      await expectLater(
        analyzer.analyze(request),
        failsWith(AnalysisFailureType.temporary),
      );
      expect(killed, [starter.calls.single.process]);
    });
  });

  group('找到 claude', () {
    bool Function(String) existing(Set<String> paths) => paths.contains;

    test('Windows 上先找官方安装的位置', () {
      final found = findClaudeExecutable(
        {'USERPROFILE': r'C:\Users\her', 'PATH': r'C:\npm'},
        windows: true,
        fileExists: existing({
          r'C:\Users\her\.local\bin\claude.exe',
          r'C:\npm\claude.cmd',
        }),
      );

      expect(found, r'C:\Users\her\.local\bin\claude.exe');
    });

    test('Windows 上再在 PATH 里找 claude.exe，最后找 claude.cmd', () {
      final env = {'USERPROFILE': r'C:\Users\her', 'Path': r'C:\npm;C:\tools'};

      expect(
        findClaudeExecutable(
          env,
          windows: true,
          fileExists: existing({r'C:\npm\claude.cmd', r'C:\tools\claude.exe'}),
        ),
        r'C:\tools\claude.exe',
      );
      expect(
        findClaudeExecutable(
          env,
          windows: true,
          fileExists: existing({r'C:\npm\claude.cmd'}),
        ),
        r'C:\npm\claude.cmd',
      );
    });

    test('哪里都没有时为 null', () {
      expect(
        findClaudeExecutable(
          {'USERPROFILE': r'C:\Users\her', 'PATH': r'C:\npm'},
          windows: true,
          fileExists: existing({}),
        ),
        isNull,
      );
    });

    test('其他平台在 PATH 里找 claude', () {
      expect(
        findClaudeExecutable(
          {'HOME': '/home/me', 'PATH': '/usr/bin:/home/me/.local/bin'},
          windows: false,
          fileExists: existing({'/home/me/.local/bin/claude'}),
        ),
        '/home/me/.local/bin/claude',
      );
    });
  });
  group('检查安装和登录（向导第 3 步）', () {
    String status({required bool loggedIn}) => jsonEncode({
      'loggedIn': loggedIn,
      'authMethod': loggedIn ? 'claude.ai' : 'none',
      'email': 'her@example.edu',
    });

    test('找不到 claude 时是没安装，不启动进程', () async {
      analyzer = analyzerWith(executable: null);

      expect(await analyzer.checkStatus(), isA<ClaudeCodeMissing>());
      expect(starter.calls, isEmpty);
    });

    test('已登录时给出位置；用 auth status 查，环境变量和分析时一样', () async {
      analyzer = analyzerWith(
        environment: {'PATH': '/usr/bin', 'ANTHROPIC_API_KEY': 'sk-fake'},
      );
      starter.respond(stdout: status(loggedIn: true));

      final result = await analyzer.checkStatus();

      expect(
        result,
        isA<ClaudeCodeReady>().having((r) => r.path, 'path', '/usr/bin/claude'),
      );
      final call = starter.calls.single;
      expect(call.arguments, ['auth', 'status', '--json']);
      expect(call.environment, {'PATH': '/usr/bin'});
    });

    test('没登录时是未登录，也给出位置', () async {
      starter.respond(stdout: status(loggedIn: false), exitCode: 1);

      expect(
        await analyzer.checkStatus(),
        isA<ClaudeCodeNotLoggedIn>().having(
          (r) => r.path,
          'path',
          '/usr/bin/claude',
        ),
      );
    });

    test('启动不了时是没安装', () async {
      starter.failToStart();

      expect(await analyzer.checkStatus(), isA<ClaudeCodeMissing>());
    });

    test('输出认不出来时说不清是否登录', () async {
      starter.respond(stdout: 'error: unknown command auth', exitCode: 1);

      expect(await analyzer.checkStatus(), isA<ClaudeCodeLoginUnknown>());
    });

    test('超时时结束进程，说不清是否登录', () async {
      analyzer = analyzerWith(statusTimeout: const Duration(milliseconds: 50));
      starter.hang();

      expect(await analyzer.checkStatus(), isA<ClaudeCodeLoginUnknown>());
      expect(starter.calls.single.process.killed, isTrue);
    });
  });
}

/// 一次启动进程的记录。
class StartedCall {
  StartedCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.workingDirectoryWasEmpty,
    required this.promptFilePath,
    required this.promptFileContent,
    required this.process,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
  final bool workingDirectoryWasEmpty;

  /// 没有提示词文件的调用（检查登录状态）时为空。
  final String promptFilePath;
  final String promptFileContent;
  final FakeProcess process;

  String get stdin => utf8.decode(process.stdinBytes);
}

/// 按脚本返回结果的进程运行器。
class FakeProcessStarter {
  final calls = <StartedCall>[];
  final _scripts = <FakeProcess Function()>[];
  bool _failToStart = false;

  void respond({String stdout = '', String stderr = '', int exitCode = 0}) =>
      _scripts.add(
        () => FakeProcess(stdout: stdout, stderr: stderr, exitCode: exitCode),
      );

  /// 下一次启动的进程一直不结束，直到被 kill。
  void hang() => _scripts.add(() => FakeProcess(hang: true));

  void failToStart() => _failToStart = true;

  Future<Process> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Map<String, String> environment,
    required bool runInShell,
  }) async {
    if (_failToStart) throw ProcessException(executable, arguments);
    final process = _scripts.removeAt(0)();
    final promptIndex = arguments.indexOf('--system-prompt-file');
    final promptPath = promptIndex < 0 ? '' : arguments[promptIndex + 1];
    calls.add(
      StartedCall(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        workingDirectoryWasEmpty: Directory(workingDirectory)
            .listSync()
            .isEmpty,
        promptFilePath: promptPath,
        promptFileContent: promptPath.isEmpty
            ? ''
            : File(promptPath).readAsStringSync(),
        process: process,
      ),
    );
    return process;
  }
}

class FakeProcess implements Process {
  FakeProcess({
    String stdout = '',
    String stderr = '',
    int exitCode = 0,
    this._hang = false,
  }) : _stdout = utf8.encode(stdout),
       _stderr = utf8.encode(stderr) {
    _stdinController.stream.listen(stdinBytes.addAll);
    if (!_hang) _exit.complete(exitCode);
  }

  final List<int> _stdout;
  final List<int> _stderr;
  final bool _hang;
  final _exit = Completer<int>();
  final _stdinController = StreamController<List<int>>();
  final stdinBytes = <int>[];
  bool killed = false;

  @override
  late final IOSink stdin = IOSink(_stdinController);

  @override
  Stream<List<int>> get stdout => _hang
      ? _exit.future.asStream().map((_) => const <int>[])
      : Stream.value(_stdout);

  @override
  Stream<List<int>> get stderr => _hang
      ? _exit.future.asStream().map((_) => const <int>[])
      : Stream.value(_stderr);

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-1);
    return true;
  }
}
