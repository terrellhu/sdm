import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;

class BatchPrintPage extends StatefulWidget {
  final List<File>? initialFiles;

  const BatchPrintPage({super.key, this.initialFiles});

  @override
  State<BatchPrintPage> createState() => _BatchPrintPageState();
}

class _BatchPrintPageState extends State<BatchPrintPage> {
  List<File> _files = [];
  int _imagesPerPage = 1;
  bool _landscape = false;
  bool _isPrinting = false;

  static const _layoutOptions = [1, 2, 4, 6];

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null) {
      _files = List.from(widget.initialFiles!);
    }
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        final file = File(f.path!);
        if (!_files.any((e) => e.path == file.path)) {
          _files.add(file);
        }
      }
    });
  }

  void _removeFile(int index) => setState(() => _files.removeAt(index));

  Future<void> _print() async {
    if (_files.isEmpty) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        name: '批量打印 - ${_files.length} 张图片',
        onLayout: (PdfPageFormat format) async {
          final pageFormat =
              _landscape ? PdfPageFormat(format.height, format.width) : format;

          final imageProviders = <pw.MemoryImage>[];
          for (final file in _files) {
            imageProviders.add(pw.MemoryImage(await file.readAsBytes()));
          }

          final doc = pw.Document();
          final total = imageProviders.length;
          var i = 0;
          while (i < total) {
            final slice = imageProviders.sublist(
              i,
              (i + _imagesPerPage).clamp(0, total),
            );
            doc.addPage(
              pw.Page(
                pageFormat: pageFormat,
                margin: const pw.EdgeInsets.all(12),
                build: (_) => _buildPageLayout(slice),
              ),
            );
            i += _imagesPerPage;
          }
          return doc.save();
        },
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  pw.Widget _buildPageLayout(List<pw.MemoryImage> images) {
    if (images.length == 1) {
      return pw.Center(
        child: pw.Image(images[0], fit: pw.BoxFit.contain),
      );
    }

    final cols = _imagesPerPage <= 2 ? images.length.clamp(1, 2) : 2;
    final rows = (_imagesPerPage / cols).ceil();

    pw.Widget cell(pw.MemoryImage img) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
        );

    final rowWidgets = <pw.Widget>[];
    for (var r = 0; r < rows; r++) {
      final start = r * cols;
      final end = (start + cols).clamp(0, images.length);
      if (start >= images.length) break;

      final rowCells = <pw.Widget>[
        for (var c = start; c < end; c++) cell(images[c]),
        for (var k = end - start; k < cols; k++)
          pw.Expanded(child: pw.SizedBox()),
      ];

      rowWidgets.add(pw.Expanded(child: pw.Row(children: rowCells)));
    }

    return pw.Column(children: rowWidgets);
  }


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
        title: Text(
          '批量打印',
          style: TextStyle(
            color: theme.colorScheme.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isPrinting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : ShadButton(
                    onPressed: _files.isNotEmpty ? _print : null,
                    leading: const Icon(Icons.print_rounded, size: 18),
                    child: const Text('立即打印'),
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
        child: Row(
          children: [
            // ── Left:精致文件列表 ──────────────────────────────
            Container(
              width: 320,
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
                          '待打印图片',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        ShadBadge.secondary(
                          child: Text('${_files.length}', style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        ShadIconButton.ghost(
                          onPressed: _addFiles,
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _files.isEmpty
                        ? _buildEmptyState(theme)
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _files.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                _files.insert(newIndex, _files.removeAt(oldIndex));
                              });
                            },
                            itemBuilder: (context, index) => _FileListItem(
                              key: ValueKey(_files[index].path),
                              file: _files[index],
                              index: index,
                              onRemove: () => _removeFile(index),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── Right: 现代化设置与预览 ─────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(theme, '参数配置', Icons.tune_rounded),
                    const SizedBox(height: 20),
                    
                    // 设置卡片
                    ShadCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _SettingRow(
                            label: '每页数量',
                            icon: Icons.grid_view_rounded,
                            child: SegmentedButton<int>(
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: _layoutOptions
                                  .map((n) => ButtonSegment<int>(
                                        value: n,
                                        label: Text('$n'),
                                      ))
                                  .toList(),
                              selected: {_imagesPerPage},
                              onSelectionChanged: (v) => setState(() => _imagesPerPage = v.first),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, thickness: 0.5),
                          ),
                          _SettingRow(
                            label: '纸张方向',
                            icon: Icons.screen_rotation_rounded,
                            child: SegmentedButton<bool>(
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('纵向'),
                                  icon: Icon(Icons.crop_portrait_rounded, size: 16),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('横向'),
                                  icon: Icon(Icons.crop_landscape_rounded, size: 16),
                                ),
                              ],
                              selected: {_landscape},
                              onSelectionChanged: (v) => setState(() => _landscape = v.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    _buildSectionHeader(theme, '版式预览', Icons.auto_awesome_motion_rounded),
                    const SizedBox(height: 20),
                    
                    if (_files.isNotEmpty)
                      _LayoutPreview(
                        perPage: _imagesPerPage,
                        files: _files,
                        landscape: _landscape,
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.muted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.border, width: 1, style: BorderStyle.none),
                        ),
                        child: Center(
                          child: Text(
                            '添加图片后即可预览',
                            style: TextStyle(color: theme.colorScheme.mutedForeground),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_photo_alternate_rounded,
              size: 40,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '没有待打印的图片',
            style: TextStyle(color: theme.colorScheme.mutedForeground, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ShadButton.secondary(
            onPressed: _addFiles,
            child: const Text('添加图片'),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.foreground,
          ),
        ),
      ],
    );
  }
}

class _FileListItem extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;

  const _FileListItem({
    super.key,
    required this.file,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: theme.colorScheme.border, width: 0.5),
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
              width: 50,
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(file.path),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '第 ${index + 1} 张',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground),
                  ),
                ],
              ),
            ),
            ShadIconButton.ghost(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.destructive),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _SettingRow({required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const Spacer(),
        child,
      ],
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  final int perPage;
  final List<File> files;
  final bool landscape;

  const _LayoutPreview({
    required this.perPage,
    required this.files,
    required this.landscape,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cols = perPage <= 2 ? perPage : 2;
    final rows = (perPage / cols).ceil();

    final previewWidth = landscape ? 180.0 : 140.0;
    final previewHeight = landscape ? 140.0 : 180.0;

    final totalPages = (files.length / perPage).ceil();

    return Wrap(
      spacing: 24,
      runSpacing: 32,
      alignment: WrapAlignment.start,
      children: List.generate(totalPages, (pageIndex) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: previewWidth,
              height: previewHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: List.generate(rows, (r) {
                  return Expanded(
                    child: Row(
                      children: List.generate(cols, (c) {
                        final cellIndex = r * cols + c;
                        final fileIndex = pageIndex * perPage + cellIndex;
                        final hasImage = fileIndex < files.length;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: hasImage ? Colors.grey[100] : theme.colorScheme.muted.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                              border: hasImage ? Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5) : null,
                            ),
                            child: hasImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(1),
                                    child: Image.file(
                                      files[fileIndex],
                                      fit: BoxFit.cover,
                                      cacheWidth: 150,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, size: 12, color: Colors.grey),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            ShadBadge.secondary(
              child: Text('Page ${pageIndex + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }
}
