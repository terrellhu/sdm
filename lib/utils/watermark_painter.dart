import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 水印绘制参数。[fontSizePt] 以 PDF point 为单位（与滑块一致），
/// 绘制时按 canvas 相对页面点宽自动缩放，保证预览与导出所见即所得。
class WatermarkStyle {
  final String text;
  final Color color; // 已含透明度
  final double fontSizePt;
  final bool tiled; // 平铺整页
  final bool diagonal; // 45° 倾斜

  const WatermarkStyle({
    required this.text,
    required this.color,
    required this.fontSizePt,
    required this.tiled,
    required this.diagonal,
  });
}

/// 在给定 canvas 上绘制水印。[pageWidthPoints] 为该页真实宽度（point），
/// 用于把 fontSizePt 映射到当前 canvas 尺寸。
void paintWatermark(
  Canvas canvas,
  Size size,
  WatermarkStyle style, {
  required double pageWidthPoints,
}) {
  if (style.text.trim().isEmpty) return;

  final scale = size.width / pageWidthPoints;
  final fontSize = (style.fontSizePt * scale).clamp(4.0, 4000.0);

  final tp = TextPainter(
    text: TextSpan(
      text: style.text,
      style: TextStyle(
        color: style.color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final angle = style.diagonal ? -math.pi / 4 : 0.0;

  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(angle);

  if (style.tiled) {
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final stepX = tp.width + fontSize * 2.2;
    final stepY = tp.height + fontSize * 2.4;
    for (double y = -diag; y < diag; y += stepY) {
      for (double x = -diag; x < diag; x += stepX) {
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  } else {
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
  canvas.restore();
}

/// 生成透明背景的水印 PNG，用于叠加到 PDF 页面（保留原页面文字/矢量）。
/// [pageWidthPt]/[pageHeightPt] 为页面真实尺寸（point），[pixelRatio] 控制清晰度。
Future<Uint8List> buildWatermarkPng({
  required double pageWidthPt,
  required double pageHeightPt,
  required WatermarkStyle style,
  double pixelRatio = 2.0,
}) async {
  final w = (pageWidthPt * pixelRatio).clamp(1.0, 8000.0);
  final h = (pageHeightPt * pixelRatio).clamp(1.0, 8000.0);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  paintWatermark(canvas, Size(w, h), style, pageWidthPoints: pageWidthPt);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bd!.buffer.asUint8List();
}

/// 生成与图片同像素尺寸的透明水印 PNG，用于合成到位图上。
/// 字体大小相对 [referenceWidthPt]（默认 A4 595pt）等比缩放，
/// 使不同分辨率的图片得到一致的视觉比例。
Future<Uint8List> buildWatermarkPngForPixels({
  required int widthPx,
  required int heightPx,
  required WatermarkStyle style,
  double referenceWidthPt = 595,
}) async {
  final w = widthPx.clamp(1, 12000);
  final h = heightPx.clamp(1, 12000);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
      recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  paintWatermark(canvas, Size(w.toDouble(), h.toDouble()), style,
      pageWidthPoints: referenceWidthPt);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bd!.buffer.asUint8List();
}

/// 预览用 CustomPainter，复用同一套绘制逻辑，确保与导出一致。
class WatermarkPreviewPainter extends CustomPainter {
  final WatermarkStyle style;
  final double pageWidthPoints;
  const WatermarkPreviewPainter(this.style, {this.pageWidthPoints = 595.0});

  @override
  void paint(Canvas canvas, Size size) {
    paintWatermark(canvas, size, style, pageWidthPoints: pageWidthPoints);
  }

  @override
  bool shouldRepaint(covariant WatermarkPreviewPainter old) =>
      old.style != style || old.pageWidthPoints != pageWidthPoints;
}
