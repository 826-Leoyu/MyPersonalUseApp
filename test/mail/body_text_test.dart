// 纯函数：HTML 正文转成适合分析的文本（M-10）。邮件都是虚构的。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/body_text.dart';

void main() {
  MailBody html(String body, {String? bodyPreview}) =>
      convertMailBody(body: body, isHtml: true, bodyPreview: bodyPreview);

  test('英文段落转成文本，链接文字后面加编号，链接存进列表', () {
    final body = html(
      '<html><body>'
      '<p>Hi team,</p>'
      '<p>Please <a href="https://example.com/rsvp">RSVP here</a> '
      'by Friday.</p>'
      '</body></html>',
    );

    expect(body.text, 'Hi team,\n\nPlease RSVP here [1] by Friday.');
    expect(body.links, ['https://example.com/rsvp']);
    expect(body.hasInlineImages, isFalse);
    expect(body.possiblyIncomplete, isFalse);
  });

  test('中文邮件的段落、空行和列表保持可读', () {
    final body = html(
      '<div>大家好：</div>'
      '<div><br></div>'
      '<div>周五组会改到&nbsp;<b>3 点</b>，请准备：</div>'
      '<ul><li>上周的周报</li><li>笔记本电脑</li></ul>'
      '<p>流程：</p>'
      '<ol><li>汇报进度</li><li>讨论问题</li></ol>'
      '<div>谢谢<br>李明</div>',
    );

    expect(
      body.text,
      '大家好：\n'
      '\n'
      '周五组会改到 3 点，请准备：\n'
      '\n'
      '- 上周的周报\n'
      '- 笔记本电脑\n'
      '\n'
      '流程：\n'
      '\n'
      '1. 汇报进度\n'
      '2. 讨论问题\n'
      '\n'
      '谢谢\n'
      '李明',
    );
  });

  test('表格每行一行，单元格之间用竖线隔开', () {
    final body = html(
      '<p>考试安排：</p>'
      '<table><tr><th>科目</th><th>时间</th></tr>'
      '<tr><td>数据库</td><td>11 月 3 日 9:00</td></tr></table>',
    );

    expect(body.text, '考试安排：\n\n科目 | 时间\n数据库 | 11 月 3 日 9:00');
  });

  test('只给网页链接编号，同一个链接用同一个编号；mailto 和页内锚点不编号', () {
    final body = html(
      '<p><a href="https://example.com/form">报名表</a>，'
      '<a href="mailto:office@example.edu">联系我们</a>，'
      '<a href="#top">回到顶部</a>，'
      '<a href=" https://example.com/form ">再看一次报名表</a></p>',
    );

    expect(body.text, '报名表 [1]，联系我们，回到顶部，再看一次报名表 [1]');
    expect(body.links, ['https://example.com/form']);
  });

  group('引用的旧邮件', () {
    test('Outlook 网页版的回复：分隔线后面的旧邮件用标记包起来', () {
      final body = html(
        '<html><head><style>P {margin-top:0;margin-bottom:0;}</style></head>'
        '<body>'
        '<style type="text/css">.x {color: red}</style>'
        '<div>Sounds good, see you there.</div>'
        '<div id="appendonsend"></div>'
        '<hr style="display:inline-block;width:98%" tabindex="-1">'
        '<div id="divRplyFwdMsg" dir="ltr"><font face="Calibri">'
        '<b>From:</b> Wang Fang &lt;wang.fang@example.com&gt;<br>'
        '<b>Sent:</b> Monday, October 19, 2026 9:00 AM<br>'
        '<b>Subject:</b> Group meeting</font><div>&nbsp;</div></div>'
        '<div><div>Is the meeting still on Friday?</div></div>'
        '</body></html>',
      );

      expect(
        body.text,
        'Sounds good, see you there.\n'
        '\n'
        '[引用]\n'
        'From: Wang Fang <wang.fang@example.com>\n'
        'Sent: Monday, October 19, 2026 9:00 AM\n'
        'Subject: Group meeting\n'
        'Is the meeting still on Friday?\n'
        '[/引用]',
      );
    });

    test('经典版 Outlook 的中文转发：发件人信息块和后面的旧邮件都算引用', () {
      final body = html(
        '<div class="WordSection1">'
        '<p class="MsoNormal">请看下面的通知。</p>'
        '<p class="MsoNormal">&nbsp;</p>'
        '<div><div style="border:none;border-top:solid #E1E1E1 1.0pt;'
        'padding:3.0pt 0cm 0cm 0cm">'
        '<p class="MsoNormal"><b>发件人:</b> 教务处 &lt;office@example.edu&gt;'
        '<br><b>发送时间:</b> 2026年10月19日 9:00'
        '<br><b>主题:</b> 期中考试安排</p></div></div>'
        '<p class="MsoNormal">期中考试在 11 月 3 日举行。</p>'
        '</div>',
      );

      expect(
        body.text,
        '请看下面的通知。\n'
        '\n'
        '[引用]\n'
        '发件人: 教务处 <office@example.edu>\n'
        '发送时间: 2026年10月19日 9:00\n'
        '主题: 期中考试安排\n'
        '\n'
        '期中考试在 11 月 3 日举行。\n'
        '[/引用]',
      );
    });

    test('Gmail 的引用块用标记包起来，里面的 blockquote 不再重复标记', () {
      final body = html(
        '<div dir="ltr">Yes, I can make it.</div><br>'
        '<div class="gmail_quote">'
        '<div dir="ltr" class="gmail_attr">On Mon, Oct 19, 2026 at 9:00 AM '
        'Sam Lee &lt;sam@example.com&gt; wrote:<br></div>'
        '<blockquote class="gmail_quote" style="margin:0px 0px 0px 0.8ex">'
        '<div dir="ltr">Can you join the call on Thursday?</div>'
        '</blockquote></div>',
      );

      expect(
        body.text,
        'Yes, I can make it.\n'
        '\n'
        '[引用]\n'
        'On Mon, Oct 19, 2026 at 9:00 AM Sam Lee <sam@example.com> wrote:\n'
        'Can you join the call on Thursday?\n'
        '[/引用]',
      );
    });

    test('引用块后面的正文照常保留', () {
      final body = html(
        '<p>See my answers below.</p>'
        '<blockquote><p>Which room?</p></blockquote>'
        '<p>Room 204.</p>',
      );

      expect(
        body.text,
        'See my answers below.\n'
        '\n'
        '[引用]\n'
        'Which room?\n'
        '[/引用]\n'
        '\n'
        'Room 204.',
      );
    });
  });

  group('签名', () {
    test('Outlook 的签名用标记包起来，旧邮件里的签名算在引用里', () {
      final body = html(
        '<div>周五组会改到 3 点。</div>'
        '<div id="Signature"><div>李明 | 计算机系</div>'
        '<div>办公室：Lambton Tower 5105</div></div>'
        '<div id="appendonsend"></div>'
        '<div id="divRplyFwdMsg"><b>From:</b> Wang Fang</div>'
        '<div>周五组会照常吗？</div>'
        '<div id="x_Signature">王芳</div>',
      );

      expect(
        body.text,
        '周五组会改到 3 点。\n'
        '\n'
        '[签名]\n'
        '李明 | 计算机系\n'
        '办公室：Lambton Tower 5105\n'
        '[/签名]\n'
        '\n'
        '[引用]\n'
        'From: Wang Fang\n'
        '周五组会照常吗？\n'
        '王芳\n'
        '[/引用]',
      );
    });

    test('Gmail 的签名用标记包起来', () {
      final body = html(
        '<div>See you then.</div><br>'
        '<div dir="ltr" class="gmail_signature" '
        'data-smartmail="gmail_signature">Sam Lee<br>Graduate Office</div>',
      );

      expect(
        body.text,
        'See you then.\n'
        '\n'
        '[签名]\n'
        'Sam Lee\n'
        'Graduate Office\n'
        '[/签名]',
      );
    });

    test('空的签名和引用不写标记', () {
      final body = html(
        '<p>Thanks.</p>'
        '<div id="Signature"><div>&nbsp;</div></div>'
        '<blockquote></blockquote>',
      );

      expect(body.text, 'Thanks.');
    });

    test('认不出来的签名照常保留，不加标记', () {
      final body = html('<p>Thanks for your help.</p><p>Best,<br>Sam</p>');

      expect(body.text, 'Thanks for your help.\n\nBest,\nSam');
    });
  });

  group('图片', () {
    test('只有内嵌图片的邮件：写成带替代文字的图片标记，记下有内嵌图片', () {
      final body = html(
        '<div><img src="cid:image001.png@01DB2A3C" alt="秋季招聘会海报"></div>'
        '<div><img src="data:image/png;base64,iVBORw0KGgo="></div>'
        '<img src="https://track.example.com/open.gif" width="1" height="1">',
      );

      expect(body.text, '[图片: 秋季招聘会海报]\n[图片]');
      expect(body.hasInlineImages, isTrue);
      expect(body.possiblyIncomplete, isFalse);
    });

    test('只有 1×1 的图片算跟踪像素，带 px 和写在 style 里的也算', () {
      final body = html(
        '<img src="https://example.com/line.png" width="1" height="600">'
        '<img src="https://t.example.com/a.gif" width="1px" height="1px">'
        '<img src="https://t.example.com/b.gif" style="width:1px; height: 1px">',
      );

      expect(body.text, '[图片]');
    });

    test('网上的图片写成图片标记，不算内嵌图片', () {
      final body = html(
        '<p>Our new menu:</p><img src="https://example.com/menu.png">',
      );

      expect(body.text, 'Our new menu:\n\n[图片]');
      expect(body.hasInlineImages, isFalse);
    });
  });

  group('用 bodyPreview 后备', () {
    test('body 为空时用 bodyPreview，并标记正文可能不完整', () {
      final body = html('', bodyPreview: 'Reminder: the lab is closed on…');

      expect(body.text, 'Reminder: the lab is closed on…');
      expect(body.possiblyIncomplete, isTrue);
    });

    test('HTML 转出来什么都没有时也用 bodyPreview', () {
      final body = html(
        '<html><body><div>&nbsp;</div></body></html>',
        bodyPreview: '图书馆周六闭馆',
      );

      expect(body.text, '图书馆周六闭馆');
      expect(body.possiblyIncomplete, isTrue);
    });

    test('bodyPreview 里的网址也编号', () {
      final body = html('', bodyPreview: 'Form: https://example.com/form');

      expect(body.text, 'Form: https://example.com/form [1]');
      expect(body.links, ['https://example.com/form']);
      expect(body.possiblyIncomplete, isTrue);
    });

    test('只有空签名和跟踪像素时也用 bodyPreview', () {
      final body = html(
        '<img src="https://t.example.com/o.gif" width="1" height="1">'
        '<div id="Signature"></div>',
        bodyPreview: '图书馆周六闭馆',
      );

      expect(body.text, '图书馆周六闭馆');
      expect(body.possiblyIncomplete, isTrue);
    });

    test('body 和 bodyPreview 都没有时正文为空', () {
      final body = html('', bodyPreview: null);

      expect(body.text, isNull);
      expect(body.links, isEmpty);
      expect(body.possiblyIncomplete, isFalse);
    });
  });

  group('纯文本正文', () {
    MailBody plain(String body) =>
        convertMailBody(body: body, isHtml: false, bodyPreview: null);

    test('保留换行，网址后面加编号，标出签名和引用', () {
      final body = plain(
        'Hi,\r\n'
        '\r\n'
        'The form is at https://example.com/form. Please also read\r\n'
        'https://example.com/rules (same as https://example.com/form).\r\n'
        '\r\n'
        '\r\n'
        '-- \r\n'
        'Sam Lee\r\n'
        'Graduate Office\r\n'
        '\r\n'
        '-----Original Message-----\r\n'
        'From: Wang Fang\r\n'
        'Is the form ready?',
      );

      expect(
        body.text,
        'Hi,\n'
        '\n'
        'The form is at https://example.com/form [1]. Please also read\n'
        'https://example.com/rules [2] (same as https://example.com/form [1]).\n'
        '\n'
        '[签名]\n'
        'Sam Lee\n'
        'Graduate Office\n'
        '[/签名]\n'
        '\n'
        '[引用]\n'
        '-----Original Message-----\n'
        'From: Wang Fang\n'
        'Is the form ready?\n'
        '[/引用]',
      );
      expect(body.links, [
        'https://example.com/form',
        'https://example.com/rules',
      ]);
    });

    test('网址后面紧跟的中文不算网址', () {
      final body = plain(
        '详见https://example.com/x，请周五前提交。\n报名https://example.com/y请回复',
      );

      expect(
        body.text,
        '详见https://example.com/x [1]，请周五前提交。\n'
        '报名https://example.com/y [2]请回复',
      );
      expect(body.links, ['https://example.com/x', 'https://example.com/y']);
    });

    test('签名分隔行后面什么都没有时不写标记', () {
      expect(plain('Thanks.\n-- \n').text, 'Thanks.');
    });

    test('Outlook 纯文本回复的下划线分隔线后面算引用', () {
      final body = plain(
        '好的，周五见。\n'
        '\n'
        '________________________________\n'
        '发件人: 王芳\n'
        '周五见面吗？',
      );

      expect(
        body.text,
        '好的，周五见。\n'
        '\n'
        '[引用]\n'
        '________________________________\n'
        '发件人: 王芳\n'
        '周五见面吗？\n'
        '[/引用]',
      );
    });
  });
}
