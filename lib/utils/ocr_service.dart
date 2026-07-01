import 'dart:io';
import 'macos_ocr.dart';
import 'ocr_types.dart';
import 'windows_ocr.dart';

/// 跨平台 OCR 调度：Windows 走 Windows.Media.Ocr，macOS 走 Vision。
class OcrService {
  static bool get isSupported => Platform.isWindows || Platform.isMacOS;

  /// 平台能力说明，用于在不支持时给出提示。
  static String get platformNote => Platform.isWindows
      ? '使用 Windows 内置 OCR'
      : Platform.isMacOS
          ? '使用 macOS Vision OCR'
          : 'OCR 仅支持 Windows 与 macOS';

  static Future<OcrPageResult> recognizeImageFile(String imagePath) {
    if (Platform.isWindows) {
      return WindowsOcr.recognizeImageFile(imagePath);
    }
    if (Platform.isMacOS) {
      return MacosOcr.recognizeImageFile(imagePath);
    }
    throw UnsupportedError('OCR 仅支持 Windows 与 macOS');
  }
}
