import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// 用模板法把源文档中的指定页（0 基）无损组装成一个新的 PDF，
/// 完整保留文字、矢量与清晰度。返回 PDF 字节。
Future<List<int>> buildPdfFromPages(
    sf.PdfDocument src, List<int> zeroBasedPages) async {
  final out = sf.PdfDocument();
  for (final idx in zeroBasedPages) {
    if (idx < 0 || idx >= src.pages.count) continue;
    final page = src.pages[idx];
    final template = page.createTemplate();
    out.pageSettings.size = page.size;
    out.pageSettings.margins.all = 0;
    out.pages.add().graphics.drawPdfTemplate(template, const Offset(0, 0));
  }
  final bytes = await out.save();
  out.dispose();
  return bytes;
}

/// 按给定顺序与每页旋转量（0/1/2/3 对应 0/90/180/270°）无损重组 PDF。
/// 旋转通过页面 /Rotate 实现，完整保留原内容。
Future<List<int>> buildReorganizedPdf(
  sf.PdfDocument src,
  List<int> sourceIndices,
  List<int> rotationQuarters,
) async {
  final out = sf.PdfDocument();
  for (var i = 0; i < sourceIndices.length; i++) {
    final srcIdx = sourceIndices[i];
    if (srcIdx < 0 || srcIdx >= src.pages.count) continue;
    final page = src.pages[srcIdx];
    final template = page.createTemplate();
    out.pageSettings.size = page.size;
    out.pageSettings.margins.all = 0;
    final newPage = out.pages.add();
    newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
    final total = (page.rotation.index + (rotationQuarters[i] % 4)) % 4;
    newPage.rotation = sf.PdfPageRotateAngle.values[total];
  }
  final bytes = await out.save();
  out.dispose();
  return bytes;
}

/// 解析形如 "1-3,5,8-10" 的页码表达式，返回去重排序后的 1 基页码列表，
/// 自动裁剪到 [1, pageCount]。解析失败返回空列表。
List<int> parsePageRanges(String input, int pageCount) {
  final result = <int>{};
  for (final rawPart in input.split(RegExp(r'[,，、\s]+'))) {
    final part = rawPart.trim();
    if (part.isEmpty) continue;
    final dash = RegExp(r'^(\d+)\s*[-~]\s*(\d+)$').firstMatch(part);
    if (dash != null) {
      var a = int.parse(dash.group(1)!);
      var b = int.parse(dash.group(2)!);
      if (a > b) {
        final t = a;
        a = b;
        b = t;
      }
      for (var i = a; i <= b; i++) {
        if (i >= 1 && i <= pageCount) result.add(i);
      }
    } else {
      final single = int.tryParse(part);
      if (single != null && single >= 1 && single <= pageCount) {
        result.add(single);
      }
    }
  }
  final list = result.toList()..sort();
  return list;
}
