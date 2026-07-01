import 'package:flutter/services.dart';
import 'ocr_types.dart';

/// 基于 macOS Vision 框架（VNRecognizeTextRequest）的本地 OCR。
/// 通过原生 MethodChannel 调用，返回与 Windows 实现相同的结构。
class MacosOcr {
  static const MethodChannel _channel = MethodChannel('sdm/ocr');

  static Future<OcrPageResult> recognizeImageFile(
    String imagePath, {
    List<String> langs = const ['zh-Hans', 'zh-Hant', 'en-US'],
  }) async {
    final res = await _channel.invokeMethod<dynamic>('recognize', {
      'path': imagePath,
      'langs': langs,
    });
    if (res is! Map) {
      throw Exception('OCR 无有效返回');
    }
    final map = Map<dynamic, dynamic>.from(res);
    final err = map['error'];
    if (err != null) {
      if (err == 'no_engine') {
        final avail =
            (map['available'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[];
        throw OcrUnavailableException(avail);
      }
      throw Exception('OCR 出错：$err');
    }
    return ocrResultFromMap(map);
  }
}
