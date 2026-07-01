import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/pdf_ops.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfOrganizePage extends StatefulWidget {
  const PdfOrganizePage({super.key});

  @override
  State<PdfOrganizePage> createState() => _PdfOrganizePageState();
}

class _PageItem {
  final int sourceIndex; // 0-based
  int rotation = 0; // 0/1/2/3 => 0/90/180/270
  _PageItem(this.sourceIndex);
}

class _PdfOrganizePageState extends State<PdfOrganizePage> {
  File? _pdfFile;
  String? _pdfName;
  pdfx.PdfDocument? _thumbDoc;
  List<_PageItem> _items = [];
  String? _outputDirectory = AppPrefs.outputDir;
  bool _isWorking = false;

  @override
  void dispose() {
    _thumbDoc?.close();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    try {
      await _thumbDoc?.close();
      final doc = await pdfx.PdfDocument.openFile(file.path);
      setState(() {
        _pdfFile = file;
        _pdfName = result.files.single.name;
        _thumbDoc = doc;
        _items = List.generate(doc.pagesCount, (i) => _PageItem(i));
      });
    } catch (e) {
      if (mounted) showErrorDialog(context, '无法打开 PDF：$e');
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      await AppPrefs.rememberOutputDir(result);
    }
  }

  void _rotate(int index, bool clockwise) {
    setState(() {
      final item = _items[index];
      item.rotation = (item.rotation + (clockwise ? 1 : 3)) % 4;
    });
  }

  void _remove(int index) => setState(() => _items.removeAt(index));

  Future<void> _export() async {
    if (_pdfFile == null || _items.isEmpty) return;
    setState(() => _isWorking = true);
    try {
      final src = sf.PdfDocument(inputBytes: await _pdfFile!.readAsBytes());
      final bytes = await buildReorganizedPdf(
        src,
        _items.map((e) => e.sourceIndex).toList(),
        _items.map((e) => e.rotation).toList(),
      );
      src.dispose();
      final dir = await resolveOutputDir(preferred: _outputDirectory);
      final base = p.basenameWithoutExtension(_pdfName ?? 'document');
      final outPath = uniquePath(dir, '${base}_编辑', '.pdf');
      await File(outPath).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _isWorking = false);
      showResultDialog(
        context,
        title: '导出完成',
        message: '已按新的顺序与旋转导出 ${_items.length} 页（无损）。\n\n$outPath',
        outputPath: outPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      showErrorDialog(context, '导出失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 页面编辑',
        actions: [
          if (_pdfFile != null) ...[
            ShadButton.ghost(
              onPressed: _pickPdf,
              size: ShadButtonSize.sm,
              leading: const Icon(Icons.swap_horiz_rounded, size: 16),
              child: const Text('重选'),
            ),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isWorking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : ShadButton(
                    onPressed:
                        (_pdfFile != null && _items.isNotEmpty) ? _export : null,
                    leading: const Icon(Icons.save_alt_rounded, size: 18),
                    child: const Text('导出 PDF'),
                  ),
          ),
        ],
      ),
      body: ToolBackground(
        child: _pdfFile == null ? _buildEmpty(theme) : _buildEditor(theme),
      ),
    );
  }

  Widget _buildEmpty(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_stories_rounded,
                size: 72, color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 24),
          Text('编辑 PDF 页面',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 8),
          Text('拖拽调整顺序、旋转或删除页面，无损导出',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
          const SizedBox(height: 32),
          ShadButton(
            onPressed: _pickPdf,
            size: ShadButtonSize.lg,
            leading: const Icon(Icons.folder_open_rounded, size: 20),
            child: const Text('选择 PDF 文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ShadThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            children: [
              Icon(Icons.drag_indicator_rounded,
                  size: 18, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_pdfName ?? ''} · 当前 ${_items.length} 页（拖动排序）',
                  style: TextStyle(
                      fontSize: 13, color: theme.colorScheme.mutedForeground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SettingTileInline(
                directory: _outputDirectory,
                onPick: _pickOutputDirectory,
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text('已删除全部页面，请重选文件',
                      style:
                          TextStyle(color: theme.colorScheme.mutedForeground)))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  itemCount: _items.length,
                  onReorderItem: (old, neo) {
                    setState(() => _items.insert(neo, _items.removeAt(old)));
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _PageRow(
                      key: ValueKey('${item.sourceIndex}_$index'),
                      document: _thumbDoc!,
                      item: item,
                      position: index + 1,
                      index: index,
                      onRotateLeft: () => _rotate(index, false),
                      onRotateRight: () => _rotate(index, true),
                      onRemove: () => _remove(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 顶部行内的输出目录快捷选择。
class SettingTileInline extends StatelessWidget {
  final String? directory;
  final VoidCallback onPick;
  const SettingTileInline(
      {super.key, required this.directory, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadButton.ghost(
      onPressed: onPick,
      size: ShadButtonSize.sm,
      leading: const Icon(Icons.folder_special_rounded, size: 16),
      child: Text(
        directory == null ? '默认下载文件夹' : p.basename(directory!),
        style: TextStyle(color: theme.colorScheme.mutedForeground, fontSize: 12),
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  final pdfx.PdfDocument document;
  final _PageItem item;
  final int position;
  final int index;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onRemove;

  const _PageRow({
    super.key,
    required this.document,
    required this.item,
    required this.position,
    required this.index,
    required this.onRotateLeft,
    required this.onRotateRight,
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 18, color: theme.colorScheme.mutedForeground),
            ),
          ),
          Container(
            width: 56,
            height: 72,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Transform.rotate(
              angle: item.rotation * math.pi / 2,
              child: _PageThumb(
                  document: document, pageNumber: item.sourceIndex + 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('第 $position 页',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '源第 ${item.sourceIndex + 1} 页'
                  '${item.rotation != 0 ? ' · 旋转 ${item.rotation * 90}°' : ''}',
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          ),
          ShadIconButton.ghost(
            onPressed: onRotateLeft,
            icon: Icon(Icons.rotate_left_rounded,
                size: 20, color: theme.colorScheme.mutedForeground),
          ),
          ShadIconButton.ghost(
            onPressed: onRotateRight,
            icon: Icon(Icons.rotate_right_rounded,
                size: 20, color: theme.colorScheme.mutedForeground),
          ),
          ShadIconButton.ghost(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: theme.colorScheme.destructive),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PageThumb extends StatefulWidget {
  final pdfx.PdfDocument document;
  final int pageNumber;
  const _PageThumb({required this.document, required this.pageNumber});

  @override
  State<_PageThumb> createState() => _PageThumbState();
}

class _PageThumbState extends State<_PageThumb> {
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await widget.document.getPage(widget.pageNumber);
      final img = await page.render(
        width: 120,
        height: page.height * 120 / page.width,
        format: pdfx.PdfPageImageFormat.png,
      );
      await page.close();
      if (img != null && mounted) {
        setState(() => _image = MemoryImage(img.bytes));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(
          child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5)));
    }
    return Image(image: _image!, fit: BoxFit.cover);
  }
}
