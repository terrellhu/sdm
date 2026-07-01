import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/pdf_ops.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfSplitPage extends StatefulWidget {
  const PdfSplitPage({super.key});

  @override
  State<PdfSplitPage> createState() => _PdfSplitPageState();
}

class _PdfSplitPageState extends State<PdfSplitPage> {
  File? _pdfFile;
  String? _pdfName;
  int _pageCount = 0;
  final Set<int> _selected = {}; // 1-based
  String _mode = 'extract'; // extract | everyN
  int _chunkSize = 1;
  String? _outputDirectory = AppPrefs.outputDir;
  bool _isWorking = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      final doc = sf.PdfDocument(inputBytes: await file.readAsBytes());
      final count = doc.pages.count;
      doc.dispose();
      setState(() {
        _pdfFile = file;
        _pdfName = result.files.single.name;
        _pageCount = count;
        _selected
          ..clear()
          ..addAll(List.generate(count, (i) => i + 1));
      });
    } catch (e) {
      if (mounted) showErrorDialog(context, '无法打开 PDF：$e');
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      await AppPrefs.rememberOutputDir(result);
    }
  }

  void _applyRange(String text) {
    final pages = parsePageRanges(text, _pageCount);
    if (pages.isEmpty) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(pages);
    });
  }

  Future<void> _run() async {
    if (_pdfFile == null) return;
    if (_mode == 'extract' && _selected.isEmpty) {
      showErrorDialog(context, '请至少选择一页');
      return;
    }
    setState(() => _isWorking = true);
    try {
      final src = sf.PdfDocument(inputBytes: await _pdfFile!.readAsBytes());
      final dir = await resolveOutputDir(preferred: _outputDirectory);
      final base = p.basenameWithoutExtension(_pdfName ?? 'document');

      String resultPath;
      String message;

      if (_mode == 'extract') {
        final pages = _selected.toList()..sort();
        final bytes = await buildPdfFromPages(src, pages.map((e) => e - 1).toList());
        resultPath = uniquePath(dir, '${base}_提取${pages.length}页', '.pdf');
        await File(resultPath).writeAsBytes(bytes);
        message = '已提取 ${pages.length} 页为单个 PDF。\n\n$resultPath';
      } else {
        final chunk = _chunkSize.clamp(1, _pageCount);
        int part = 1;
        String? firstPath;
        for (int start = 0; start < _pageCount; start += chunk) {
          final end = (start + chunk).clamp(0, _pageCount);
          final idxs = [for (int i = start; i < end; i++) i];
          final bytes = await buildPdfFromPages(src, idxs);
          final path = uniquePath(dir, '${base}_part$part', '.pdf');
          await File(path).writeAsBytes(bytes);
          firstPath ??= path;
          part++;
        }
        resultPath = firstPath ?? dir;
        message = '已按每 $chunk 页拆分为 ${part - 1} 个 PDF 文件。\n\n$dir';
      }

      src.dispose();
      if (!mounted) return;
      setState(() => _isWorking = false);
      showResultDialog(
        context,
        title: '拆分完成',
        message: message,
        outputPath: resultPath,
        isFile: _mode == 'extract',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      showErrorDialog(context, '处理失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 拆分 / 提取',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isWorking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : ShadButton(
                    onPressed: _pdfFile != null ? _run : null,
                    leading: const Icon(Icons.content_cut_rounded, size: 18),
                    child: Text(_mode == 'extract' ? '提取导出' : '拆分导出'),
                  ),
          ),
        ],
      ),
      body: ToolBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32),
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
                  if (_pdfFile != null) ...[
                    const SizedBox(height: 32),
                    const SectionHeader('拆分方式', Icons.tune_rounded),
                    const SizedBox(height: 16),
                    ShadCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ToolChip(
                                label: '提取选中页',
                                icon: Icons.select_all_rounded,
                                selected: _mode == 'extract',
                                onTap: () => setState(() => _mode = 'extract'),
                              ),
                              const SizedBox(width: 8),
                              ToolChip(
                                label: '按份数拆分',
                                icon: Icons.grid_on_rounded,
                                selected: _mode == 'everyN',
                                onTap: () => setState(() => _mode = 'everyN'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_mode == 'extract')
                            _buildExtractOptions(theme)
                          else
                            _buildEveryNOptions(theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: SettingTile(
                        title: '保存位置',
                        icon: Icons.folder_special_rounded,
                        child: OutputDirRow(
                          directory: _outputDirectory,
                          onPick: _pickOutputDirectory,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractOptions(ShadThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('选择页面 (${_selected.length}/$_pageCount)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _selected
                ..clear()
                ..addAll(List.generate(_pageCount, (i) => i + 1))),
              child: const Text('全选'),
            ),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ShadInput(
          placeholder: const Text('输入页码范围，如 1-3,5,8-10'),
          onSubmitted: _applyRange,
          onChanged: (v) {},
        ),
        const SizedBox(height: 6),
        Text('回车应用范围；也可点击下方页码手动增减',
            style:
                TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_pageCount, (i) {
            final page = i + 1;
            final sel = _selected.contains(page);
            return GestureDetector(
              onTap: () => setState(() =>
                  sel ? _selected.remove(page) : _selected.add(page)),
              child: Container(
                width: 40,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.border),
                ),
                child: Text('$page',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? theme.colorScheme.primaryForeground
                            : theme.colorScheme.foreground)),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEveryNOptions(ShadThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每个文件包含页数',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final n in const [1, 2, 5, 10])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ToolChip(
                  label: '$n 页',
                  selected: _chunkSize == n,
                  onTap: () => setState(() => _chunkSize = n),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '共 $_pageCount 页，将生成 ${(_pageCount / _chunkSize).ceil()} 个文件',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground),
        ),
      ],
    );
  }
}
