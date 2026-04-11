import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/tool_item.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  List<ToolItem> get _tools => [
        ToolItem(
          id: 'pdf_to_image',
          name: 'PDF转图片',
          description: '将PDF文件转换为PNG或JPEG图片',
          icon: Icons.picture_as_pdf,
          color: Colors.red,
          routeName: 'pdfToImage',
        ),
        ToolItem(
          id: 'image_viewer',
          name: '图片浏览',
          description: '浏览文件夹图片，支持全屏预览和多选',
          icon: Icons.photo_library,
          color: Colors.blue,
          routeName: 'imageViewer',
        ),
        ToolItem(
          id: 'batch_print',
          name: '批量打印',
          description: '批量打印多张图片，自定义每页布局',
          icon: Icons.print,
          color: Colors.green,
          routeName: 'batchPrint',
        ),
        ToolItem(
          id: 'pdf_merge',
          name: 'PDF 合并',
          description: '将多个 PDF 文件合并为一个',
          icon: Icons.merge,
          color: Colors.orange,
          routeName: 'pdfMerge',
        ),
        ToolItem(
          id: 'image_to_pdf',
          name: '图片转 PDF',
          description: '将多张图片打包导出为 PDF 文件',
          icon: Icons.image_outlined,
          color: Colors.purple,
          routeName: 'imageToPdf',
        ),
        ToolItem(
          id: 'pdf_watermark',
          name: 'PDF 加水印',
          description: '为 PDF 每页添加自定义文字水印',
          icon: Icons.water_drop_outlined,
          color: Colors.teal,
          routeName: 'pdfWatermark',
        ),
        ToolItem(
          id: 'image_compress',
          name: '图片压缩',
          description: '批量压缩图片体积，支持多种格式',
          icon: Icons.compress,
          color: Colors.indigo,
          routeName: 'imageCompress',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 标题栏
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'SDM 工具箱',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.foreground,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                      theme.colorScheme.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 工具网格
          SliverLayoutBuilder(
            builder: (context, constraints) {
              if (constraints.crossAxisExtent <= 0) {
                return const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final horizontalPadding = constraints.crossAxisExtent > 40 ? 20.0 : 0.0;
              return SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tool = _tools[index];
                      return _ToolCard(tool: tool);
                    },
                    childCount: _tools.length,
                  ),
                ),
              );
            },
          ),
          
          // 底部说明
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '更多工具即将上线...',
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolItem tool;

  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.goNamed(tool.routeName),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tool.icon,
                size: 28,
                color: tool.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tool.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              tool.description,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
