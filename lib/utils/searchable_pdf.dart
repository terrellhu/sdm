import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'windows_ocr.dart';

/// 可搜索 PDF 的一页：底图 + 该图上识别出的词（像素坐标）。
class OcrDocPage {
  final Uint8List imageBytes; // 作为底图的图片（PNG/JPG）
  final double pageWidthPt; // 目标页面宽（point）
  final double pageHeightPt;
  final int imgW; // OCR/底图像素宽
  final int imgH;
  final List<OcrWord> words;

  const OcrDocPage({
    required this.imageBytes,
    required this.pageWidthPt,
    required this.pageHeightPt,
    required this.imgW,
    required this.imgH,
    required this.words,
  });
}

/// 是否能加载到中文字体（否则中文文字层会缺字）。
bool get canEmbedCjk => _loadCjkFont() != null;

List<int>? _cachedFont;
bool _fontLoaded = false;

List<int>? _loadCjkFont() {
  if (_fontLoaded) return _cachedFont;
  _fontLoaded = true;
  if (!Platform.isWindows) return _cachedFont = null;
  final fontsDir =
      p.join(Platform.environment['WINDIR'] ?? r'C:\Windows', 'Fonts');
  const candidates = [
    'simhei.ttf',
    'simkai.ttf',
    'simfang.ttf',
    'simsun.ttc',
    'msyh.ttc',
  ];
  for (final name in candidates) {
    final f = File(p.join(fontsDir, name));
    if (f.existsSync()) {
      try {
        return _cachedFont = f.readAsBytesSync();
      } catch (_) {}
    }
  }
  return _cachedFont = null;
}

/// 生成可搜索 PDF：每页绘制底图，再叠加与识别结果对应的透明文字层，
/// 使输出 PDF 可复制、可全文搜索。
Future<List<int>> buildSearchablePdf(List<OcrDocPage> pages) async {
  final doc = sf.PdfDocument();
  final fontData = _loadCjkFont();
  final fontCache = <int, sf.PdfFont>{};

  sf.PdfFont fontFor(double sizePt) {
    final key = sizePt.round().clamp(4, 400);
    return fontCache[key] ??= fontData != null
        ? sf.PdfTrueTypeFont(fontData, key.toDouble())
        : sf.PdfStandardFont(sf.PdfFontFamily.helvetica, key.toDouble());
  }

  final transparent = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0, 0));

  for (final page in pages) {
    doc.pageSettings.size = Size(page.pageWidthPt, page.pageHeightPt);
    doc.pageSettings.margins.all = 0;
    final pg = doc.pages.add();
    final g = pg.graphics;
    g.drawImage(
      sf.PdfBitmap(page.imageBytes),
      Rect.fromLTWH(0, 0, page.pageWidthPt, page.pageHeightPt),
    );

    if (page.imgW <= 0) continue;
    final scale = page.pageWidthPt / page.imgW;
    for (final w in page.words) {
      final t = w.text.trim();
      if (t.isEmpty || w.h <= 0) continue;
      final bx = w.x * scale;
      final by = w.y * scale;
      final bw = w.w * scale;
      final bh = w.h * scale;
      final font = fontFor(bh * 0.8);
      g.drawString(
        t,
        font,
        brush: transparent,
        bounds: Rect.fromLTWH(bx, by, (bw <= 0 ? 1 : bw) * 1.3, bh * 1.4),
      );
    }
  }

  final bytes = await doc.save();
  doc.dispose();
  return bytes;
}
