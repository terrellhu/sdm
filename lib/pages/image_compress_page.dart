import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCompressPage extends StatefulWidget {
  const ImageCompressPage({super.key});

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  final List<_ImageEntry> _entries = [];
  int _jpegQuality = 80;
  String _outputFormat = 'jpg';
  bool _saveToSubfolder = true;
  String? _outputDirectory;
  bool _isCompressing = false;
  int _processedCount = 0;

  static const _supportedExtensions = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tiff', 'tif', 'webp',
  ];

  Future<void> _addImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        final file = File(f.path!);
        if (!_entries.any((e) => e.file.path == file.path)) {
          _entries.add(_ImageEntry(file: file, name: f.name));
        }
      }
    });
    _loadFileSizes();
  }

  Future<void> _addFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    final all = await Directory(dir).list(recursive: false).toList();
    final files = all.whereType<File>().where((f) {
      final ext = p.extension(f.path).toLowerCase().replaceFirst('.', '');
      return _supportedExtensions.contains(ext);
    }).toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    setState(() {
      for (final file in files) {
        if (!_entries.any((e) => e.file.path == file.path)) {
          _entries.add(_ImageEntry(file: file, name: p.basename(file.path)));
        }
      }
    });
    _loadFileSizes();
  }

  void _loadFileSizes() {
    for (final entry in _entries) {
      if (entry.originalSize == null) {
        entry.file.length().then((size) {
          if (mounted) setState(() => entry.originalSize = size);
        });
      }
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputDirectory = result);
  }

  Future<void> _compress() async {
    if (_entries.isEmpty) return;
    setState(() {
      _isCompressing = true;
      _processedCount = 0;
      for (final e in _entries) {
        e.compressedSize = null;
        e.error = null;
      }
    });

    String outputDir;
    if (_outputDirectory != null) {
      outputDir = _outputDirectory!;
    } else {
      final downloads = await getDownloadsDirectory();
      final base = downloads?.path ?? (await getTemporaryDirectory()).path;
      outputDir = _saveToSubfolder ? p.join(base, 'compressed') : base;
    }
    await Directory(outputDir).create(recursive: true);

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      try {
        final bytes = await entry.file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) throw Exception('无法解码图片');

        final List<int> encoded;
        String ext;

        switch (_outputFormat) {
          case 'jpg':
            encoded = img.encodeJpg(decoded, quality: _jpegQuality);
            ext = '.jpg';
          case 'png':
            encoded = img.encodePng(decoded);
            ext = '.png';
          default: // keep
            final srcExt = p.extension(entry.file.path).toLowerCase();
            if (srcExt == '.png') {
              encoded = img.encodePng(decoded);
              ext = '.png';
            } else {
              encoded = img.encodeJpg(decoded, quality: _jpegQuality);
              ext = srcExt.isEmpty ? '.jpg' : srcExt;
            }
        }

        final baseName = p.basenameWithoutExtension(entry.name);
        final outPath = p.join(outputDir, '$baseName$ext');
        await File(outPath).writeAsBytes(encoded);

        setState(() {
          entry.compressedSize = encoded.length;
          _processedCount = i + 1;
        });
      } catch (e) {
        setState(() {
          entry.error = e.toString();
          _processedCount = i + 1;
        });
      }
    }

    setState(() => _isCompressing = false);
    _showSuccess(outputDir);
  }

  void _showSuccess(String dir) {
    final saved = _entries
        .where((e) => e.compressedSize != null && e.originalSize != null)
        .fold<int>(
          0,
          (s, e) => s + (e.originalSize! - e.compressedSize!).clamp(0, 999999999),
        );

    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('压缩完成'),
        description: Text(
          '处理 ${_entries.length} 张图片\n'
          '节省空间：${_formatSize(saved)}\n\n'
          '保存至：\n$dir',
        ),
        actions: [
          ShadButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定')),
        ],
      ),
    );
  }

  int get _totalOriginal => _entries.fold(0, (s, e) => s + (e.originalSize ?? 0));
  int get _totalCompressed => _entries.fold(0, (s, e) => s + (e.compressedSize ?? 0));

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  double? get _compressionRatio {
    if (_totalOriginal == 0 || _totalCompressed == 0) return null;
    return _totalCompressed / _totalOriginal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final progress = _entries.isEmpty ? 0.0 : _processedCount / _entries.length;

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
          '图片压缩',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (_isCompressing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_processedCount/${_entries.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed: (!_isCompressing && _entries.isNotEmpty) ? _compress : null,
              leading: const Icon(Icons.bolt_rounded, size: 18),
              child: const Text('开始压缩'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: 图片列表 ─────────────────────────────
          Container(
            width: 380,
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
                        '处理队列',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.mutedForeground),
                      ),
                      const Spacer(),
                      ShadBadge.secondary(
                        child: Text('${_entries.length}', style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      ShadIconButton.ghost(
                        onPressed: _addFolder,
                        icon: const Icon(Icons.create_new_folder_rounded, size: 20),
                      ),
                      ShadIconButton.ghost(
                        onPressed: _addImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) => _EntryTile(
                            entry: _entries[i],
                            formatSize: _formatSize,
                            onRemove: () => setState(() => _entries.removeAt(i)),
                          ),
                        ),
                ),
                // 汇总栏
                if (_entries.isNotEmpty) _buildSummaryBar(theme),
              ],
            ),
          ),

          // ── Right: 设置面板 ─────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [theme.colorScheme.background, theme.colorScheme.muted.withValues(alpha: 0.2)],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(theme, '压缩配置', Icons.tune_rounded),
                    const SizedBox(height: 20),
                    
                    ShadCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildSettingTile(
                            theme,
                            title: '输出格式',
                            icon: Icons.extension_rounded,
                            child: Row(
                              children: [
                                _ChoiceChip(
                                  label: 'JPEG',
                                  selected: _outputFormat == 'jpg',
                                  onTap: () => setState(() => _outputFormat = 'jpg'),
                                ),
                                const SizedBox(width: 8),
                                _ChoiceChip(
                                  label: 'PNG',
                                  selected: _outputFormat == 'png',
                                  onTap: () => setState(() => _outputFormat = 'png'),
                                ),
                                const SizedBox(width: 8),
                                _ChoiceChip(
                                  label: '保持原样',
                                  selected: _outputFormat == 'keep',
                                  onTap: () => setState(() => _outputFormat = 'keep'),
                                ),
                              ],
                            ),
                          ),
                          
                          if (_outputFormat != 'png') ...[
                            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, thickness: 0.5)),
                            _buildSettingTile(
                              theme,
                              title: '压缩质量',
                              icon: Icons.high_quality_rounded,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_jpegQuality >= 90 ? '高质量' : (_jpegQuality >= 60 ? '平衡' : '高压缩'), 
                                           style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                      Text('$_jpegQuality%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ShadSlider(
                                    initialValue: _jpegQuality.toDouble(),
                                    min: 10,
                                    max: 100,
                                    divisions: 18,
                                    onChanged: (v) => setState(() => _jpegQuality = v.toInt()),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('体积优先', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                                      Text('画质优先', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, thickness: 0.5)),
                          
                          _buildSettingTile(
                            theme,
                            title: '保存位置',
                            icon: Icons.folder_copy_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _outputDirectory ?? '默认下载文件夹/${_saveToSubfolder ? "compressed/" : ""}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _outputDirectory != null ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ShadButton.secondary(
                                      onPressed: _pickOutputDirectory,
                                      size: ShadButtonSize.sm,
                                      leading: const Icon(Icons.edit_location_alt_rounded, size: 16),
                                      child: const Text('更改'),
                                    ),
                                  ],
                                ),
                                if (_outputDirectory == null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ShadSwitch(
                                        value: _saveToSubfolder,
                                        onChanged: (v) => setState(() => _saveToSubfolder = v),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('创建 "compressed" 子文件夹', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    _buildSectionHeader(theme, '参考指南', Icons.info_outline_rounded),
                    const SizedBox(height: 20),
                    
                    ShadCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildHintRow(theme, '90% - 100%', '画质近乎无损，适合高要求存档', _jpegQuality >= 90),
                          const SizedBox(height: 16),
                          _buildHintRow(theme, '70% - 85%', '体积显著减小，肉眼难察觉差异 (推荐)', _jpegQuality >= 70 && _jpegQuality < 90),
                          const SizedBox(height: 16),
                          _buildHintRow(theme, '40% - 65%', '高比例压缩，适合网页快速预览', _jpegQuality >= 40 && _jpegQuality < 70),
                          const SizedBox(height: 16),
                          _buildHintRow(theme, '10% - 35%', '极限压缩，可能会有明显噪点', _jpegQuality < 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_size_select_large_rounded, size: 56, color: theme.colorScheme.mutedForeground.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          ShadButton.secondary(
            onPressed: _addImages,
            leading: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            child: const Text('添加图片'),
          ),
          const SizedBox(height: 12),
          Text('或者点击上方文件夹按钮批量导入', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(top: BorderSide(color: theme.colorScheme.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('当前总体积', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)),
              Text(_formatSize(_totalOriginal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          if (_totalCompressed > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('压缩后体积', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)),
                Text(_formatSize(_totalCompressed), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_down_rounded, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '已节省 ${((1 - (_compressionRatio ?? 1)) * 100).toStringAsFixed(1)}% 的空间',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ShadThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildHintRow(ShadThemeData theme, String range, String desc, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? theme.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? theme.colorScheme.primary : theme.colorScheme.mutedForeground.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: Text(range, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal))),
          Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: active ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground))),
        ],
      ),
    );
  }
}

