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

          // Pre-load all images
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

    // Determine grid dimensions
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
        // Fill empty slots so row stays balanced
        for (var k = end - start; k < cols; k++)
          pw.Expanded(child: pw.SizedBox()),
      ];

      rowWidgets.add(pw.Expanded(child: pw.Row(children: rowCells)));
    }

    return pw.Column(children: rowWidgets);
  }

  int get _totalPages => _files.isEmpty
      ? 0
      : (_files.length / _imagesPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('批量打印'),
        actions: [
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed: (!_isPrinting && _files.isNotEmpty) ? _print : null,
              leading: const Icon(Icons.print, size: 16),
              child: const Text('打印'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: file list ──────────────────────────────
          SizedBox(
            width: 300,
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
                          '图片列表  ${_files.length} 张',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: _addFiles,
                        leading: const Icon(Icons.add, size: 14),
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: theme.colorScheme.mutedForeground,
                              ),
                              const SizedBox(height: 12),
                              ShadButton(
                                onPressed: _addFiles,
                                child: const Text('添加图片'),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          itemCount: _files.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              _files.insert(
                                  newIndex, _files.removeAt(oldIndex));
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

          // ── Divider ──────────────────────────────────────
          VerticalDivider(
              width: 1, color: theme.colorScheme.border),

          // ── Right: settings + summary ─────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '打印设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Images per page
                  _SettingRow(
                    label: '每页图片数',
                    child: SegmentedButton<int>(
                      segments: _layoutOptions
                          .map((n) => ButtonSegment<int>(
                                value: n,
                                label: Text('$n'),
                              ))
                          .toList(),
                      selected: {_imagesPerPage},
                      onSelectionChanged: (v) =>
                          setState(() => _imagesPerPage = v.first),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Orientation
                  _SettingRow(
                    label: '页面方向',
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('纵向'),
                          icon: Icon(Icons.crop_portrait, size: 15),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('横向'),
                          icon: Icon(Icons.crop_landscape, size: 15),
                        ),
                      ],
                      selected: {_landscape},
                      onSelectionChanged: (v) =>
                          setState(() => _landscape = v.first),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Summary card
                  ShadCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '打印摘要',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoRow('图片总数', '${_files.length} 张'),
                        _InfoRow('每页数量', '$_imagesPerPage 张 / 页'),
                        _InfoRow('总页数', '$_totalPages 页'),
                        _InfoRow('纸张方向', _landscape ? '横向' : '纵向'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Layout preview
                  if (_files.isNotEmpty)
                    _LayoutPreview(
                      perPage: _imagesPerPage,
                      files: _files,
                      landscape: _landscape,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// File list item (reorderable)
// ──────────────────────────────────────────────

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
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          // Drag handle (provided by ReorderableListView)
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            ),
          ),
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: 88,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filename
          Expanded(
            child: Text(
              p.basename(file.path),
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Remove
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

// ──────────────────────────────────────────────
// Setting row helper
// ──────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        child,
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Info row helper
// ──────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Layout preview widget (shows grid diagram)
// ──────────────────────────────────────────────

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

    final previewWidth = landscape ? 160.0 : 120.0;
    final previewHeight = landscape ? 120.0 : 160.0;

    return ShadCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '版式预览 (第 1 页)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: previewWidth,
              height: previewHeight,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.border),
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.muted,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: List.generate(rows, (r) {
                  return Expanded(
                    child: Row(
                      children: List.generate(cols, (c) {
                        final index = r * cols + c;
                        final hasImage = index < files.length;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: hasImage
                                  ? Colors.white
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: theme.colorScheme.border,
                                width: 0.5,
                              ),
                            ),
                            child: hasImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(1),
                                    child: Image.file(
                                      files[index],
                                      fit: BoxFit.cover,
                                      cacheWidth: 100,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_outlined,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
