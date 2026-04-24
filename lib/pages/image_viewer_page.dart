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
      barrierColor: Colors.black.withValues(alpha: 0.9),
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
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ShadIconButton.ghost(
          onPressed: () => context.go('/'),
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: theme.colorScheme.foreground),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '图片浏览',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_currentFolder != null)
              Text(
                _currentFolder!,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_images.isNotEmpty) ...[
            Center(
              child: ShadBadge.secondary(
                child: Text('${_images.length} 张', style: const TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 12),
            ShadButton.ghost(
              onPressed: _toggleSelectAll,
              size: ShadButtonSize.sm,
              child: Text(allSelected ? '取消全选' : '全选所有'),
            ),
            const SizedBox(width: 8),
            ShadButton(
              onPressed: _selectedIndices.isNotEmpty ? _printSelected : null,
              size: ShadButtonSize.sm,
              leading: const Icon(Icons.print_rounded, size: 16),
              child: Text('打印选中 (${_selectedIndices.length})'),
            ),
            const SizedBox(width: 12),
          ],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _images.isEmpty
                ? _buildEmpty(theme)
                : _buildGrid(theme),
      ),
      floatingActionButton: _images.isEmpty ? null : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_img',
            onPressed: _pickImages,
            child: const Icon(Icons.add_photo_alternate_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'pick_folder',
            onPressed: _pickFolder,
            child: const Icon(Icons.folder_copy_rounded),
          ),
        ],
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
            child: Icon(
              Icons.photo_library_rounded,
              size: 72,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '开启您的图片探索之旅',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选择文件夹或直接添加单张图片',
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton(
                onPressed: _pickFolder,
                size: ShadButtonSize.lg,
                leading: const Icon(Icons.folder_open_rounded, size: 20),
                child: const Text('选择文件夹'),
              ),
              const SizedBox(width: 16),
              ShadButton.outline(
                onPressed: _pickImages,
                size: ShadButtonSize.lg,
                leading: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                child: const Text('直接添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ShadThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
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
    );
  }
}

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
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? theme.colorScheme.primary.withValues(alpha: 0.2) 
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.muted,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: theme.colorScheme.mutedForeground,
                    size: 32,
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    p.basename(file.path),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onSelectionToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.black.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4)
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuart,
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
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 主展示区
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Hero(
                    tag: 'img_$i',
                    child: Image.file(
                      widget.images[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white24,
                        size: 80,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 顶部栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(file.path),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_index + 1} / ${widget.images.length}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // 平衡返回键
                  ],
                ),
              ),
            ),

            // 左右导航按钮 (仅在大屏幕或特定交互下显示，此处始终提供以方便演示)
            if (_index > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filled(
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 32),
                    style: IconButton.styleFrom(backgroundColor: Colors.white12),
                  ),
                ),
              ),
            if (_index < widget.images.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filled(
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 32),
                    style: IconButton.styleFrom(backgroundColor: Colors.white12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
