import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/image_tasks.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class ImageConvertPage extends StatefulWidget {
  const ImageConvertPage({super.key});

  @override
  State<ImageConvertPage> createState() => _ImageConvertPageState();
}

class _ImageConvertPageState extends State<ImageConvertPage> {
  final List<File> _files = [];
  String _target = 'jpg';
  int _quality = 90;
  bool _limitSize = false;
  int _maxDimension = 1920;
  String? _outputDirectory = AppPrefs.outputDir;
  bool _isWorking = false;
  int _processed = 0;

  static const _supportedExtensions = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tiff', 'tif', 'webp',
  ];
  static const _dimensionOptions = [1280, 1920, 2560, 3840];
  static const _targets = {
    'jpg': 'JPG',
    'png': 'PNG',
    'bmp': 'BMP',
    'tiff': 'TIFF',
  };

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

  Future<void> _convert() async {
    if (_files.isEmpty) return;
    setState(() {
      _isWorking = true;
      _processed = 0;
    });
    final outputDir =
        await resolveOutputDir(preferred: _outputDirectory, subfolder: 'converted');
    String? firstOut;
    int ok = 0;
    for (var i = 0; i < _files.length; i++) {
      try {
        final bytes = await _files[i].readAsBytes();
        final result = await compute(
          runImageOp,
          ImageOp(
            bytes: bytes,
            format: _target,
            quality: _quality,
            maxDimension: _limitSize ? _maxDimension : null,
          ),
        );
        final baseName = p.basenameWithoutExtension(_files[i].path);
        final outPath = uniquePath(outputDir, baseName, result.ext);
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
      title: '转换完成',
      message: '成功转换 $ok / ${_files.length} 张图片。\n\n$outputDir',
      outputPath: firstOut ?? outputDir,
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
        title: '图片格式转换',
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
              onPressed:
                  (!_isWorking && _files.isNotEmpty) ? _convert : null,
              leading: const Icon(Icons.swap_horiz_rounded, size: 18),
              child: const Text('开始转换'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 340,
            decoration: BoxDecoration(
              border: Border(
                  right:
                      BorderSide(color: theme.colorScheme.border, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Text('图片队列',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.mutedForeground)),
                      const Spacer(),
                      ShadBadge.secondary(
                          child: Text('${_files.length}',
                              style: const TextStyle(fontSize: 11))),
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
                  child: _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_rounded,
                                  size: 48,
                                  color: theme.colorScheme.mutedForeground
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              ShadButton.secondary(
                                  onPressed: _addImages,
                                  child: const Text('添加图片')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _files.length,
                          itemBuilder: (_, i) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: theme.colorScheme.border, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Image.file(_files[i],
                                        fit: BoxFit.cover,
                                        cacheWidth: 100,
                                        errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_rounded,
                                            size: 20)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(p.basename(_files[i].path),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                ShadIconButton.ghost(
                                  onPressed: () =>
                                      setState(() => _files.removeAt(i)),
                                  icon: Icon(Icons.delete_outline_rounded,
                                      size: 18,
                                      color: theme.colorScheme.destructive),
                                ),
                              ],
                            ),
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
                  const SectionHeader('转换设置', Icons.tune_rounded),
                  const SizedBox(height: 20),
                  ShadCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SettingTile(
                          title: '目标格式',
                          icon: Icons.extension_rounded,
                          child: Row(
                            children: _targets.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ToolChip(
                                  label: e.value,
                                  selected: _target == e.key,
                                  onTap: () => setState(() => _target = e.key),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (_target == 'jpg') ...[
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1, thickness: 0.5)),
                          SettingTile(
                            title: '质量 $_quality%',
                            icon: Icons.high_quality_rounded,
                            child: ShadSlider(
                              initialValue: _quality.toDouble(),
                              min: 10,
                              max: 100,
                              divisions: 18,
                              onChanged: (v) =>
                                  setState(() => _quality = v.toInt()),
                            ),
                          ),
                        ],
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1, thickness: 0.5)),
                        SettingTile(
                          title: '尺寸限制',
                          icon: Icons.photo_size_select_large_rounded,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ShadSwitch(
                                    value: _limitSize,
                                    onChanged: (v) =>
                                        setState(() => _limitSize = v),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text('缩小最长边（等比）',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              if (_limitSize) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: _dimensionOptions.map((d) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ToolChip(
                                        label: '${d}px',
                                        selected: _maxDimension == d,
                                        onTap: () =>
                                            setState(() => _maxDimension = d),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1, thickness: 0.5)),
                        SettingTile(
                          title: '保存位置',
                          icon: Icons.folder_special_rounded,
                          child: OutputDirRow(
                            directory: _outputDirectory,
                            placeholder: '默认下载文件夹/converted/',
                            onPick: _pickOutputDirectory,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('支持 JPG / PNG / BMP / TIFF / WebP / GIF 读取并互转（WebP 暂以 PNG 输出）。',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
