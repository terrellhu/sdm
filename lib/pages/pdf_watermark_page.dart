import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/material.dart' show Image;
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/watermark_painter.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfWatermarkPage extends StatefulWidget {
  const PdfWatermarkPage({super.key});

  @override
  State<PdfWatermarkPage> createState() => _PdfWatermarkPageState();
}

class _PdfWatermarkPageState extends State<PdfWatermarkPage> {
  File? _pdfFile;
  String? _pdfName;
  int _pageCount = 0;

  String _watermarkText = '仅供参考';
  double _fontSize = 42;
  double _opacity = 0.25;
  bool _diagonal = true;
  bool _tiled = true;
  Color _color = Colors.red;
  String? _outputDirectory = AppPrefs.outputDir;

  ImageProvider? _previewImage;
  double _previewPageWidthPt = 595;
  bool _isLoadingPreview = false;

  bool _isSaving = false;
  double _saveProgress = 0;

  static const _presetColors = {
    '红色': Colors.red,
    '蓝色': Colors.blue,
    '灰色': Colors.grey,
    '黑色': Colors.black,
    '橙色': Colors.orange,
    '绿色': Colors.green,
  };

  WatermarkStyle get _style => WatermarkStyle(
        text: _watermarkText,
        color: _color.withValues(alpha: _opacity),
        fontSizePt: _fontSize,
        tiled: _tiled,
        diagonal: _diagonal,
      );

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
      final pageWidthPt = page.width;
      await doc.dispose();
      if (bd != null && mounted) {
        setState(() {
          _previewImage = MemoryImage(Uint8List.view(bd.buffer));
          _previewPageWidthPt = pageWidthPt;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      AppPrefs.outputDir = result;
    }
  }

  Future<void> _save() async {
    if (_pdfFile == null) return;
    setState(() {
      _isSaving = true;
      _saveProgress = 0;
    });

    try {
      final doc = sf.PdfDocument(inputBytes: await _pdfFile!.readAsBytes());
      final style = _style;
      final count = doc.pages.count;
      final cache = <String, Uint8List>{};

      for (int i = 0; i < count; i++) {
        final page = doc.pages[i];
        final size = page.size;
        final key = '${size.width.round()}x${size.height.round()}';
        final png = cache[key] ??= await buildWatermarkPng(
          pageWidthPt: size.width,
          pageHeightPt: size.height,
          style: style,
        );
        page.graphics
            .drawImage(sf.PdfBitmap(png), Rect.fromLTWH(0, 0, size.width, size.height));
        setState(() => _saveProgress = (i + 1) / count);
      }

      final bytes = await doc.save();
      doc.dispose();

      final dir = await resolveOutputDir(preferred: _outputDirectory);
      final baseName = p.basenameWithoutExtension(_pdfName ?? 'document');
      final outPath = uniquePath(dir, '${baseName}_水印', '.pdf');
      await File(outPath).writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _isSaving = false);
      showResultDialog(
        context,
        title: '水印已添加',
        message: '已处理 $count 页并叠加水印，原有文字与图形保持可选、可搜索。\n\n$outPath',
        outputPath: outPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorDialog(context, '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 加水印',
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
                        value: _saveProgress,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('${(_saveProgress * 100).toInt()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed: (!_isSaving && _pdfFile != null) ? _save : null,
              leading: const Icon(Icons.save_alt_rounded, size: 18),
              child: const Text('保存文件'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 360,
            decoration: BoxDecoration(
              border: Border(
                  right:
                      BorderSide(color: theme.colorScheme.border, width: 0.5)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.background,
                  theme.colorScheme.muted.withValues(alpha: 0.1)
                ],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('源文件', Icons.picture_as_pdf_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: _pdfFile == null
                        ? Center(
                            child: ShadButton.outline(
                              onPressed: _pickPdf,
                              leading: const Icon(Icons.add_rounded, size: 18),
                              child: const Text('点击选择 PDF'),
                            ),
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_pdfName ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text('$_pageCount 页',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme.mutedForeground)),
                                  ],
                                ),
                              ),
                              ShadIconButton.ghost(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader('水印样式', Icons.style_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('水印内容'),
                        ShadInput(
                          initialValue: _watermarkText,
                          placeholder: const Text('请输入水印文字'),
                          onChanged: (v) =>
                              setState(() => _watermarkText = v),
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('颜色预设'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _presetColors.entries.map((entry) {
                            final isSelected =
                                _color.toARGB32() == entry.value.toARGB32();
                            return GestureDetector(
                              onTap: () => setState(() => _color = entry.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color: entry.value
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8)
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('透明度'),
                            Text('${(_opacity * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ShadSlider(
                          initialValue: _opacity,
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          onChanged: (v) => setState(() => _opacity = v),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('字体大小'),
                            Text('${_fontSize.toInt()} pt',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ShadSlider(
                          initialValue: _fontSize,
                          min: 16,
                          max: 120,
                          divisions: 26,
                          onChanged: (v) => setState(() => _fontSize = v),
                        ),
                        const SizedBox(height: 16),
                        _buildToggle('平铺整页', _tiled,
                            (v) => setState(() => _tiled = v)),
                        const SizedBox(height: 8),
                        _buildToggle('45° 倾斜', _diagonal,
                            (v) => setState(() => _diagonal = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader('保存设置', Icons.folder_open_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: OutputDirRow(
                      directory: _outputDirectory,
                      onPick: _pickOutputDirectory,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: theme.colorScheme.muted.withValues(alpha: 0.2),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    color: theme.colorScheme.background.withValues(alpha: 0.5),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_rounded,
                            size: 16,
                            color: theme.colorScheme.mutedForeground),
                        const SizedBox(width: 8),
                        Text('实时预览 (第 1 页)',
                            style: TextStyle(
                                color: theme.colorScheme.mutedForeground,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _pdfFile == null
                        ? _buildEmptyPreview(theme)
                        : _isLoadingPreview
                            ? const Center(child: CircularProgressIndicator())
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: _PreviewWidget(
                                    pageImage: _previewImage,
                                    style: _style,
                                    pageWidthPt: _previewPageWidthPt,
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        ShadSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEmptyPreview(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
              ],
            ),
            child: Icon(Icons.water_drop_rounded,
                size: 64,
                color: theme.colorScheme.mutedForeground.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text('暂无预览',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 8),
          Text('请先选择 PDF 文件以配置水印',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }
}

class _PreviewWidget extends StatelessWidget {
  final ImageProvider? pageImage;
  final WatermarkStyle style;
  final double pageWidthPt;

  const _PreviewWidget({
    required this.pageImage,
    required this.style,
    required this.pageWidthPt,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pageImage != null)
                Image(image: pageImage!, fit: BoxFit.contain),
              CustomPaint(
                painter:
                    WatermarkPreviewPainter(style, pageWidthPoints: pageWidthPt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
