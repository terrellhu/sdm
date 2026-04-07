import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_render/pdf_render.dart';
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
  PdfDocument? _pdfDocument;
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
    _pdfDocument?.dispose();
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
        
        await _pdfDocument?.dispose();
        final doc = await PdfDocument.openFile(filePath);
        
        setState(() {
          _pdfName = fileName;
          _pdfDocument = doc;
          _pageCount = doc.pageCount;
          _selectedPages = List.generate(doc.pageCount, (i) => i + 1);
        });
      }
    } catch (e) {
      _showError('加载PDF失败: $e');
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

      // 确定输出目录
      String outputDir;
      if (_outputDirectory != null) {
        outputDir = _outputDirectory!;
      } else {
        final downloadsDir = await getDownloadsDirectory();
        outputDir = downloadsDir?.path ?? (await getTemporaryDirectory()).path;
      }

      // 创建以PDF文件名命名的子文件夹
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
        
        // 更新进度
        setState(() {
          _conversionProgress = (i + 1) / _selectedPages.length;
        });

        // 获取页面
        final page = await _pdfDocument!.getPage(pageNum);
        
        // 渲染为图片
        final renderWidth = (page.width * _scale).toInt();
        final renderHeight = (page.height * _scale).toInt();
        final img = await page.render(
          width: renderWidth,
          height: renderHeight,
          fullWidth: renderWidth.toDouble(),
          fullHeight: renderHeight.toDouble(),
        );
        
        // 获取图片数据
        final imgData = await img.createImageIfNotAvailable();
        final byteData = await imgData.toByteData(format: ImageByteFormat.png);
        
        if (byteData != null) {
          // 保存文件
          final fileName = '${baseName}_page_$pageNum.$_outputFormat';
          final filePath = path.join(exportDir.path, fileName);
          final file = File(filePath);
          
          await file.writeAsBytes(byteData.buffer.asUint8List());
          converted.add(filePath);
        }
      }

      setState(() => _isConverting = false);

      // 显示成功对话框
      _showSuccessDialog(exportDir.path, converted.length);
    } catch (e) {
      setState(() => _isConverting = false);
      _showError('转换失败: $e');
    }
  }

  void _showError(String message) {
    ShadToaster.of(context).show(
      ShadToast(
        title: const Text('错误'),
        description: Text(message),
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
      appBar: AppBar(
        leading: ShadIconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('PDF转图片'),
        actions: [
          if (_pdfDocument != null && !_isConverting)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShadButton(
                onPressed: _convertToImages,
                leading: const Icon(Icons.transform, size: 16),
                child: const Text('开始转换'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isConverting
              ? _buildConvertingView(theme)
              : _pdfDocument == null
                  ? _buildEmptyView(theme)
                  : _buildMainView(theme),
    );
  }

  Widget _buildEmptyView(ShadThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '选择PDF文件开始转换',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          ShadButton(
            onPressed: _pickPdfFile,
            leading: const Icon(Icons.folder_open, size: 16),
            child: const Text('选择文件'),
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
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: _conversionProgress,
              strokeWidth: 8,
              backgroundColor: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '正在转换... ${(_conversionProgress * 100).toInt()}%',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
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
          padding: const EdgeInsets.all(16),
          child: ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件名
                Row(
                  children: [
                    Icon(Icons.insert_drive_file, 
                      size: 20, 
                      color: theme.colorScheme.mutedForeground
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pdfName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ShadButton.ghost(
                      onPressed: _pickPdfFile,
                      leading: const Icon(Icons.swap_horiz, size: 16),
                      child: const Text('更换'),
                    ),
                  ],
                ),
                const Divider(),
                
                // 设置选项
                Row(
                  children: [
                    // 输出格式
                    Expanded(
                      child: _buildSettingTile(
                        title: '输出格式',
                        child: Row(
                          children: [
                            _buildFormatButton('png', 'PNG'),
                            const SizedBox(width: 8),
                            _buildFormatButton('jpg', 'JPEG'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // 缩放比例
                    Expanded(
                      child: _buildSettingTile(
                        title: '图片质量 (${_scale.toStringAsFixed(1)}x)',
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
                const SizedBox(height: 16),
                
                // 输出目录
                _buildSettingTile(
                  title: '输出目录',
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
                      ShadButton.secondary(
                        onPressed: _pickOutputDirectory,
                        leading: const Icon(Icons.folder, size: 16),
                        child: const Text('选择'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 页面选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择页面 (${_selectedPages.length}/$_pageCount)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ShadButton.ghost(
                onPressed: _selectedPages.length == _pageCount 
                    ? _deselectAllPages 
                    : _selectAllPages,
                child: Text(_selectedPages.length == _pageCount ? '取消全选' : '全选'),
              ),
            ],
          ),
        ),
        
        // 页面网格
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 0) {
                return const Center(child: CircularProgressIndicator());
              }
              final horizontalPadding = constraints.maxWidth > 32 ? 16.0 : 0.0;
              return GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: _pageCount,
                itemBuilder: (context, index) {
                  final pageNum = index + 1;
                  final isSelected = _selectedPages.contains(pageNum);
                  
                  return _PageThumbnail(
                    document: _pdfDocument!,
                    pageNumber: pageNum,
                    isSelected: isSelected,
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
    return ShadButton(
      onPressed: () => setState(() => _outputFormat = format),
      backgroundColor: isSelected 
          ? ShadTheme.of(context).colorScheme.primary 
          : ShadTheme.of(context).colorScheme.secondary,
      foregroundColor: isSelected 
          ? ShadTheme.of(context).colorScheme.primaryForeground 
          : ShadTheme.of(context).colorScheme.secondaryForeground,
      child: Text(label),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: ShadTheme.of(context).colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PageThumbnail extends StatefulWidget {
  final PdfDocument document;
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
      final thumbWidth = 150;
      final thumbHeight = (page.height * 150 / page.width).toInt();
      final img = await page.render(
        width: thumbWidth,
        height: thumbHeight,
        fullWidth: thumbWidth.toDouble(),
        fullHeight: thumbHeight.toDouble(),
      );
      final imgData = await img.createImageIfNotAvailable();
      final byteData = await imgData.toByteData(format: ImageByteFormat.png);
      
      if (byteData != null && mounted) {
        setState(() {
          _imageProvider = MemoryImage(
            Uint8List.view(byteData.buffer),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: ShadCard(
        padding: const EdgeInsets.all(8),
        backgroundColor: widget.isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图
            Padding(
              padding: const EdgeInsets.all(4),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _imageProvider != null
                      ? Image(image: _imageProvider!, fit: BoxFit.contain)
                      : const Icon(Icons.broken_image),
            ),
            
            // 页码
            Positioned(
              bottom: 4,
              left: 4,
              child: ShadBadge.secondary(
                child: Text('${widget.pageNumber}'),
              ),
            ),
            
            // 选中标记
            if (widget.isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
