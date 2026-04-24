import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PdfToImagePage extends StatefulWidget {
  const PdfToImagePage({super.key});

  @override
  State<PdfToImagePage> createState() => _PdfToImagePageState();
}

class _PdfToImagePageState extends State<PdfToImagePage> {
  String? _pdfName;
  pdfx.PdfDocument? _pdfDocument;
  int _pageCount = 0;
  bool _isLoading = false;
  bool _isConverting = false;
  double _conversionProgress = 0;
  String _outputFormat = 'png';
  double _scale = 2.0;
  List<int> _selectedPages = [];
  String? _outputDirectory;

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        await _pdfDocument?.close();
        final doc = await pdfx.PdfDocument.openFile(filePath);
        
        setState(() {
          _pdfName = fileName;
          _pdfDocument = doc;
          _pageCount = doc.pagesCount;
          _selectedPages = List.generate(doc.pagesCount, (i) => i + 1);
        });
      }
    } catch (e) {
      _showError('加载 PDF 失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
    }
  }

  Future<void> _convertToImages() async {
    if (_pdfDocument == null || _selectedPages.isEmpty) return;

    try {
      setState(() {
        _isConverting = true;
        _conversionProgress = 0;
      });

      String outputDir;
      if (_outputDirectory != null) {
        outputDir = _outputDirectory!;
      } else {
        final downloadsDir = await getDownloadsDirectory();
        outputDir = downloadsDir?.path ?? (await getTemporaryDirectory()).path;
      }

      final baseName = _pdfName != null 
          ? path.basenameWithoutExtension(_pdfName!) 
          : 'pdf_export';
      final exportDir = Directory(path.join(outputDir, '${baseName}_images'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final List<String> converted = [];
      
      for (int i = 0; i < _selectedPages.length; i++) {
        final pageNum = _selectedPages[i];
        
        setState(() {
          _conversionProgress = (i + 1) / _selectedPages.length;
        });

        final page = await _pdfDocument!.getPage(pageNum);
        
        final renderWidth = page.width * _scale;
        final renderHeight = page.height * _scale;
        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: pdfx.PdfPageImageFormat.png,
        );
        
        if (pageImage != null) {
          final fileName = '${baseName}_page_$pageNum.$_outputFormat';
          final filePath = path.join(exportDir.path, fileName);
          final file = File(filePath);
          
          await file.writeAsBytes(pageImage.bytes);
          converted.add(filePath);
        }
        
        await page.close();
      }

      setState(() => _isConverting = false);
      _showSuccessDialog(exportDir.path, converted.length);
    } catch (e) {
      setState(() => _isConverting = false);
      _showError('转换失败: $e');
    }
  }

  void _showError(String message) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('错误'),
        description: SelectableText(message),
        actions: [
          ShadButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.of(context).pop();
            },
            child: const Text('复制错误信息'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String dirPath, int count) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('转换完成'),
        description: Text('已成功转换 $count 页图片\n\n保存位置:\n$dirPath'),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _togglePageSelection(int pageNum) {
    setState(() {
      if (_selectedPages.contains(pageNum)) {
        if (_selectedPages.length > 1) {
          _selectedPages.remove(pageNum);
        }
      } else {
        _selectedPages.add(pageNum);
        _selectedPages.sort();
      }
    });
  }

  void _selectAllPages() {
    setState(() {
      _selectedPages = List.generate(_pageCount, (i) => i + 1);
    });
  }

  void _deselectAllPages() {
    setState(() {
      _selectedPages = [];
    });
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
        title: Text(
          'PDF 转图片',
          style: TextStyle(
            color: theme.colorScheme.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_pdfDocument != null && !_isConverting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _convertToImages,
                leading: const Icon(Icons.transform_rounded, size: 18),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isConverting
                ? _buildConvertingView(theme)
                : _pdfDocument == null
                    ? _buildEmptyView(theme)
                    : _buildMainView(theme),
      ),
    );
  }

  Widget _buildEmptyView(ShadThemeData theme) {
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
              Icons.picture_as_pdf_rounded,
              size: 80,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '选择 PDF 文件开始转换',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          ShadButton(
            onPressed: _pickPdfFile,
            size: ShadButtonSize.lg,
            leading: const Icon(Icons.folder_open_rounded, size: 20),
            child: const Text('选取文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildConvertingView(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: _conversionProgress,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.muted,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '${(_conversionProgress * 100).toInt()}%',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            '正在拼力转换中...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '正在处理第 ${(_conversionProgress * _selectedPages.length).ceil()} / ${_selectedPages.length} 页',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView(ShadThemeData theme) {
    return Column(
      children: [
        // 文件信息和设置
        Padding(
          padding: const EdgeInsets.all(24),
          child: ShadCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件名
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.insert_drive_file_rounded, 
                        size: 24, 
                        color: theme.colorScheme.primary
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pdfName ?? '未知文件',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '共 $_pageCount 页',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ShadButton.outline(
                      onPressed: _pickPdfFile,
                      size: ShadButtonSize.sm,
                      leading: const Icon(Icons.swap_horiz_rounded, size: 16),
                      child: const Text('重选'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                
                // 设置选项
                Row(
                  children: [
                    // 输出格式
                    Expanded(
                      child: _buildSettingTile(
                        title: '导出格式',
                        icon: Icons.image_rounded,
                        child: Row(
                          children: [
                            _buildFormatButton('png', 'PNG'),
                            const SizedBox(width: 8),
                            _buildFormatButton('jpg', 'JPEG'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // 缩放比例
                    Expanded(
                      child: _buildSettingTile(
                        title: '渲染质量 (${_scale.toStringAsFixed(1)}x)',
                        icon: Icons.high_quality_rounded,
                        child: ShadSlider(
                          initialValue: _scale,
                          min: 1.0,
                          max: 4.0,
                          divisions: 6,
                          onChanged: (value) => setState(() => _scale = value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 输出目录
                _buildSettingTile(
                  title: '保存位置',
                  icon: Icons.folder_special_rounded,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _outputDirectory ?? '默认下载文件夹',
                          style: TextStyle(
                            fontSize: 14,
                            color: _outputDirectory != null 
                                ? theme.colorScheme.foreground 
                                : theme.colorScheme.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ShadButton.secondary(
                        onPressed: _pickOutputDirectory,
                        size: ShadButtonSize.sm,
                        leading: const Icon(Icons.edit_location_alt_rounded, size: 16),
                        child: const Text('修改'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 页面选择标题
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: Row(
            children: [
              Icon(Icons.checklist_rtl_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '选择页面 (${_selectedPages.length}/$_pageCount)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ShadButton.ghost(
                onPressed: _selectedPages.length == _pageCount 
                    ? _deselectAllPages 
                    : _selectAllPages,
                size: ShadButtonSize.sm,
                child: Text(_selectedPages.length == _pageCount ? '取消全选' : '全选所有'),
              ),
            ],
          ),
        ),
        
        // 页面网格
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 0) return const SizedBox.shrink();
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: _pageCount,
                itemBuilder: (context, index) {
                  final pageNum = index + 1;
                  return _PageThumbnail(
                    document: _pdfDocument!,
                    pageNumber: pageNum,
                    isSelected: _selectedPages.contains(pageNum),
                    onTap: () => _togglePageSelection(pageNum),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormatButton(String format, String label) {
    final isSelected = _outputFormat == format;
    final theme = ShadTheme.of(context);
    return Expanded(
      child: ShadButton(
        onPressed: () => setState(() => _outputFormat = format),
        size: ShadButtonSize.sm,
        backgroundColor: isSelected 
            ? theme.colorScheme.primary 
            : theme.colorScheme.muted.withValues(alpha: 0.5),
        foregroundColor: isSelected 
            ? theme.colorScheme.primaryForeground 
            : theme.colorScheme.foreground,
        child: Text(label),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PageThumbnail extends StatefulWidget {
  final pdfx.PdfDocument document;
  final int pageNumber;
  final bool isSelected;
  final VoidCallback onTap;

  const _PageThumbnail({
    required this.document,
    required this.pageNumber,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PageThumbnail> createState() => _PageThumbnailState();
}

class _PageThumbnailState extends State<_PageThumbnail> {
  ImageProvider? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final page = await widget.document.getPage(widget.pageNumber);
      final thumbWidth = 200.0;
      final thumbHeight = page.height * 200.0 / page.width;
      final pageImage = await page.render(
        width: thumbWidth,
        height: thumbHeight,
        format: pdfx.PdfPageImageFormat.png,
      );
      
      if (pageImage != null && mounted) {
        setState(() {
          _imageProvider = MemoryImage(pageImage.bytes);
          _isLoading = false;
        });
      }
      await page.close();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: widget.isSelected ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _imageProvider != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image(image: _imageProvider!, fit: BoxFit.contain),
                        )
                      : const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
            
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.pageNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            if (widget.isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
