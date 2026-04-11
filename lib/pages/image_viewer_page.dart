import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:path/path.dart' as p;

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  List<File> _images = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = false;
  String? _currentFolder;

  static const _supportedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'tiff', 'tif',
  ];

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    setState(() {
      _isLoading = true;
      _currentFolder = path;
      _selectedIndices.clear();
    });
    try {
      final dir = Directory(path);
      final all = await dir.list(recursive: false).toList();
      final files = all
          .whereType<File>()
          .where((f) {
            final ext = p.extension(f.path).toLowerCase().replaceFirst('.', '');
            return _supportedExtensions.contains(ext);
          })
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      setState(() => _images = files);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      _images = result.files.map((f) => File(f.path!)).toList();
      _selectedIndices.clear();
      _currentFolder = null;
    });
  }

  void _openViewer(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullScreenViewer(images: _images, initialIndex: index),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _images.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices
          ..clear()
          ..addAll(List.generate(_images.length, (i) => i));
      }
    });
  }

  void _printSelected() {
    final selected = _selectedIndices.toList()..sort();
    final files = selected.map((i) => _images[i]).toList();
    context.pushNamed('batchPrint', extra: files);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final allSelected =
        _images.isNotEmpty && _selectedIndices.length == _images.length;

    return Scaffold(
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('图片浏览'),
            if (_currentFolder != null)
              Text(
                _currentFolder!,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_images.isNotEmpty) ...[
            Text(
              '${_images.length} 张',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            ShadButton.ghost(
              onPressed: _toggleSelectAll,
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
            const SizedBox(width: 4),
            ShadButton(
              onPressed: _selectedIndices.isNotEmpty ? _printSelected : null,
              leading: const Icon(Icons.print, size: 16),
              child: Text('打印选中 (${_selectedIndices.length})'),
            ),
            const SizedBox(width: 8),
          ],
          ShadButton.outline(
            onPressed: _pickFolder,
            leading: const Icon(Icons.folder_open, size: 16),
            child: const Text('选择文件夹'),
          ),
          const SizedBox(width: 8),
          ShadButton.ghost(
            onPressed: _pickImages,
            leading: const Icon(Icons.add_photo_alternate, size: 16),
            child: const Text('添加图片'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
              ? _buildEmpty(theme)
              : _buildGrid(theme),
    );
  }

  Widget _buildEmpty(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '选择文件夹或图片开始浏览',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton(
                onPressed: _pickFolder,
                leading: const Icon(Icons.folder_open, size: 16),
                child: const Text('选择文件夹'),
              ),
              const SizedBox(width: 12),
              ShadButton.outline(
                onPressed: _pickImages,
                leading: const Icon(Icons.add_photo_alternate, size: 16),
                child: const Text('选择图片'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ShadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          return _ImageTile(
            file: _images[index],
            index: index,
            isSelected: _selectedIndices.contains(index),
            onTap: () => _openViewer(index),
            onSelectionToggle: () => _toggleSelection(index),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Thumbnail tile
// ──────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  final File file;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSelectionToggle;

  const _ImageTile({
    required this.file,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.muted,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.mutedForeground,
                    size: 32,
                  ),
                ),
              ),

              // Bottom gradient + filename
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                  child: Text(
                    p.basename(file.path),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Selection checkbox
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelectionToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.black.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Full-screen viewer dialog
// ──────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const _FullScreenViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late int _index;
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.images[_index];

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) _go(-1);
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) _go(1);
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 860),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header bar
              _buildHeader(file),
              // Image viewer
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8.0,
                    child: Image.file(
                      widget.images[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Navigation bar
              _buildNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(File file) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.basename(file.path),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_index + 1} / ${widget.images.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'ESC 关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _index > 0 ? () => _go(-1) : null,
            icon: Icon(
              Icons.chevron_left,
              color: _index > 0 ? Colors.white : Colors.white24,
              size: 36,
            ),
            tooltip: '上一张 ←',
          ),
          const SizedBox(width: 32),
          IconButton(
            onPressed: _index < widget.images.length - 1 ? () => _go(1) : null,
            icon: Icon(
              Icons.chevron_right,
              color: _index < widget.images.length - 1
                  ? Colors.white
                  : Colors.white24,
              size: 36,
            ),
            tooltip: '下一张 →',
          ),
        ],
      ),
    );
  }
}
