import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfMergePage extends StatefulWidget {
  const PdfMergePage({super.key});

  @override
  State<PdfMergePage> createState() => _PdfMergePageState();
}

class _PdfMergePageState extends State<PdfMergePage> {
  final List<_PdfEntry> _entries = [];
  String? _outputDirectory = AppPrefs.outputDir;
  String _outputFilename = 'merged.pdf';
  bool _isMerging = false;
  double _progress = 0;
  String _progressLabel = '';

  Future<void> _addPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        if (!_entries.any((e) => e.file.path == file.path)) {
          _entries.add(_PdfEntry(file: file, name: f.name));
        }
      }
    });
    for (final entry in _entries) {
      if (entry.pageCount == null) _loadPageCount(entry);
    }
  }

  Future<void> _loadPageCount(_PdfEntry entry) async {
    try {
      final doc = sf.PdfDocument(inputBytes: await entry.file.readAsBytes());
      final count = doc.pages.count;
      doc.dispose();
      if (mounted) setState(() => entry.pageCount = count);
    } catch (_) {}
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      await AppPrefs.rememberOutputDir(result);
    }
  }

  Future<void> _merge() async {
    if (_entries.isEmpty) return;
    setState(() {
      _isMerging = true;
      _progress = 0;
      _progressLabel = '准备中...';
    });

    try {
      final output = sf.PdfDocument();
      final totalPages = _totalPages > 0 ? _totalPages : _entries.length;
      int processed = 0;

      for (var fi = 0; fi < _entries.length; fi++) {
        final entry = _entries[fi];
        setState(() =>
            _progressLabel = '处理 ${entry.name} (${fi + 1}/${_entries.length})');

        final src = sf.PdfDocument(inputBytes: await entry.file.readAsBytes());
        for (int i = 0; i < src.pages.count; i++) {
          final page = src.pages[i];
          final template = page.createTemplate();
          output.pageSettings.size = page.size;
          output.pageSettings.margins.all = 0;
          final newPage = output.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
          processed++;
          setState(() => _progress = processed / totalPages);
        }
        src.dispose();
      }

      final bytes = await output.save();
      output.dispose();

      final dir = await resolveOutputDir(preferred: _outputDirectory);
      final baseName = p.basenameWithoutExtension(
          _outputFilename.isEmpty ? 'merged.pdf' : _outputFilename);
      final outPath = uniquePath(dir, baseName, '.pdf');
      await File(outPath).writeAsBytes(bytes);

      if (!mounted) return;
      setState(() {
        _isMerging = false;
        _progress = 1.0;
      });
      showResultDialog(
        context,
        title: '合并完成',
        message: '共合并 $processed 页，无损保留原始文字与矢量内容。\n\n$outPath',
        outputPath: outPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMerging = false);
      showErrorDialog(context, '合并失败：$e');
    }
  }

  int get _totalPages => _entries.fold(0, (s, e) => s + (e.pageCount ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 合并',
        actions: [
          if (!_isMerging)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _entries.isNotEmpty ? _merge : null,
                leading: const Icon(Icons.merge_rounded, size: 18),
                child: const Text('开始合并'),
              ),
            ),
        ],
      ),
      body: ToolBackground(
        child: _isMerging ? _buildProgress(theme) : _buildMain(theme),
      ),
    );
  }

  Widget _buildProgress(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.muted,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text('${(_progress * 100).toInt()}%',
                  style:
                      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          Text('正在无损合并 PDF...',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground)),
          const SizedBox(height: 8),
          Text(_progressLabel,
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildMain(ShadThemeData theme) {
    return Row(
      children: [
        Container(
          width: 340,
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(color: theme.colorScheme.border, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text('文件队列',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.mutedForeground)),
                    const Spacer(),
                    ShadBadge.secondary(
                        child: Text('${_entries.length}',
                            style: const TextStyle(fontSize: 11))),
                    const SizedBox(width: 8),
                    ShadIconButton.ghost(
                      onPressed: _addPdfs,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _entries.isEmpty
                    ? _buildEmptyList(theme)
                    : ReorderableListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _entries.length,
                        onReorderItem: (old, neo) {
                          setState(() {
                            _entries.insert(neo, _entries.removeAt(old));
                          });
                        },
                        itemBuilder: (_, i) => _PdfListItem(
                          key: ValueKey(_entries[i].file.path),
                          entry: _entries[i],
                          index: i,
                          onRemove: () => setState(() => _entries.removeAt(i)),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('合并参数', Icons.tune_rounded),
                const SizedBox(height: 20),
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SettingTile(
                        title: '输出文件名',
                        icon: Icons.edit_note_rounded,
                        child: ShadInput(
                          initialValue: _outputFilename,
                          placeholder: const Text('请输入文件名'),
                          onChanged: (v) => setState(() =>
                              _outputFilename = v.isEmpty ? 'merged.pdf' : v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      SettingTile(
                        title: '保存位置',
                        icon: Icons.folder_special_rounded,
                        child: OutputDirRow(
                          directory: _outputDirectory,
                          onPick: _pickOutputDirectory,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildLosslessHint(theme),
                const SizedBox(height: 40),
                const SectionHeader('合并摘要', Icons.assignment_rounded),
                const SizedBox(height: 20),
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      InfoRow(Icons.file_copy_rounded, '文档总数',
                          '${_entries.length} 个 PDF'),
                      const SizedBox(height: 16),
                      InfoRow(Icons.pages_rounded, '累计页数', '$_totalPages 页'),
                      const SizedBox(height: 16),
                      InfoRow(Icons.save_rounded, '目标名称', _outputFilename),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLosslessHint(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '无损合并：完整保留原文档的可选文字、矢量图形与清晰度，体积不会暴涨。',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.foreground,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_rounded,
              size: 48,
              color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          ShadButton.secondary(
              onPressed: _addPdfs, child: const Text('添加 PDF')),
        ],
      ),
    );
  }
}

class _PdfEntry {
  final File file;
  final String name;
  int? pageCount;
  _PdfEntry({required this.file, required this.name});
}

class _PdfListItem extends StatelessWidget {
  final _PdfEntry entry;
  final int index;
  final VoidCallback onRemove;

  const _PdfListItem({
    super.key,
    required this.entry,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 18, color: theme.colorScheme.mutedForeground),
              ),
            ),
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (entry.pageCount != null)
                    Text('${entry.pageCount} 页',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.mutedForeground))
                  else
                    const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5)),
                ],
              ),
            ),
            ShadIconButton.ghost(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: theme.colorScheme.destructive),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
