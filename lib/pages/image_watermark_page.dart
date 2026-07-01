import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/image_tasks.dart';
import '../utils/watermark_painter.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class ImageWatermarkPage extends StatefulWidget {
  const ImageWatermarkPage({super.key});

  @override
  State<ImageWatermarkPage> createState() => _ImageWatermarkPageState();
}

class _ImageWatermarkPageState extends State<ImageWatermarkPage> {
  final List<File> _files = [];
  String _text = '仅供参考';
  double _fontSize = 42;
  double _opacity = 0.3;
  bool _diagonal = true;
  bool _tiled = true;
  Color _color = Colors.white;
  String? _outputDirectory = AppPrefs.outputDir;
  bool _isWorking = false;
  int _processed = 0;

  static const _presetColors = {
    '白色': Colors.white,
    '黑色': Colors.black,
    '红色': Colors.red,
    '蓝色': Colors.blue,
    '黄色': Colors.yellow,
    '灰色': Colors.grey,
  };

  WatermarkStyle get _style => WatermarkStyle(
        text: _text,
        color: _color.withValues(alpha: _opacity),
        fontSizePt: _fontSize,
        tiled: _tiled,
        diagonal: _diagonal,
      );

  Future<void> _addImages() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        if (!_files.any((e) => e.path == file.path)) _files.add(file);
      }
    });
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      AppPrefs.outputDir = result;
    }
  }

  Future<void> _run() async {
    if (_files.isEmpty) return;
    setState(() {
      _isWorking = true;
      _processed = 0;
    });
    final dir = await resolveOutputDir(
        preferred: _outputDirectory, subfolder: 'watermarked');
    final style = _style;
    String? firstOut;
    int ok = 0;
    for (var i = 0; i < _files.length; i++) {
      try {
        final bytes = await _files[i].readAsBytes();
        final size = await compute(decodeSize, bytes);
        if (size == null) throw const FormatException('无法解码');
        final overlay = await buildWatermarkPngForPixels(
          widthPx: size[0],
          heightPx: size[1],
          style: style,
        );
        final ext = p.extension(_files[i].path).replaceFirst('.', '');
        final result = await compute(
          runComposite,
          CompositeOp(
            baseBytes: bytes,
            overlayPng: overlay,
            format: 'keep',
            sourceExt: ext,
          ),
        );
        final baseName = p.basenameWithoutExtension(_files[i].path);
        final outPath = uniquePath(dir, '${baseName}_水印', result.ext);
        await File(outPath).writeAsBytes(result.bytes);
        firstOut ??= outPath;
        ok++;
      } catch (_) {}
      setState(() => _processed = i + 1);
    }
    if (!mounted) return;
    setState(() => _isWorking = false);
    showResultDialog(
      context,
      title: '水印已添加',
      message: '成功处理 $ok / ${_files.length} 张图片。\n\n$dir',
      outputPath: firstOut ?? dir,
      isFile: firstOut != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final progress = _files.isEmpty ? 0.0 : _processed / _files.length;
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: '图片加水印',
        actions: [
          if (_isWorking)
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
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('$_processed/${_files.length}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShadButton(
              onPressed: (!_isWorking && _files.isNotEmpty) ? _run : null,
              leading: const Icon(Icons.branding_watermark_rounded, size: 18),
              child: const Text('批量添加'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 360,
            decoration: BoxDecoration(
              border: Border(
                  right:
                      BorderSide(color: theme.colorScheme.border, width: 0.5)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.background,
                  theme.colorScheme.muted.withValues(alpha: 0.1)
                ],
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                          child: SectionHeader('图片', Icons.photo_library_rounded)),
                      ShadBadge.secondary(
                          child: Text('${_files.length}',
                              style: const TextStyle(fontSize: 11))),
                      const SizedBox(width: 8),
                      ShadIconButton.ghost(
                        onPressed: _addImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded,
                            size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_files.isEmpty)
                    ShadButton.outline(
                      onPressed: _addImages,
                      leading: const Icon(Icons.add_rounded, size: 18),
                      child: const Text('添加图片'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_files.length, (i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Image.file(_files[i],
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_rounded, size: 20)),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: ShadIconButton.ghost(
                                width: 24,
                                height: 24,
                                onPressed: () =>
                                    setState(() => _files.removeAt(i)),
                                icon: Icon(Icons.cancel_rounded,
                                    size: 16,
                                    color: theme.colorScheme.destructive),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  const SizedBox(height: 28),
                  const SectionHeader('水印样式', Icons.style_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('水印内容'),
                        ShadInput(
                          initialValue: _text,
                          placeholder: const Text('请输入水印文字'),
                          onChanged: (v) => setState(() => _text = v),
                        ),
                        const SizedBox(height: 20),
                        _label('颜色预设'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _presetColors.entries.map((entry) {
                            final sel = _color.toARGB32() ==
                                entry.value.toARGB32();
                            return GestureDetector(
                              onTap: () => setState(() => _color = entry.value),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.border,
                                    width: sel ? 2.5 : 1,
                                  ),
                                ),
                                child: sel
                                    ? Icon(Icons.check,
                                        size: 15,
                                        color: entry.value
                                                    .computeLuminance() >
                                                0.5
                                            ? Colors.black
                                            : Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _label('透明度'),
                            Text('${(_opacity * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ShadSlider(
                          initialValue: _opacity,
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          onChanged: (v) => setState(() => _opacity = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _label('字体大小'),
                            Text('${_fontSize.toInt()}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ShadSlider(
                          initialValue: _fontSize,
                          min: 16,
                          max: 120,
                          divisions: 26,
                          onChanged: (v) => setState(() => _fontSize = v),
                        ),
                        const SizedBox(height: 12),
                        _toggle('平铺整页', _tiled,
                            (v) => setState(() => _tiled = v)),
                        const SizedBox(height: 8),
                        _toggle('45° 倾斜', _diagonal,
                            (v) => setState(() => _diagonal = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader('保存设置', Icons.folder_open_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: OutputDirRow(
                      directory: _outputDirectory,
                      placeholder: '默认下载文件夹/watermarked/',
                      onPick: _pickOutputDirectory,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: theme.colorScheme.muted.withValues(alpha: 0.2),
              child: _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.branding_watermark_rounded,
                              size: 64,
                              color: theme.colorScheme.mutedForeground
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('添加图片后在此实时预览水印效果',
                              style: TextStyle(
                                  color: theme.colorScheme.mutedForeground)),
                        ],
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                Image.file(_files.first,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: Icon(
                                            Icons.broken_image_rounded))),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: WatermarkPreviewPainter(_style),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Row(
        children: [
          ShadSwitch(value: value, onChanged: onChanged),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      );
}
