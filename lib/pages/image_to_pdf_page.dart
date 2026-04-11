import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  final List<File> _images = [];
  String _pageSize = 'A4';
  bool _landscape = false;
  String _fitMode = 'contain'; // contain | fill
  String? _outputDirectory;
  String _outputFilename = 'output.pdf';
  bool _isConverting = false;
  double _progress = 0;

  static const _pageSizes = {
    'A4': PdfPageFormat.a4,
    'A3': PdfPageFormat.a3,
    'Letter': PdfPageFormat.letter,
    '原始尺寸': null,
  };

  Future<void> _addImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        final file = File(f.path!);
        if (!_images.any((e) => e.path == file.path)) {
          _images.add(file);
        }
      }
    });
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputDirectory = result);
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() {
      _isConverting = true;
      _progress = 0;
    });

    try {
      final doc = pw.Document();

      for (var i = 0; i < _images.length; i++) {
        final bytes = await _images[i].readAsBytes();
        final image = pw.MemoryImage(bytes);

        PdfPageFormat format;
        if (_pageSize == '原始尺寸') {
          // We'll use A4 but fit image — actual size doesn't matter for contain
          format = PdfPageFormat.a4;
        } else {
          format = _pageSizes[_pageSize] ?? PdfPageFormat.a4;
        }
        if (_landscape) {
          format = PdfPageFormat(format.height, format.width);
        }

        final fitMode = _fitMode == 'fill' ? pw.BoxFit.fill : pw.BoxFit.contain;

        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: _fitMode == 'fill'
                ? pw.EdgeInsets.zero
                : const pw.EdgeInsets.all(16),
            build: (_) => pw.Center(
              child: pw.Image(image, fit: fitMode),
            ),
          ),
        );

        setState(() => _progress = (i + 1) / _images.length);
      }

      final outputDir = _outputDirectory ??
          (await getDownloadsDirectory())?.path ??
          (await getTemporaryDirectory()).path;

      final outPath = p.join(outputDir, _outputFilename);
      await File(outPath).writeAsBytes(await doc.save());

      setState(() => _isConverting = false);
      _showSuccess(outPath);
    } catch (e) {
      setState(() => _isConverting = false);
      _showError('转换失败：$e');
    }
  }

  void _showSuccess(String path) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('转换完成'),
        description: Text('${_images.length} 张图片已转换为 PDF\n\n保存至：\n$path'),
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('图片转 PDF'),
        actions: [
          if (!_isConverting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _images.isNotEmpty ? _convert : null,
                leading: const Icon(Icons.picture_as_pdf, size: 16),
                child: const Text('开始转换'),
              ),
            ),
        ],
      ),
      body: _isConverting ? _buildProgress(theme) : _buildMain(theme),
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
            Text('正在处理第 ${(_progress * _images.length).ceil()} / ${_images.length} 张',
                style: TextStyle(color: theme.colorScheme.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(ShadThemeData theme) {
    return Row(
      children: [
        // ── Left: image list ─────────────────────────────
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
                        '图片列表  ${_images.length} 张',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: _addImages,
                      leading: const Icon(Icons.add, size: 14),
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _images.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: theme.colorScheme.mutedForeground),
                            const SizedBox(height: 12),
                            ShadButton(
                              onPressed: _addImages,
                              child: const Text('添加图片'),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemCount: _images.length,
                        onReorder: (old, neo) {
                          setState(() {
                            if (neo > old) neo--;
                            _images.insert(neo, _images.removeAt(old));
                          });
                        },
                        itemBuilder: (_, i) => _ImageListItem(
                          key: ValueKey(_images[i].path),
                          file: _images[i],
                          index: i,
                          onRemove: () =>
                              setState(() => _images.removeAt(i)),
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
                Text('转换设置',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.foreground)),
                const SizedBox(height: 24),

                // Page size
                _SettingSection(
                  label: '页面尺寸',
                  child: Wrap(
                    spacing: 8,
                    children: _pageSizes.keys.map((size) {
                      final selected = _pageSize == size;
                      return _ChoiceChip(
                        label: size,
                        selected: selected,
                        onTap: () => setState(() => _pageSize = size),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Orientation
                _SettingSection(
                  label: '页面方向',
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('纵向'),
                          icon: Icon(Icons.crop_portrait, size: 15)),
                      ButtonSegment(
                          value: true,
                          label: Text('横向'),
                          icon: Icon(Icons.crop_landscape, size: 15)),
                    ],
                    selected: {_landscape},
                    onSelectionChanged: (v) =>
                        setState(() => _landscape = v.first),
                  ),
                ),
                const SizedBox(height: 20),

                // Fit mode
                _SettingSection(
                  label: '图片适配',
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'contain',
                          label: Text('保持比例'),
                          icon: Icon(Icons.fit_screen, size: 15)),
                      ButtonSegment(
                          value: 'fill',
                          label: Text('铺满页面'),
                          icon: Icon(Icons.fullscreen, size: 15)),
                    ],
                    selected: {_fitMode},
                    onSelectionChanged: (v) =>
                        setState(() => _fitMode = v.first),
                  ),
                ),
                const SizedBox(height: 20),

                // Output filename
                _SettingSection(
                  label: '输出文件名',
                  child: ShadInput(
                    initialValue: _outputFilename,
                    onChanged: (v) => setState(
                        () => _outputFilename = v.isEmpty ? 'output.pdf' : v),
                  ),
                ),
                const SizedBox(height: 20),

                // Output directory
                _SettingSection(
                  label: '保存位置',
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

                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('转换摘要',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.foreground)),
                      const SizedBox(height: 12),
                      _InfoRow('图片数量', '${_images.length} 张'),
                      _InfoRow('页面尺寸', '$_pageSize  ${_landscape ? "横向" : "纵向"}'),
                      _InfoRow('图片适配', _fitMode == 'contain' ? '保持比例' : '铺满页面'),
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
}

// ──────────────────────────────────────────────

class _ImageListItem extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;

  const _ImageListItem({
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
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.file(file,
                  fit: BoxFit.cover,
                  cacheWidth: 88,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image, size: 20)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p.basename(file.path),
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
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

class _SettingSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? theme.colorScheme.primaryForeground
                : theme.colorScheme.secondaryForeground,
          ),
        ),
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
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
