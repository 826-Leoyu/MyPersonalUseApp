/// 邮件正文转成适合分析的文本。纯函数，不碰数据库。
///
/// 格式见 spec 0002 的"正文文本的格式"。
library;

import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// 一封邮件转换后的正文。
class MailBody {
  const MailBody({
    required this.text,
    required this.links,
    required this.hasInlineImages,
    required this.possiblyIncomplete,
  });

  /// 清理后的文本；什么都没有时为 null。
  final String? text;

  /// 正文里的链接，第 n 个对应文本里的 `[n]`。
  final List<String> links;
  final bool hasInlineImages;

  /// `body` 转不出内容、用了 `bodyPreview` 时为 true。
  final bool possiblyIncomplete;
}

/// 把导出文件里的 `body` 转成 [MailBody]。转不出任何内容时用 [bodyPreview]。
MailBody mailBodyText({
  required String body,
  required bool isHtml,
  String? bodyPreview,
}) {
  final converted = isHtml ? _fromHtml(body) : _fromPlainText(body);
  final preview = bodyPreview?.trim() ?? '';
  if (converted.text != null || preview.isEmpty) return converted;
  return MailBody(
    text: preview,
    links: const [],
    hasInlineImages: converted.hasInlineImages,
    possiblyIncomplete: true,
  );
}

MailBody _fromHtml(String body) {
  final writer = _Writer();
  _Converter(writer).convert(html.parse(body).body!);
  return MailBody(
    text: writer.result,
    links: writer.links,
    hasInlineImages: writer.hasInlineImages,
    possiblyIncomplete: false,
  );
}

/// 纯文本里旧邮件开始的那一行：`-----Original Message-----` 一类，或者
/// Outlook 纯文本回复的一行下划线。
final _plainQuoteStart = RegExp(
  r'^\s*(-{2,}\s*(original message|原始邮件|forwarded message|转发的邮件)'
  r'\s*-{2,}|_{10,})\s*$',
  caseSensitive: false,
);

/// 纯文本里的网址。
final _url = RegExp(r'https?://[^\s<>"]+');

