import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 图片处理请求，可在 isolate（compute）中执行，避免阻塞 UI。
class ImageOp {
  final Uint8List bytes;

  /// 目标格式：'jpg' | 'png' | 'webp' | 'bmp' | 'tiff' | 'keep'
  final String format;
  final int quality; // JPEG/WebP 质量 1-100
  final int? maxDimension; // 最长边限制，null 表示不缩放
  final bool grayscale;
  final int rotation; // 0 / 90 / 180 / 270

  /// 源扩展名（不含点），用于 'keep' 模式决定编码器。
  final String sourceExt;

  const ImageOp({
    required this.bytes,
    this.format = 'keep',
    this.quality = 85,
    this.maxDimension,
    this.grayscale = false,
    this.rotation = 0,
    this.sourceExt = '',
  });
}

/// 处理结果：编码后的字节与最终扩展名（含点）。
class ImageResult {
  final Uint8List bytes;
  final String ext;
  const ImageResult(this.bytes, this.ext);
}

/// 给已解码图片叠加水印并编码的请求（水印 PNG 需与源图同尺寸）。
class CompositeOp {
  final Uint8List baseBytes;
  final Uint8List overlayPng;
  final String format; // jpg | png | keep
  final int quality;
  final String sourceExt;
  const CompositeOp({
    required this.baseBytes,
    required this.overlayPng,
    this.format = 'keep',
    this.quality = 92,
    this.sourceExt = '',
  });
}

/// 按目标格式编码 img.Image，返回字节与扩展名。
ImageResult _encode(img.Image image, String format, int quality, String sourceExt) {
  var target = format;
  if (target == 'keep') {
    target = sourceExt.toLowerCase();
    if (target == 'jpeg') target = 'jpg';
    if (target.isEmpty) target = 'jpg';
  }

  switch (target) {
    case 'png':
      return ImageResult(Uint8List.fromList(img.encodePng(image)), '.png');
    case 'webp':
      // image 包尚不支持 webp 编码，回退到 png 以免失败。
      return ImageResult(Uint8List.fromList(img.encodePng(image)), '.png');
    case 'bmp':
      return ImageResult(Uint8List.fromList(img.encodeBmp(image)), '.bmp');
    case 'tiff':
    case 'tif':
      return ImageResult(Uint8List.fromList(img.encodeTiff(image)), '.tiff');
    case 'jpg':
    case 'jpeg':
    default:
      // JPEG 不支持透明，若源含 alpha 先铺白底。
      if (image.hasAlpha) {
        final bg = img.Image(width: image.width, height: image.height);
        img.fill(bg, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(bg, image);
        image = bg;
      }
      return ImageResult(
          Uint8List.fromList(img.encodeJpg(image, quality: quality)), '.jpg');
  }
}

/// 在 isolate 中执行的顶层函数。
ImageResult runImageOp(ImageOp op) {
  var image = img.decodeImage(op.bytes);
  if (image == null) {
    throw const FormatException('无法解码该图片');
  }

  if (op.rotation != 0) {
    image = img.copyRotate(image, angle: op.rotation);
  }

  if (op.maxDimension != null) {
    final longest =
        image.width > image.height ? image.width : image.height;
    if (longest > op.maxDimension!) {
      if (image.width >= image.height) {
        image = img.copyResize(image, width: op.maxDimension);
      } else {
        image = img.copyResize(image, height: op.maxDimension);
      }
    }
  }

  if (op.grayscale) {
    image = img.grayscale(image);
  }

  return _encode(image, op.format, op.quality, op.sourceExt);
}

/// 在 isolate 中把预先生成好的水印图层合成到源图上并编码。
ImageResult runComposite(CompositeOp op) {
  final base = img.decodeImage(op.baseBytes);
  if (base == null) throw const FormatException('无法解码源图片');
  final overlay = img.decodePng(op.overlayPng);
  if (overlay != null) {
    img.compositeImage(base, overlay);
  }
  return _encode(base, op.format, op.quality, op.sourceExt);
}

/// 读取图片真实像素尺寸（宽, 高），失败返回 null。
List<int>? decodeSize(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return [image.width, image.height];
}

/// OCR 归一化结果：统一编码为 PNG 并限制最长边，附带最终像素尺寸。
class NormalizedImage {
  final Uint8List bytes;
  final int width;
  final int height;
  const NormalizedImage(this.bytes, this.width, this.height);
}

/// 为 OCR 归一化图片：解码 → 限制最长边（默认 2600px，兼顾精度与引擎上限）→ PNG。
NormalizedImage normalizeForOcr(Uint8List input) {
  const maxDim = 2600;
  var image = img.decodeImage(input);
  if (image == null) throw const FormatException('无法解码图片');
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxDim) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxDim)
        : img.copyResize(image, height: maxDim);
  }
  return NormalizedImage(
      Uint8List.fromList(img.encodePng(image)), image.width, image.height);
}
