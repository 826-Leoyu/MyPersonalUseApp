// 纯函数：分析结果校验（M-23）。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/analysis_result_parser.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_states.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';

void main() {
  AnalysisRequest request({
    List<String> links = const ['https://example.com/form'],
    List<String> relatedIds = const [],
  }) => AnalysisRequest(
    subject: 'Assignment 3',
    senderName: 'Dr. Example',
    senderAddress: 'prof@example.edu',
    receivedAt: DateTime.utc(2026, 10, 19, 13),
    importance: 'normal',
    bodyText: 'Submit by Friday [1].',
    links: links,
    hasAttachments: false,
    hasInlineImages: false,
    bodyPossiblyIncomplete: false,
    timeZone: 'Eastern Daylight Time',
    relatedItems: [
      for (final id in relatedIds)
        RelatedItem(
          id: id,
          title: 'Old item',
          eventTime: null,
          dueTime: null,
          status: MailItemStatus.candidate,
        ),
    ],
    markedUseful: false,
  );

  Map<String, Object?> item({
    Object? match = const {'kind': 'new'},
    Object? title = 'Submit assignment 3',
    Object? dueTime = const {
      'value': '2026-10-23T23:59:00-04:00',
      'precision': 'dateTime',
      'unconfirmed': false,
    },
    Object? eventTime,
    Object? linkRefs = const [1],
  }) => {
    'match': match,
    'title': title,
    'summary': 'Upload the PDF.',
    'actions': ['Upload the PDF'],
    'location': null,
    'linkRefs': linkRefs,
    'eventTime': eventTime,
    'dueTime': dueTime,
    'optional': false,
    'unanalyzedAttachments': false,
  };

  Map<String, Object?> output({
    Object? category = 'actionRequired',
    List<Object?>? items,
  }) => {
    'category': category,
    'reason': 'Has a deadline.',
    'items': items ?? [item()],
  };

  Matcher invalidOutput = throwsA(
    isA<AnalysisFailed>().having(
      (f) => f.type,
      'type',
      AnalysisFailureType.invalidOutput,
    ),
  );

  test('读出分类、理由和事项', () {
    final result = parseAnalysisResult(output(), request());

    expect(result.category, MailCategory.actionRequired);
    expect(result.reason, 'Has a deadline.');
    final first = result.items.single;
    expect(first.updates, isNull);
    expect(first.title, 'Submit assignment 3');
    expect(first.summary, 'Upload the PDF.');
    expect(first.actions, ['Upload the PDF']);
    expect(first.linkRefs, [1]);
    expect(first.dueTime, CardTime.dateTime(DateTime.utc(2026, 10, 24, 3, 59)));
    expect(first.eventTime, isNull);
  });

  test('一封邮件可以没有事项，也可以有多个', () {
    expect(parseAnalysisResult(output(items: []), request()).items, isEmpty);
    expect(
      parseAnalysisResult(output(items: [item(), item()]), request()).items,
      hasLength(2),
    );
  });

  test('仅供参考和低价值的邮件不看事项，事项写错了也不算输出格式不对', () {
    for (final category in ['informational', 'lowValue']) {
      final result = parseAnalysisResult(
        output(
          category: category,
          items: [item(title: '')],
        ),
        request(),
      );

      expect(result.items, isEmpty, reason: category);
    }
  });

  test('只有日期的时间不编出时刻', () {
    final result = parseAnalysisResult(
      output(
        items: [
          item(
            dueTime: {
              'value': '2026-10-23',
              'precision': 'date',
              'unconfirmed': false,
            },
          ),
        ],
      ),
      request(),
    );

    expect(result.items.single.dueTime, CardTime.date(DayKey(2026, 10, 23)));
  });

  test('待确认的时间可以没有值，也可以带一个暂定的值', () {
    final result = parseAnalysisResult(
      output(
        items: [
          item(
            dueTime: {'value': null, 'precision': 'date', 'unconfirmed': true},
            eventTime: {
              'value': '2026-10-30',
              'precision': 'date',
              'unconfirmed': true,
            },
          ),
        ],
      ),
      request(),
    );

    expect(result.items.single.dueTime, const CardTime.pending());
    expect(
      result.items.single.eventTime,
      CardTime.date(DayKey(2026, 10, 30), pending: true),
    );
  });

  test('引用请求里给过的事项编号时是更新', () {
    final result = parseAnalysisResult(
      output(
        items: [
          item(match: {'kind': 'update', 'itemId': 'item-1'}),
        ],
      ),
      request(relatedIds: ['item-1']),
    );

    expect(result.items.single.updates, 'item-1');
  });

  group('输出格式不对（M-23）', () {
    final cases = <String, Map<String, Object?> Function()>{
      '分类不认识': () => output(category: 'urgent'),
      '缺少理由': () => output()..remove('reason'),
      'items 不是数组': () => {...output(), 'items': 'none'},
      '缺少标题': () => output(items: [item()..remove('title')]),
      '标题为空': () => output(items: [item(title: '  ')]),
      '引用了请求里没有的事项编号': () => output(
        items: [
          item(match: {'kind': 'update', 'itemId': 'item-9'}),
        ],
      ),
      'match 不认识': () => output(
        items: [
          item(match: {'kind': 'merge'}),
        ],
      ),
      '时间解析不了': () => output(
        items: [
          item(
            dueTime: {
              'value': 'next Friday',
              'precision': 'dateTime',
              'unconfirmed': false,
            },
          ),
        ],
      ),
      '日期加时刻没有时区偏移': () => output(
        items: [
          item(
            dueTime: {
              'value': '2026-10-23T23:59:00',
              'precision': 'dateTime',
              'unconfirmed': false,
            },
          ),
        ],
      ),
      '日期不存在': () => output(
        items: [
          item(
            dueTime: {
              'value': '2026-02-30',
              'precision': 'date',
              'unconfirmed': false,
            },
          ),
        ],
      ),
      '没有值也不待确认': () => output(
        items: [
          item(
            dueTime: {'value': null, 'precision': 'date', 'unconfirmed': false},
          ),
        ],
      ),
      '链接编号不存在': () => output(
        items: [
          item(linkRefs: [2]),
        ],
      ),
      '链接编号从 0 开始': () => output(
        items: [
          item(linkRefs: [0]),
        ],
      ),
      '顶层不是对象': () => {'result': output()},
    };
    for (final MapEntry(key: name, value: build) in cases.entries) {
      test(name, () {
        expect(() => parseAnalysisResult(build(), request()), invalidOutput);
      });
    }

    test('顶层是数组', () {
      expect(() => parseAnalysisResult([output()], request()), invalidOutput);
    });
  });
}
