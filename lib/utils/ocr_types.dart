// OCR 通用数据结构，供 Windows / macOS 两套实现共用。

/// 一个词及其在图片像素坐标系（左上角原点）中的包围盒。
class OcrWord {
  final String text;
  final double x, y, w, h;
  const OcrWord(this.text, this.x, this.y, this.w, this.h);
}

/// 一行文本（由若干词组成）。
class OcrLine {
  final List<OcrWord> words;
  const OcrLine(this.words);

  /// 拼接行内文本：相邻中文之间不加空格，其余以空格分隔。
  String get text {
    if (words.isEmpty) return '';
    final sb = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      final w = words[i].text;
      if (i > 0) {
        final prev = words[i - 1].text;
        final joinNoSpace = _endsCjk(prev) && _startsCjk(w);
        if (!joinNoSpace) sb.write(' ');
      }
      sb.write(w);
    }
    return sb.toString().trim();
  }
}

/// 一页/一张图的 OCR 结果。
class OcrPageResult {
  final int width; // OCR 所用图片像素宽
  final int height;
  final List<OcrLine> lines;
  const OcrPageResult({
    required this.width,
    required this.height,
    required this.lines,
  });

  List<OcrWord> get words => [for (final l in lines) ...l.words];

  String get text =>
      lines.map((l) => l.text).where((s) => s.trim().isNotEmpty).join('\n');
}

/// OCR 引擎不可用（通常是未安装对应语言的 OCR 语言包）。
class OcrUnavailableException implements Exception {
  final List<String> available;
  OcrUnavailableException(this.available);
  @override
  String toString() =>
      '系统 OCR 引擎不可用。已安装的识别语言：${available.isEmpty ? '无' : available.join(', ')}';
}

/// 从原生返回的 Map（Windows JSON / macOS 通道均为同结构）解析结果。
OcrPageResult ocrResultFromMap(Map map) {
  return OcrPageResult(
    width: (map['width'] as num?)?.toInt() ?? 0,
    height: (map['height'] as num?)?.toInt() ?? 0,
    lines: parseOcrLines(map['lines']),
  );
}

List<OcrLine> parseOcrLines(dynamic raw) {
  final rawLines = raw is List ? raw : (raw == null ? const [] : [raw]);
  final lines = <OcrLine>[];
  for (final l in rawLines) {
    if (l is! Map) continue;
    final rw = l['words'];
    final rawWords = rw is List ? rw : (rw == null ? const [] : [rw]);
    final words = <OcrWord>[];
    for (final w in rawWords) {
      if (w is Map) {
        words.add(OcrWord(
          (w['t'] ?? '').toString(),
          (w['x'] as num?)?.toDouble() ?? 0,
          (w['y'] as num?)?.toDouble() ?? 0,
          (w['w'] as num?)?.toDouble() ?? 0,
          (w['h'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    if (words.isNotEmpty) lines.add(OcrLine(words));
  }
  return lines;
}

bool _isCjk(int code) =>
    (code >= 0x4E00 && code <= 0x9FFF) ||
    (code >= 0x3400 && code <= 0x4DBF) ||
    (code >= 0xF900 && code <= 0xFAFF) ||
    (code >= 0x3000 && code <= 0x303F);

bool _endsCjk(String s) => s.isNotEmpty && _isCjk(s.codeUnitAt(s.length - 1));
bool _startsCjk(String s) => s.isNotEmpty && _isCjk(s.codeUnitAt(0));
