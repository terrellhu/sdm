import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfMergePage extends StatefulWidget {
  const PdfMergePage({super.key});

  @override
  State<PdfMergePage> createState() => _PdfMergePageState();
}

class _PdfMergePageState extends State<PdfMergePage> {
  final List<_PdfEntry> _entries = [];
  double _renderScale = 1.5;
  String? _outputDirectory;
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
        final file = File(f.path!);
        if (!_entries.any((e) => e.file.path == file.path)) {
          _entries.add(_PdfEntry(file: file, name: f.name));
        }
      }
    });
    // Load page counts in background
    for (final entry in _entries) {
      if (entry.pageCount == null) _loadPageCount(entry);
    }
  }

  Future<void> _loadPageCount(_PdfEntry entry) async {
    try {
      final doc = await PdfDocument.openFile(entry.file.path);
      final count = doc.pageCount;
      await doc.dispose();
      if (mounted) setState(() => entry.pageCount = count);
    } catch (_) {}
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputDirectory = result);
  }

  Future<void> _merge() async {
    if (_entries.isEmpty) return;
    setState(() {
      _isMerging = true;
      _progress = 0;
      _progressLabel = '准备中...';
    });

    try {
      // Count total pages
      int totalPages = 0;
      final pageCounts = <int>[];
      for (final entry in _entries) {
        final doc = await PdfDocument.openFile(entry.file.path);
        pageCounts.add(doc.pageCount);
        totalPages += doc.pageCount;
        await doc.dispose();
      }

      final mergedDoc = pw.Document();
      int processed = 0;

      for (var fi = 0; fi < _entries.length; fi++) {
        final entry = _entries[fi];
        setState(() => _progressLabel =
            '处理 ${entry.name} (${fi + 1}/${_entries.length})');

        final srcDoc = await PdfDocument.openFile(entry.file.path);
        for (int pi = 1; pi <= srcDoc.pageCount; pi++) {
          final page = await srcDoc.getPage(pi);
          final w = (page.width * _renderScale).toInt();
          final h = (page.height * _renderScale).toInt();
          final rendered = await page.render(
            width: w,
            height: h,
            fullWidth: page.width * _renderScale,
            fullHeight: page.height * _renderScale,
          );
          final flutterImage = await rendered.createImageIfNotAvailable();
          final byteData =
              await flutterImage.toByteData(format: ImageByteFormat.png);

          if (byteData != null) {
            final pngBytes = Uint8List.view(byteData.buffer);
            mergedDoc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(
                  page.width * PdfPageFormat.point,
                  page.height * PdfPageFormat.point,
                ),
                margin: pw.EdgeInsets.zero,
                build: (_) =>
                    pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fill),
              ),
            );
          }

          processed++;
          setState(() => _progress = processed / totalPages);
        }
        await srcDoc.dispose();
      }

      // Save
      final outputDir = _outputDirectory ??
          (await getDownloadsDirectory())?.path ??
          (await getTemporaryDirectory()).path;

      final outPath = p.join(outputDir, _outputFilename);
      await File(outPath).writeAsBytes(await mergedDoc.save());

      setState(() {
        _isMerging = false;
        _progress = 1.0;
      });

      _showSuccess('合并完成', '已保存至：\n$outPath', totalPages);
    } catch (e) {
      setState(() => _isMerging = false);
      _showError('合并失败：$e');
    }
  }

  void _showSuccess(String title, String desc, int pages) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: Text(title),
        description: Text('共合并 $pages 页\n\n$desc'),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ShadToaster.of(context).show(
      ShadToast(title: const Text('错误'), description: Text(msg)),
    );
  }

  int get _totalPages =>
      _entries.fold(0, (s, e) => s + (e.pageCount ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('PDF 合并'),
        actions: [
          if (!_isMerging)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _entries.isNotEmpty ? _merge : null,
                leading: const Icon(Icons.merge, size: 16),
                child: const Text('开始合并'),
              ),
            ),
        ],
      ),
      body: _isMerging ? _buildProgress(theme) : _buildMain(theme),
    );
  }

  Widget _buildProgress(ShadThemeData theme) {
    return Center(
      child: ShadCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 8,
                backgroundColor: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text('${(_progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_progressLabel,
                style: TextStyle(color: theme.colorScheme.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(ShadThemeData theme) {
    return Row(
      children: [
        // ── Left: file list ────────────────────────────────
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PDF 列表  ${_entries.length} 个  共 $_totalPages 页',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: _addPdfs,
                      leading: const Icon(Icons.add, size: 14),
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf,
                                size: 48,
                                color: theme.colorScheme.mutedForeground),
                            const SizedBox(height: 12),
                            ShadButton(
                              onPressed: _addPdfs,
                              child: const Text('添加 PDF 文件'),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemCount: _entries.length,
                        onReorder: (old, neo) {
                          setState(() {
                            if (neo > old) neo--;
                            _entries.insert(neo, _entries.removeAt(old));
                          });
                        },
                        itemBuilder: (_, i) => _PdfListItem(
                          key: ValueKey(_entries[i].file.path),
                          entry: _entries[i],
                          index: i,
                          onRemove: () =>
                              setState(() => _entries.removeAt(i)),
                        ),
                      ),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: theme.colorScheme.border),

        // ── Right: settings ───────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合并设置',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.foreground)),
                const SizedBox(height: 24),

                // Render quality
                _buildSettingTile(
                  theme,
                  title: '渲染质量',
                  subtitle: '越高质量越好，速度越慢',
                  child: Column(
                    children: [
                      ShadSlider(
                        initialValue: _renderScale,
                        min: 1.0,
                        max: 3.0,
                        divisions: 4,
                        onChanged: (v) => setState(() => _renderScale = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('快速',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.mutedForeground)),
                          Text('${_renderScale.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text('高清',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Output filename
                _buildSettingTile(
                  theme,
                  title: '输出文件名',
                  child: ShadInput(
                    initialValue: _outputFilename,
                    onChanged: (v) =>
                        setState(() => _outputFilename = v.isEmpty ? 'merged.pdf' : v),
                  ),
                ),
                const SizedBox(height: 20),

                // Output directory
                _buildSettingTile(
                  theme,
                  title: '保存位置',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _outputDirectory ?? '默认下载文件夹',
                          style: TextStyle(
                            color: _outputDirectory != null
                                ? null
                                : theme.colorScheme.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShadButton.secondary(
                        onPressed: _pickOutputDirectory,
                        leading: const Icon(Icons.folder, size: 16),
                        child: const Text('选择'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Summary
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('合并摘要',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.foreground)),
                      const SizedBox(height: 12),
                      _InfoRow('文件数量', '${_entries.length} 个 PDF'),
                      _InfoRow('总页数', '$_totalPages 页'),
                      _InfoRow('输出文件', _outputFilename),
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

  Widget _buildSettingTile(
    ShadThemeData theme, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        if (subtitle != null)
          Text(subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.mutedForeground)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ──────────────────────────────────────────────

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
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            ),
          ),
          Container(
            width: 36,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (entry.pageCount != null)
                  Text('${entry.pageCount} 页',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                if (entry.pageCount == null)
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
            tooltip: '移除',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