MailBody _fromPlainText(String body) {
  final links = <String>[];
  final lines = <String>[];
  // 正在标记的引用或签名的结束标记。
  String? openEnd;
  void close(String end) {
    lines.add(end);
    openEnd = null;
  }

  void open(String start, String end) {
    if (openEnd case final previous?) close(previous);
    lines.addAll(['', start]);
    openEnd = end;
  }

  for (final raw in body.split(RegExp(r'\r\n|\r|\n'))) {
    final line = raw.trimRight();
    if (openEnd != _quoteEnd && _plainQuoteStart.hasMatch(line)) {
      open(_quoteStart, _quoteEnd);
    } else if (openEnd == null && line == '--') {
      // 签名分隔行"-- "本身不留。
      open(_signatureStart, _signatureEnd);
      continue;
    }
    lines.add(
      line.replaceAllMapped(_url, (m) {
        final (url, rest) = _trimUrl(m[0]!);
        return '$url [${_number(links, url)}]$rest';
      }),
    );
  }
  if (openEnd case final end?) close(end);
  final text = lines
      .join('\n')
      // 标记里面紧挨着标记的空行不要。
      .replaceAllMapped(RegExp(r'(\[(?:引用|签名)\])\n+'), (m) => '${m[1]}\n')
      .replaceAll(RegExp(r'\n\n+(?=\[/(?:引用|签名)\])'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return MailBody(
    text: text.isEmpty ? null : text,
    links: links,
    hasInlineImages: false,
    possiblyIncomplete: false,
  );
}

/// 网址末尾的标点不算网址：返回网址和去掉的标点。
(String, String) _trimUrl(String url) {
  var end = url.length;
  while (end > 0) {
    final c = url[end - 1];
    final unmatchedParen = c == ')' && !url.substring(0, end).contains('(');
    if (!'.,;:!?。，；：！？'.contains(c) && !unmatchedParen) break;
    end--;
  }
  return (url.substring(0, end), url.substring(end));
}

/// 链接的编号，从 1 开始；同一个链接用同一个编号。
int _number(List<String> links, String url) {
  final index = links.indexOf(url);
  if (index >= 0) return index + 1;
  links.add(url);
  return links.length;
}

/// 前后空一行的块。
const _paragraphTags = {
  'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'pre', //
};

/// 前后换行的块。
const _lineTags = {
  'div', 'hr', 'tr', 'section', 'article', 'header', 'footer', 'address', //
  'dl', 'dt', 'dd', 'center', 'caption', 'figure', 'figcaption',
};

const _listTags = {'ul', 'ol'};

/// 不是正文内容的元素。
const _skippedTags = {'head', 'style', 'script', 'title', 'template'};

/// 引用的旧邮件和签名的标记。
const _quoteStart = '[引用]';
const _quoteEnd = '[/引用]';
const _signatureStart = '[签名]';
const _signatureEnd = '[/签名]';

/// 去掉 Outlook 转发时加在 id 前面的 `x_`。
String _id(Element e) => e.id.replaceFirst(RegExp('^x_'), '');

/// Outlook 的签名 id 以 Signature 开头；Gmail 用 `gmail_signature`。
bool _isSignature(Element e) =>
    RegExp('^signature', caseSensitive: false).hasMatch(_id(e)) ||
    e.classes.contains('gmail_signature');

/// 宽或高不超过 1 像素的图片，是用来统计打开次数的，不是内容。
bool _isTrackingPixel(Element img) => ['width', 'height'].any(
  (side) => switch (int.tryParse(img.attributes[side] ?? '')) {
    final size? => size <= 1,
    null => false,
  },
);

/// 整个元素是引用的旧邮件。
bool _isQuote(Element e) =>
    e.localName == 'blockquote' || e.classes.contains('gmail_quote');

/// 这个元素和它后面的所有内容都是引用的旧邮件：Outlook 回复和转发时，
/// 旧邮件放在分隔块后面，不包在一个元素里。
bool _startsTailQuote(Element e) {
  if (const {
    'appendonsend',
    'divRplyFwdMsg',
    'mail-editor-reference-message-container',
  }.contains(_id(e))) {
    return true;
  }
  // 经典版 Outlook：顶部有边框的 div，里面是"From: …"开头的旧邮件信息。
  final style = (e.attributes['style'] ?? '').replaceAll(' ', '').toLowerCase();
  return e.localName == 'div' &&
      style.contains('border-top:solid') &&
      RegExp(r'^\s*(From|发件人|寄件者)\s*[:：]').hasMatch(e.text);
}

class _Converter {
  _Converter(this._out);

  final _Writer _out;

  /// 在引用的旧邮件或签名里面：里面的引用和签名不再另加标记。
  bool _inQuote = false;

  /// 遇到了 [_startsTailQuote]，后面直到结尾都是引用。
  bool _inTailQuote = false;

  void convert(Element body) {
    node(body);
    if (_inTailQuote) _out.closeMarker(_quoteEnd);
  }

  void node(Node node) {
    switch (node) {
      case Text(:final data):
        _out.write(data);
      case Element(localName: final name) when _skippedTags.contains(name):
        break;
      case Element() when !_inQuote && _startsTailQuote(node):
        _out.openMarker(_quoteStart);
        _inQuote = _inTailQuote = true;
        this.node(node);
      case Element() when !_inQuote && _isQuote(node):
        _marked(node, _quoteStart, _quoteEnd);
      case Element() when !_inQuote && _isSignature(node):
        _marked(node, _signatureStart, _signatureEnd);
      case Element(localName: 'a'):
        children(node);
        final href = node.attributes['href']?.trim() ?? '';
        if (RegExp('^https?://', caseSensitive: false).hasMatch(href)) {
          _out.write(' [${_out.link(href)}]');
        }
      case Element(localName: 'img') when !_isTrackingPixel(node):
        final src = (node.attributes['src'] ?? '').trim().toLowerCase();
        if (src.startsWith('cid:') || src.startsWith('data:')) {
          _out.hasInlineImages = true;
        }
        _out.write(switch (node.attributes['alt']?.trim()) {
          final alt? when alt.isNotEmpty => ' [图片: $alt] ',
          _ => ' [图片] ',
        });
      case Element(localName: 'td' || 'th'):
        if (node.previousElementSibling != null) _out.write(' | ');
        children(node);
      case Element(localName: 'br'):
        _out.lineBreak();
      case Element(localName: 'li'):
        _out.newLine();
        final depth = _lists.length;
        final marker = switch (_lists.lastOrNull) {
          final ordered? when ordered >= 0 => '${_lists.last = ordered + 1}.',
          _ => '-',
        };
        _out.prefix('${'  ' * max(depth - 1, 0)}$marker ');
        children(node);
        _out.newLine();
      case Element(localName: final name) when _listTags.contains(name):
        // 有序列表记下已经编到第几项，无序列表记 -1。
        _lists.add(name == 'ol' ? 0 : -1);
        _lists.length == 1 ? _out.blankLine() : _out.newLine();
        children(node);
        _lists.removeLast();
        _lists.isEmpty ? _out.blankLine() : _out.newLine();
      case Element(localName: final name) when _paragraphTags.contains(name):
        _out.blankLine();
        children(node);
        _out.blankLine();
      case Element(localName: final name) when _lineTags.contains(name):
        _out.newLine();
        children(node);
        _out.newLine();
      case Element():
        children(node);
    }
  }

  /// 用 [start] 和 [end] 把 [element] 包起来。
  void _marked(Element element, String start, String end) {
    _out.openMarker(start);
    _inQuote = true;
    children(element);
    _inQuote = false;
    _out.closeMarker(end);
  }

  /// 正在处理的列表，最里层的在最后。
  final _lists = <int>[];

  void children(Node node) => node.nodes.forEach(this.node);
}

/// 拼接文本：连续空白合成一个空格，块之间换行。
class _Writer {
  final _buffer = StringBuffer();
  final links = <String>[];
  bool hasInlineImages = false;

  /// 下一段文字前要换几行：0 不换行，1 换一行，2 空一行。
  int _pendingBreak = 0;
  bool _pendingSpace = false;

  void write(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.first.isEmpty) _pendingSpace = true;
    var first = true;
    for (final word in words) {
      if (word.isEmpty) continue;
      if (!first) _pendingSpace = true;
      first = false;
      _flush();
      _buffer.write(word);
    }
    if (words.length > 1 && words.last.isEmpty) _pendingSpace = true;
  }

  void _flush() {
    if (_afterMarker) {
      _pendingBreak = 1;
      _afterMarker = false;
    }
    if (_buffer.isNotEmpty) {
      if (_pendingBreak > 0) {
        _buffer.write('\n' * _pendingBreak);
      } else if (_pendingSpace) {
        _buffer.write(' ');
      }
    }
    _pendingBreak = 0;
    _pendingSpace = false;
  }

  /// 后面的文字另起一行。
  void newLine() => _pendingBreak = max(_pendingBreak, 1);

  /// 后面的文字前空一行。
  void blankLine() => _pendingBreak = 2;

  /// `<br>`：每个换一行，最多空一行。
  void lineBreak() => _pendingBreak = min(_pendingBreak + 1, 2);

  /// 标记单独占一行，前面空一行。
  void openMarker(String marker) {
    blankLine();
    prefix(marker);
    _afterMarker = true;
  }

  /// 标记单独占一行，后面空一行。
  void closeMarker(String marker) {
    _pendingBreak = 1;
    prefix(marker);
    blankLine();
  }

  /// 刚写完开始标记：下一段文字只换一行，不空行。
  bool _afterMarker = false;

  /// 原样写出，不合并空白，比如列表项的缩进和符号。
  void prefix(String text) {
    _flush();
    _buffer.write(text);
  }

  /// 链接的编号，从 1 开始；同一个链接用同一个编号。
  int link(String url) => _number(links, url);

  String? get result => _buffer.isEmpty ? null : _buffer.toString();
}
