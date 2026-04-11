import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/material.dart' show Image;
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfWatermarkPage extends StatefulWidget {
  const PdfWatermarkPage({super.key});

  @override
  State<PdfWatermarkPage> createState() => _PdfWatermarkPageState();
}

class _PdfWatermarkPageState extends State<PdfWatermarkPage> {
  File? _pdfFile;
  String? _pdfName;
  int _pageCount = 0;

  // Watermark settings
  String _watermarkText = '仅供参考';
  double _fontSize = 60;
  double _opacity = 0.3;
  bool _diagonal = true;
  Color _color = Colors.red;
  String? _outputDirectory;

  // Preview
  ImageProvider? _previewImage;
  bool _isLoadingPreview = false;

  bool _isSaving = false;
  double _saveProgress = 0;

  static const _presetColors = {
    '红色': Colors.red,
    '蓝色': Colors.blue,
    '灰色': Colors.grey,
    '黑色': Colors.black,
  };

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final doc = await PdfDocument.openFile(file.path);
    final count = doc.pageCount;
    await doc.dispose();

    setState(() {
      _pdfFile = file;
      _pdfName = result.files.single.name;
      _pageCount = count;
      _previewImage = null;
    });

    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (_pdfFile == null) return;
    setState(() => _isLoadingPreview = true);
    try {
      final doc = await PdfDocument.openFile(_pdfFile!.path);
      final page = await doc.getPage(1);
      final w = (page.width * 1.5).toInt();
      final h = (page.height * 1.5).toInt();
      final rendered = await page.render(
        width: w,
        height: h,
        fullWidth: page.width * 1.5,
        fullHeight: page.height * 1.5,
      );
      final flImg = await rendered.createImageIfNotAvailable();
      final bd = await flImg.toByteData(format: ImageByteFormat.png);
      await doc.dispose();
      if (bd != null && mounted) {
        setState(() {
          _previewImage = MemoryImage(Uint8List.view(bd.buffer));
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputDirectory = result);
  }

  Future<void> _save() async {
    if (_pdfFile == null) return;
    setState(() {
      _isSaving = true;
      _saveProgress = 0;
    });

    try {
      final srcDoc = await PdfDocument.openFile(_pdfFile!.path);
      final outDoc = pw.Document();

      for (int pi = 1; pi <= srcDoc.pageCount; pi++) {
        final page = await srcDoc.getPage(pi);
        final w = (page.width * 1.5).toInt();
        final h = (page.height * 1.5).toInt();
        final rendered = await page.render(
          width: w,
          height: h,
          fullWidth: page.width * 1.5,
          fullHeight: page.height * 1.5,
        );
        final flImg = await rendered.createImageIfNotAvailable();
        final bd = await flImg.toByteData(format: ImageByteFormat.png);

        if (bd != null) {
          final bgImage = pw.MemoryImage(Uint8List.view(bd.buffer));
          final pdfColor = PdfColor(_color.r, _color.g, _color.b, _opacity);

          outDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                page.width * PdfPageFormat.point,
                page.height * PdfPageFormat.point,
              ),
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                  ),
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: _diagonal ? -math.pi / 4 : 0,
                      child: pw.Text(
                        _watermarkText,
                        style: pw.TextStyle(
                          fontSize: _fontSize,
                          color: pdfColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        setState(() => _saveProgress = pi / srcDoc.pageCount);
      }
      await srcDoc.dispose();

      final outputDir = _outputDirectory ??
          (await getDownloadsDirectory())?.path ??
          (await getTemporaryDirectory()).path;

      final baseName = p.basenameWithoutExtension(_pdfName ?? 'document');
      final outPath = p.join(outputDir, '${baseName}_watermark.pdf');
      await File(outPath).writeAsBytes(await outDoc.save());

      setState(() => _isSaving = false);
      _showSuccess(outPath);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('保存失败：$e');
    }
  }

  void _showSuccess(String path) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('保存成功'),
        description: Text('已处理 $_pageCount 页并添加水印\n\n保存至：\n$path'),
        actions: [
          ShadButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ShadToaster.of(context).show(
      ShadToast(title: const Text('错误'), description: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('PDF 加水印'),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _saveProgress),
                  ),
                  const SizedBox(width: 8),
                  Text('${(_saveProgress * 100).toInt()}%',
                      style: TextStyle(
                          color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed: (!_isSaving && _pdfFile != null) ? _save : null,
              leading: const Icon(Icons.save, size: 16),
              child: const Text('保存'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: settings ────────────────────────────
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PDF picker
                  ShadCard(
                    padding: const EdgeInsets.all(14),
                    child: _pdfFile == null
                        ? Center(
                            child: ShadButton(
                              onPressed: _pickPdf,
                              leading:
                                  const Icon(Icons.picture_as_pdf, size: 16),
                              child: const Text('选择 PDF 文件'),
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(Icons.picture_as_pdf,
                                  color: Colors.red, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_pdfName ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text('$_pageCount 页',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                              ShadButton.ghost(
                                size: ShadButtonSize.sm,
                                onPressed: _pickPdf,
                                child: const Text('更换'),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                  const Text('水印设置',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  // Watermark text
                  _Label('水印文字'),
                  ShadInput(
                    initialValue: _watermarkText,
                    onChanged: (v) =>
                        setState(() => _watermarkText = v.isEmpty ? ' ' : v),
                  ),
                  const SizedBox(height: 14),

                  // Color
                  _Label('水印颜色'),
                  Wrap(
                    spacing: 8,
                    children: _presetColors.entries.map((entry) {
                      final isSelected = _color.toARGB32() == entry.value.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _color = entry.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.foreground
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Opacity
                  _Label(
                      '透明度  ${(_opacity * 100).toInt()}%'),
                  ShadSlider(
                    initialValue: _opacity,
                    min: 0.05,
                    max: 1.0,
                    divisions: 19,
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                  const SizedBox(height: 14),

                  // Font size
                  _Label('字体大小  ${_fontSize.toInt()} pt'),
                  ShadSlider(
                    initialValue: _fontSize,
                    min: 20,
                    max: 120,
                    divisions: 20,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                  const SizedBox(height: 14),

                  // Diagonal
                  Row(
                    children: [
                      Checkbox(
                        value: _diagonal,
                        onChanged: (v) =>
                            setState(() => _diagonal = v ?? true),
                      ),
                      const Text('斜向水印（45°）'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Output directory
                  _Label('保存位置'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _outputDirectory ?? '默认下载文件夹',
                          style: TextStyle(
                            fontSize: 12,
                            color: _outputDirectory != null
                                ? null
                                : theme.colorScheme.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.secondary(
                        size: ShadButtonSize.sm,
                        onPressed: _pickOutputDirectory,
                        leading: const Icon(Icons.folder, size: 14),
                        child: const Text('选择'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: theme.colorScheme.border),

          // ── Right: preview ─────────────────────────────
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('预览（第 1 页）',
                      style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                          fontSize: 13)),
                ),
                Expanded(
                  child: _pdfFile == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.water_drop_outlined,
                                  size: 56,
                                  color: theme.colorScheme.mutedForeground),
                              const SizedBox(height: 12),
                              Text('选择 PDF 后查看水印预览',
                                  style: TextStyle(
                                      color:
                                          theme.colorScheme.mutedForeground)),
                            ],
                          ),
                        )
                      : _isLoadingPreview
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: _PreviewWidget(
                                pageImage: _previewImage,
                                watermarkText: _watermarkText,
                                fontSize: _fontSize,
                                opacity: _opacity,
                                color: _color,
                                diagonal: _diagonal,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

// ──────────────────────────────────────────────
// Live preview widget (Flutter rendering)
// ──────────────────────────────────────────────

class _PreviewWidget extends StatelessWidget {
  final ImageProvider? pageImage;
  final String watermarkText;
  final double fontSize;
  final double opacity;
  final Color color;
  final bool diagonal;

  const _PreviewWidget({
    required this.pageImage,
    required this.watermarkText,
    required this.fontSize,
    required this.opacity,
    required this.color,
    required this.diagonal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale font to preview size (assume page is ~A4)
        final previewFontSize = fontSize * (constraints.maxWidth / 595.0);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pageImage != null)
                Image(image: pageImage!, fit: BoxFit.contain),
              Center(
                child: Transform.rotate(
                  angle: diagonal ? -math.pi / 4 : 0,
                  child: Text(
                    watermarkText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: previewFontSize.clamp(12, 80),
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
