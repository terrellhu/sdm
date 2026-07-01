import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/file_utils.dart';
import '../utils/image_tasks.dart';
import '../utils/searchable_pdf.dart';
import '../utils/windows_ocr.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  final List<File> _imageFiles = [];
  File? _pdfFile;
  String? _sourceName;

  bool _isWorking = false;
  double _progress = 0;
  String _stage = '';

  bool _recognized = false;
  String _text = '';
  List<OcrDocPage> _pages = [];

  Future<void> _addImages() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return;
    setState(() {
      _pdfFile = null;
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        if (!_imageFiles.any((e) => e.path == file.path)) _imageFiles.add(file);
      }
      _sourceName = '${_imageFiles.length} 张图片';
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _imageFiles.clear();
      _pdfFile = File(result.files.single.path!);
      _sourceName = result.files.single.name;
    });
  }

  void _reset() {
    setState(() {
      _imageFiles.clear();
      _pdfFile = null;
      _sourceName = null;
      _recognized = false;
      _text = '';
      _pages = [];
    });
  }

  /// 把一张图片字节归一化并 OCR，返回该页结果。
  Future<OcrDocPage> _ocrOne(
    Uint8List sourceBytes, {
    required double pageWidthPt,
    required double pageHeightPt,
    required int index,
  }) async {
    final norm = await compute(normalizeForOcr, sourceBytes);
    final tmp = await getTemporaryDirectory();
    final imgPath = p.join(tmp.path, 'sdm_ocr_src_$index.png');
    await File(imgPath).writeAsBytes(norm.bytes);
    final ocr = await WindowsOcr.recognizeImageFile(imgPath);
    try {
      await File(imgPath).delete();
    } catch (_) {}
    return OcrDocPage(
      imageBytes: norm.bytes,
      pageWidthPt: pageWidthPt <= 0 ? norm.width.toDouble() : pageWidthPt,
      pageHeightPt: pageHeightPt <= 0 ? norm.height.toDouble() : pageHeightPt,
      imgW: norm.width,
      imgH: norm.height,
      words: ocr.words,
    );
  }

  Future<void> _recognize() async {
    if (_imageFiles.isEmpty && _pdfFile == null) return;
    setState(() {
      _isWorking = true;
      _progress = 0;
      _stage = '准备中...';
    });

    final pages = <OcrDocPage>[];
    final buffer = StringBuffer();

    try {
      if (_pdfFile != null) {
        final doc = await pdfx.PdfDocument.openFile(_pdfFile!.path);
        final count = doc.pagesCount;
        for (int i = 1; i <= count; i++) {
          setState(() {
            _stage = '正在识别第 $i / $count 页';
            _progress = i / count;
          });
          final page = await doc.getPage(i);
          final rendered = await page.render(
            width: page.width * 2.5,
            height: page.height * 2.5,
            format: pdfx.PdfPageImageFormat.png,
          );
          final pageW = page.width;
          final pageH = page.height;
          await page.close();
          if (rendered == null) continue;
          final result = await _ocrOne(
            rendered.bytes,
            pageWidthPt: pageW,
            pageHeightPt: pageH,
            index: i,
          );
          pages.add(result);
          final t = result.words.isEmpty
              ? ''
              : _buildPageText(result.words);
          if (t.isNotEmpty) buffer.writeln(t);
        }
        await doc.close();
      } else {
        for (var i = 0; i < _imageFiles.length; i++) {
          setState(() {
            _stage = '正在识别第 ${i + 1} / ${_imageFiles.length} 张';
            _progress = (i + 1) / _imageFiles.length;
          });
          final bytes = await _imageFiles[i].readAsBytes();
          final result = await _ocrOne(
            bytes,
            pageWidthPt: 0,
            pageHeightPt: 0,
            index: i,
          );
          pages.add(result);
          final t = _buildPageText(result.words);
          if (t.isNotEmpty) buffer.writeln(t);
        }
      }

      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _recognized = true;
        _pages = pages;
        _text = buffer.toString().trim();
      });
    } on OcrUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      showErrorDialog(
        context,
        '$e\n\n请在「设置 → 时间和语言 → 语言和区域」中，为中文添加“光学字符识别(OCR)”可选功能后重试。',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      showErrorDialog(context, '识别失败：$e');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (mounted) {
      ShadToaster.of(context).show(const ShadToast(title: Text('已复制全部文本')));
    }
  }

  Future<void> _exportTxt() async {
    final dir = await resolveOutputDir();
    final base = _sourceName == null
        ? 'ocr'
        : p.basenameWithoutExtension(_sourceName!);
    final outPath = uniquePath(dir, base, '.txt');
    await File(outPath).writeAsString(_text);
    if (!mounted) return;
    showResultDialog(context,
        title: '导出成功', message: '文本已保存为 TXT。\n\n$outPath', outputPath: outPath);
  }

  Future<void> _exportSearchablePdf() async {
    if (_pages.isEmpty) return;
    setState(() {
      _isWorking = true;
      _stage = '正在生成可搜索 PDF...';
    });
    try {
      final bytes = await buildSearchablePdf(_pages);
      final dir = await resolveOutputDir();
      final base = _sourceName == null
          ? 'ocr'
          : p.basenameWithoutExtension(_sourceName!);
      final outPath = uniquePath(dir, '${base}_可搜索', '.pdf');
      await File(outPath).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _isWorking = false);
      showResultDialog(
        context,
        title: '导出完成',
        message: canEmbedCjk
            ? '已生成可复制、可搜索的 PDF。\n\n$outPath'
            : '已生成可搜索 PDF（未找到中文字体，中文检索可能受限）。\n\n$outPath',
        outputPath: outPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      showErrorDialog(context, '导出失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (!WindowsOcr.isSupported) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: toolAppBar(context, title: 'OCR 文字识别'),
        body: Center(
          child: Text('OCR 目前仅支持 Windows 平台',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'OCR 文字识别',
        actions: _buildActions(),
      ),
      body: ToolBackground(
        child: _isWorking
            ? _buildProgress(theme)
            : _recognized
                ? _buildResult(theme)
                : _buildInput(theme),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isWorking) return const [];
    if (_recognized) {
      return [
        ShadButton.ghost(
          onPressed: _reset,
          size: ShadButtonSize.sm,
          leading: const Icon(Icons.refresh_rounded, size: 16),
          child: const Text('重选'),
        ),
        if (_text.isNotEmpty) ...[
          ShadButton.ghost(
            onPressed: _copy,
            size: ShadButtonSize.sm,
            leading: const Icon(Icons.copy_rounded, size: 16),
            child: const Text('复制'),
          ),
          ShadButton.ghost(
            onPressed: _exportTxt,
            size: ShadButtonSize.sm,
            leading: const Icon(Icons.download_rounded, size: 16),
            child: const Text('TXT'),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: ShadButton(
            onPressed: _pages.isEmpty ? null : _exportSearchablePdf,
            leading: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            child: const Text('可搜索 PDF'),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: ShadButton(
          onPressed: (_imageFiles.isNotEmpty || _pdfFile != null) ? _recognize : null,
          leading: const Icon(Icons.document_scanner_rounded, size: 18),
          child: const Text('开始识别'),
        ),
      ),
    ];
  }

  Widget _buildProgress(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: _progress == 0 ? null : _progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.muted,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(_stage,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
        ],
      ),
    );
  }

  Widget _buildInput(ShadThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.document_scanner_rounded,
                    size: 64, color: theme.colorScheme.mutedForeground),
              ),
              const SizedBox(height: 20),
              Text('识别图片 / 扫描件中的文字',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.foreground)),
              const SizedBox(height: 8),
              Text('使用系统内置 OCR，离线免费；可导出为文本或可搜索 PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.mutedForeground)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShadButton(
                    onPressed: _addImages,
                    leading: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                    child: const Text('添加图片'),
                  ),
                  const SizedBox(width: 16),
                  ShadButton.outline(
                    onPressed: _pickPdf,
                    leading: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    child: const Text('选择扫描 PDF'),
                  ),
                ],
              ),
              if (_sourceName != null) ...[
                const SizedBox(height: 24),
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('已选择：$_sourceName',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: _reset,
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: theme.colorScheme.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '若提示引擎不可用，请在系统「语言和区域」为中文添加“光学字符识别(OCR)”可选功能。',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.mutedForeground,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(ShadThemeData theme) {
    if (_text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: theme.colorScheme.mutedForeground),
              const SizedBox(height: 20),
              Text('未识别到文字',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.foreground)),
              const SizedBox(height: 8),
              Text('图片可能不含文字，或清晰度不足；可尝试更清晰的扫描件。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.mutedForeground)),
              const SizedBox(height: 24),
              ShadButton.outline(
                  onPressed: _reset, child: const Text('重新选择')),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.text_fields_rounded,
                  size: 16, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 8),
              Text('${_pages.length} 页 · ${_text.length} 字',
                  style: TextStyle(
                      fontSize: 13, color: theme.colorScheme.mutedForeground)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.border, width: 0.5),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(_text,
                  style: const TextStyle(fontSize: 14, height: 1.7)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 从词列表拼接一页文本：同一行相邻词若均为中文则不插空格。
String _buildPageText(List<OcrWord> words) {
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

bool _isCjk(int code) =>
    (code >= 0x4E00 && code <= 0x9FFF) ||
    (code >= 0x3400 && code <= 0x4DBF) ||
    (code >= 0xF900 && code <= 0xFAFF) ||
    (code >= 0x3000 && code <= 0x303F);

bool _endsCjk(String s) => s.isNotEmpty && _isCjk(s.codeUnitAt(s.length - 1));
bool _startsCjk(String s) => s.isNotEmpty && _isCjk(s.codeUnitAt(0));
