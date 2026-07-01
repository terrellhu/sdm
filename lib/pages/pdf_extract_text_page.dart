import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/file_utils.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfExtractTextPage extends StatefulWidget {
  const PdfExtractTextPage({super.key});

  @override
  State<PdfExtractTextPage> createState() => _PdfExtractTextPageState();
}

class _PdfExtractTextPageState extends State<PdfExtractTextPage> {
  String? _pdfName;
  String _text = '';
  int _pageCount = 0;
  bool _isLoading = false;
  bool _done = false;

  Future<void> _pickAndExtract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    setState(() {
      _isLoading = true;
      _pdfName = result.files.single.name;
      _text = '';
      _done = false;
    });
    try {
      final doc = sf.PdfDocument(inputBytes: await file.readAsBytes());
      final count = doc.pages.count;
      final text = sf.PdfTextExtractor(doc).extractText();
      doc.dispose();
      if (!mounted) return;
      setState(() {
        _pageCount = count;
        _text = text.trim();
        _isLoading = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorDialog(context, '提取失败：$e');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (mounted) {
      ShadToaster.of(context).show(
        const ShadToast(title: Text('已复制全部文本到剪贴板')),
      );
    }
  }

  Future<void> _exportTxt() async {
    final dir = await resolveOutputDir();
    final base = p.basenameWithoutExtension(_pdfName ?? 'document');
    final outPath = uniquePath(dir, base, '.txt');
    await File(outPath).writeAsString(_text);
    if (!mounted) return;
    showResultDialog(
      context,
      title: '导出成功',
      message: '文本已保存为 TXT。\n\n$outPath',
      outputPath: outPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasText = _text.isNotEmpty;
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 转文字',
        actions: [
          if (hasText) ...[
            ShadButton.ghost(
              onPressed: _copy,
              size: ShadButtonSize.sm,
              leading: const Icon(Icons.copy_rounded, size: 16),
              child: const Text('复制'),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _exportTxt,
                size: ShadButtonSize.sm,
                leading: const Icon(Icons.download_rounded, size: 16),
                child: const Text('导出 TXT'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _isLoading ? null : _pickAndExtract,
                leading: const Icon(Icons.text_snippet_rounded, size: 18),
                child: const Text('选择 PDF'),
              ),
            ),
        ],
      ),
      body: ToolBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_done
                ? _buildEmpty(theme)
                : _buildResult(theme, hasText),
      ),
    );
  }

  Widget _buildEmpty(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.text_snippet_rounded,
                size: 72, color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 24),
          Text('提取 PDF 中的文字',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 8),
          Text('适用于电子版 PDF，可复制或导出为 TXT',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 32),
          ShadButton(
            onPressed: _pickAndExtract,
            size: ShadButtonSize.lg,
            leading: const Icon(Icons.folder_open_rounded, size: 20),
            child: const Text('选择 PDF 文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(ShadThemeData theme, bool hasText) {
    if (!hasText) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_search_rounded,
                  size: 64, color: theme.colorScheme.mutedForeground),
              const SizedBox(height: 20),
              Text('未检测到可提取的文字',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.foreground)),
              const SizedBox(height: 8),
              Text(
                '该 PDF 可能是扫描件或纯图片，需要 OCR 才能识别文字。',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.mutedForeground),
              ),
              const SizedBox(height: 24),
              ShadButton.outline(
                onPressed: _pickAndExtract,
                child: const Text('换一个 PDF'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.description_rounded,
                  size: 16, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${_pdfName ?? ''} · $_pageCount 页 · ${_text.length} 字',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.mutedForeground),
                    overflow: TextOverflow.ellipsis),
              ),
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
              child: SelectableText(
                _text,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
