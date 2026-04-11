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
  String _outputFormat = 'jpg'; // jpg | png | keep
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
            final srcExt =
                p.extension(entry.file.path).toLowerCase();
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

  int get _totalOriginal =>
      _entries.fold(0, (s, e) => s + (e.originalSize ?? 0));
  int get _totalCompressed =>
      _entries.fold(0, (s, e) => s + (e.compressedSize ?? 0));

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
    final progress =
        _entries.isEmpty ? 0.0 : _processedCount / _entries.length;

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('图片压缩'),
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
                        strokeWidth: 2, value: progress),
                  ),
                  const SizedBox(width: 8),
                  Text('$_processedCount/${_entries.length}',
                      style: TextStyle(
                          color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed:
                  (!_isCompressing && _entries.isNotEmpty) ? _compress : null,
              leading: const Icon(Icons.compress, size: 16),
              child: const Text('开始压缩'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: file list ─────────────────────────────
          SizedBox(
            width: 340,
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
                          '图片列表  ${_entries.length} 张',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: _addFolder,
                        leading: const Icon(Icons.folder_open, size: 14),
                        child: const Text('文件夹'),
                      ),
                      const SizedBox(width: 6),
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
                  child: _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_size_select_large,
                                  size: 48,
                                  color: theme.colorScheme.mutedForeground),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShadButton(
                                      onPressed: _addImages,
                                      child: const Text('添加图片')),
                                  const SizedBox(width: 8),
                                  ShadButton.outline(
                                      onPressed: _addFolder,
                                      child: const Text('选择文件夹')),
                                ],
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) =>
                              _EntryTile(
                                entry: _entries[i],
                                formatSize: _formatSize,
                                onRemove: () =>
                                    setState(() => _entries.removeAt(i)),
                              ),
                        ),
                ),
                // Totals bar
                if (_entries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: theme.colorScheme.border)),
                      color: theme.colorScheme.muted,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '原始：${_formatSize(_totalOriginal)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_totalCompressed > 0) ...[
                          Text('→ ',
                              style: TextStyle(
                                  color: theme.colorScheme.mutedForeground)),
                          Text(
                            _formatSize(_totalCompressed),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_compressionRatio != null)
                            Text(
                              '  (${(100 - _compressionRatio! * 100).toStringAsFixed(0)}% 压缩)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade600),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: theme.colorScheme.border),

          // ── Right: settings ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('压缩设置',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.foreground)),
                  const SizedBox(height: 24),

                  // Output format
                  _SettingSection(
                    label: '输出格式',
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'jpg', label: Text('JPEG')),
                        ButtonSegment(value: 'png', label: Text('PNG')),
                        ButtonSegment(value: 'keep', label: Text('保持原格式')),
                      ],
                      selected: {_outputFormat},
                      onSelectionChanged: (v) =>
                          setState(() => _outputFormat = v.first),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // JPEG quality (only for jpg/keep)
                  if (_outputFormat != 'png') ...[
                    _SettingSection(
                      label: 'JPEG 质量  $_jpegQuality%',
                      subtitle: '越高质量越好，文件越大',
                      child: Column(
                        children: [
                          ShadSlider(
                            initialValue: _jpegQuality.toDouble(),
                            min: 10,
                            max: 100,
                            divisions: 18,
                            onChanged: (v) =>
                                setState(() => _jpegQuality = v.toInt()),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('最小体积',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          theme.colorScheme.mutedForeground)),
                              Text('最佳质量',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          theme.colorScheme.mutedForeground)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Output directory
                  _SettingSection(
                    label: '保存位置',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _outputDirectory ??
                                    '下载文件夹/${_saveToSubfolder ? "compressed/" : ""}',
                                style: TextStyle(
                                  fontSize: 13,
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
                        if (_outputDirectory == null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _saveToSubfolder,
                                onChanged: (v) => setState(
                                    () => _saveToSubfolder = v ?? true),
                              ),
                              const Text('保存到 compressed/ 子文件夹',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Quality preview card
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('质量参考',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.foreground)),
                        const SizedBox(height: 12),
                        ...[
                          ('95%+', '无损级别，适合存档'),
                          ('80-90%', '高质量，推荐日常使用'),
                          ('60-75%', '平衡质量与体积'),
                          ('40-55%', '小体积，适合网络分享'),
                        ].map((e) => _QualityHint(
                            range: e.$1,
                            desc: e.$2,
                            highlighted: _outputFormat != 'png' &&
                                _qualityInRange(_jpegQuality, e.$1))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _qualityInRange(int q, String range) {
    if (range.contains('+')) {
      final min = int.tryParse(range.replaceAll('%+', '')) ?? 0;
      return q >= min;
    }
    final parts = range.replaceAll('%', '').split('-');
    if (parts.length != 2) return false;
    final lo = int.tryParse(parts[0]) ?? 0;
    final hi = int.tryParse(parts[1]) ?? 100;
    return q >= lo && q <= hi;
  }
}

// ──────────────────────────────────────────────

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

  const _EntryTile({
    required this.entry,
    required this.formatSize,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasResult = entry.compressedSize != null;
    final hasError = entry.error != null;

    String sizeLabel = '';
    Color? sizeColor;
    if (hasError) {
      sizeLabel = '失败';
      sizeColor = Colors.red;
    } else if (hasResult && entry.originalSize != null) {
      final ratio = entry.compressedSize! / entry.originalSize!;
      sizeLabel =
          '${formatSize(entry.originalSize!)} → ${formatSize(entry.compressedSize!)} '
          '(-${(100 - ratio * 100).toStringAsFixed(0)}%)';
      sizeColor = Colors.green.shade700;
    } else if (entry.originalSize != null) {
      sizeLabel = formatSize(entry.originalSize!);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasError
            ? Colors.red.withValues(alpha: 0.05)
            : hasResult
                ? Colors.green.withValues(alpha: 0.05)
                : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasError
              ? Colors.red.withValues(alpha: 0.3)
              : hasResult
                  ? Colors.green.withValues(alpha: 0.3)
                  : theme.colorScheme.border,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Image.file(
                entry.file,
                fit: BoxFit.cover,
                cacheWidth: 72,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (sizeLabel.isNotEmpty)
                  Text(sizeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: sizeColor ?? Colors.grey)),
              ],
            ),
          ),
          if (hasResult)
            const Icon(Icons.check_circle,
                color: Colors.green, size: 16),
          if (hasError)
            const Icon(Icons.error_outline,
                color: Colors.red, size: 16),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close,
                size: 15, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget child;
  const _SettingSection(
      {required this.label, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        if (subtitle != null)
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 11,
                  color: ShadTheme.of(context).colorScheme.mutedForeground)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _QualityHint extends StatelessWidget {
  final String range;
  final String desc;
  final bool highlighted;
  const _QualityHint(
      {required this.range,
      required this.desc,
      required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.blue
                  : Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(range,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: highlighted
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: highlighted ? Colors.blue : Colors.grey)),
          ),
          Text(desc,
              style: TextStyle(
                  fontSize: 13,
                  color: highlighted ? null : Colors.grey)),
        ],
      ),
    );
  }
}
