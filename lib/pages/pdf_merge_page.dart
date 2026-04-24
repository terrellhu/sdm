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
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ShadIconButton.ghost(
          onPressed: () => context.go('/'),
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: theme.colorScheme.foreground),
        ),
        title: const Text(
          'PDF 合并',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.muted.withValues(alpha: 0.3),
            ],
          ),
        ),
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
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '正在合并 PDF 档案...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.colorScheme.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            _progressLabel,
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
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
            border: Border(right: BorderSide(color: theme.colorScheme.border, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '文件队列',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    ShadBadge.secondary(
                      child: Text('${_entries.length}', style: const TextStyle(fontSize: 11)),
                    ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                _buildSectionHeader(theme, '合并参数', Icons.tune_rounded),
                const SizedBox(height: 20),
                
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        theme,
                        title: '渲染质量',
                        icon: Icons.high_quality_rounded,
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
                                Text('快速', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                                Text('${_renderScale.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('高清', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      _buildSettingTile(
                        theme,
                        title: '输出文件名',
                        icon: Icons.edit_note_rounded,
                        child: ShadInput(
                          initialValue: _outputFilename,
                          placeholder: const Text('请输入文件名'),
                          onChanged: (v) => setState(() => _outputFilename = v.isEmpty ? 'merged.pdf' : v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      _buildSettingTile(
                        theme,
                        title: '保存位置',
                        icon: Icons.folder_special_rounded,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _outputDirectory ?? '默认下载文件夹',
                                style: TextStyle(
                                  color: _outputDirectory != null ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ShadButton.secondary(
                              onPressed: _pickOutputDirectory,
                              size: ShadButtonSize.sm,
                              leading: const Icon(Icons.edit_location_alt_rounded, size: 16),
                              child: const Text('更改'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                _buildSectionHeader(theme, '合并摘要', Icons.assignment_rounded),
                const SizedBox(height: 20),
                
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.file_copy_rounded, label: '文档总数', value: '${_entries.length} 个 PDF'),
                      const SizedBox(height: 16),
                      _InfoRow(icon: Icons.pages_rounded, label: '累计页数', value: '$_totalPages 页'),
                      const SizedBox(height: 16),
                      _InfoRow(icon: Icons.save_rounded, label: '目标名称', value: _outputFilename),
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

  Widget _buildEmptyList(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_rounded, size: 48, color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          ShadButton.secondary(
            onPressed: _addPdfs,
            child: const Text('添加 PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ShadThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.foreground),
        ),
      ],
    );
  }

  Widget _buildSettingTile(ShadThemeData theme, {required String title, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.mutedForeground)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: Icon(Icons.drag_indicator_rounded, size: 18, color: theme.colorScheme.mutedForeground),
              ),
            ),
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (entry.pageCount != null)
                    Text('${entry.pageCount} 页', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground))
                  else
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                ],
              ),
            ),
            ShadIconButton.ghost(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.destructive),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: theme.colorScheme.mutedForeground, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}
