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
  String _fitMode = 'contain';
  String? _outputDirectory;
  final String _outputFilename = 'output.pdf';
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
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ShadIconButton.ghost(
          onPressed: () => context.go('/'),
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: theme.colorScheme.foreground),
        ),
        title: const Text(
          '图片转 PDF',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (!_isConverting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _images.isNotEmpty ? _convert : null,
                leading: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                child: const Text('开始转换'),
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
        child: _isConverting ? _buildProgress(theme) : _buildMain(theme),
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
            '正在生成 PDF 文件...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.colorScheme.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            '正在处理第 ${(_progress * _images.length).ceil()} / ${_images.length} 张图片',
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildMain(ShadThemeData theme) {
    return Row(
      children: [
        // ── Left: 图片列表 ─────────────────────────────
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
                      '图片队列',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    ShadBadge.secondary(
                      child: Text('${_images.length}', style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ShadIconButton.ghost(
                      onPressed: _addImages,
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _images.isEmpty
                    ? _buildEmptyList(theme)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                          onRemove: () => setState(() => _images.removeAt(i)),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // ── Right: 设置面板 ───────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, '转换参数', Icons.settings_suggest_rounded),
                const SizedBox(height: 20),
                
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        theme,
                        title: '页面尺寸',
                        icon: Icons.aspect_ratio_rounded,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      _buildSettingTile(
                        theme,
                        title: '页面方向',
                        icon: Icons.screen_rotation_rounded,
                        child: Row(
                          children: [
                            _ChoiceChip(
                              label: '纵向',
                              icon: Icons.crop_portrait_rounded,
                              selected: !_landscape,
                              onTap: () => setState(() => _landscape = false),
                            ),
                            const SizedBox(width: 8),
                            _ChoiceChip(
                              label: '横向',
                              icon: Icons.crop_landscape_rounded,
                              selected: _landscape,
                              onTap: () => setState(() => _landscape = true),
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
                        title: '图片适配',
                        icon: Icons.fit_screen_rounded,
                        child: Row(
                          children: [
                            _ChoiceChip(
                              label: '保持比例',
                              selected: _fitMode == 'contain',
                              onTap: () => setState(() => _fitMode = 'contain'),
                            ),
                            const SizedBox(width: 8),
                            _ChoiceChip(
                              label: '铺满页面',
                              selected: _fitMode == 'fill',
                              onTap: () => setState(() => _fitMode = 'fill'),
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
                
                _buildSectionHeader(theme, '转换摘要', Icons.assignment_rounded),
                const SizedBox(height: 20),
                
                ShadCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _InfoRow(Icons.photo_library_rounded, '图片总数', '${_images.length} 张'),
                      const SizedBox(height: 16),
                      _InfoRow(Icons.straighten_rounded, '页面尺寸', '$_pageSize  ${_landscape ? "横向" : "纵向"}'),
                      const SizedBox(height: 16),
                      _InfoRow(Icons.center_focus_strong_rounded, '适配模式', _fitMode == 'contain' ? '保持比例' : '铺满页面'),
                      const SizedBox(height: 16),
                      _InfoRow(Icons.save_rounded, '输出名称', _outputFilename),
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
          Icon(Icons.add_photo_alternate_rounded, size: 48, color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          ShadButton.secondary(
            onPressed: _addImages,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 100,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.basename(file.path),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? theme.colorScheme.primaryForeground : theme.colorScheme.foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? theme.colorScheme.primaryForeground : theme.colorScheme.foreground,
              ),
            ),
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
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: theme.colorScheme.mutedForeground, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