class _ImageEntry {
  final File file;
  final String name;
  int? originalSize;
  int? compressedSize;
  String? error;

  _ImageEntry({required this.file, required this.name});
}

class _EntryTile extends StatelessWidget {
  final _ImageEntry entry;
  final String Function(int) formatSize;
  final VoidCallback onRemove;

  const _EntryTile({required this.entry, required this.formatSize, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasResult = entry.compressedSize != null;
    final hasError = entry.error != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? Colors.red.withValues(alpha: 0.5) : (hasResult ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.colorScheme.border),
          width: hasResult || hasError ? 1 : 0.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.file(
                  entry.file,
                  fit: BoxFit.cover,
                  cacheWidth: 100,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (hasError)
                    Text('压缩失败', style: TextStyle(fontSize: 11, color: theme.colorScheme.destructive, fontWeight: FontWeight.w500))
                  else if (hasResult)
                    Row(
                      children: [
                        Text(formatSize(entry.originalSize ?? 0), style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(formatSize(entry.compressedSize!), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ],
                    )
                  else
                    Text(formatSize(entry.originalSize ?? 0), style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
            if (hasResult)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
            else if (hasError)
              Icon(Icons.error_rounded, color: theme.colorScheme.destructive, size: 20)
            else
              ShadIconButton.ghost(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.destructive),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? theme.colorScheme.primaryForeground : theme.colorScheme.foreground,
          ),
        ),
      ),
    );
  }
}
