import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/tool_item.dart';
import '../utils/app_prefs.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  List<ToolItem> get _tools => [
        ToolItem(
          id: 'pdf_to_image',
          name: 'PDF 转图片',
          description: '高质量转换为 PNG/JPEG',
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFEF4444),
          routeName: 'pdfToImage',
        ),
        ToolItem(
          id: 'image_viewer',
          name: '图片浏览',
          description: '文件夹快速预览与管理',
          icon: Icons.photo_library_rounded,
          color: const Color(0xFF3B82F6),
          routeName: 'imageViewer',
        ),
        ToolItem(
          id: 'batch_print',
          name: '批量打印',
          description: '多图拼版排版打印',
          icon: Icons.print_rounded,
          color: const Color(0xFF10B981),
          routeName: 'batchPrint',
        ),
        ToolItem(
          id: 'pdf_merge',
          name: 'PDF 合并',
          description: '多文档一键无损合并',
          icon: Icons.merge_type_rounded,
          color: const Color(0xFFF59E0B),
          routeName: 'pdfMerge',
        ),
        ToolItem(
          id: 'image_to_pdf',
          name: '图片转 PDF',
          description: '图片快速打包成文档',
          icon: Icons.insert_page_break_rounded,
          color: const Color(0xFF8B5CF6),
          routeName: 'imageToPdf',
        ),
        ToolItem(
          id: 'pdf_watermark',
          name: 'PDF 加水印',
          description: '自定义文字安全防盗',
          icon: Icons.verified_user_rounded,
          color: const Color(0xFF06B6D4),
          routeName: 'pdfWatermark',
        ),
        ToolItem(
          id: 'image_compress',
          name: '图片压缩',
          description: '智能压缩保持清晰度',
          icon: Icons.shutter_speed_rounded,
          color: const Color(0xFF6366F1),
          routeName: 'imageCompress',
        ),
        ToolItem(
          id: 'pdf_split',
          name: 'PDF 拆分',
          description: '提取页面或按份拆分',
          icon: Icons.content_cut_rounded,
          color: const Color(0xFFEC4899),
          routeName: 'pdfSplit',
        ),
        ToolItem(
          id: 'pdf_encrypt',
          name: 'PDF 加密',
          description: 'AES 密码保护与解密',
          icon: Icons.lock_rounded,
          color: const Color(0xFF14B8A6),
          routeName: 'pdfEncrypt',
        ),
        ToolItem(
          id: 'image_convert',
          name: '格式转换',
          description: 'JPG/PNG/BMP 批量互转',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFFF97316),
          routeName: 'imageConvert',
        ),
        ToolItem(
          id: 'pdf_extract_text',
          name: 'PDF 转文字',
          description: '提取文本并导出 TXT',
          icon: Icons.text_snippet_rounded,
          color: const Color(0xFF64748B),
          routeName: 'pdfExtractText',
        ),
        ToolItem(
          id: 'image_watermark',
          name: '图片水印',
          description: '批量文字水印防盗图',
          icon: Icons.branding_watermark_rounded,
          color: const Color(0xFFA855F7),
          routeName: 'imageWatermark',
        ),
        ToolItem(
          id: 'pdf_organize',
          name: 'PDF 页面编辑',
          description: '排序·旋转·删除页面',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF0EA5E9),
          routeName: 'pdfOrganize',
        ),
        ToolItem(
          id: 'ocr',
          name: 'OCR 文字识别',
          description: '扫描件转文本/可搜索PDF',
          icon: Icons.document_scanner_rounded,
          color: const Color(0xFFD946EF),
          routeName: 'ocr',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 精致标题栏 ──────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            collapsedHeight: 80,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.colorScheme.background,
            actions: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppPrefs.themeMode,
                builder: (context, mode, _) {
                  final icon = switch (mode) {
                    ThemeMode.light => Icons.light_mode_rounded,
                    ThemeMode.dark => Icons.dark_mode_rounded,
                    ThemeMode.system => Icons.brightness_auto_rounded,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ShadIconButton.ghost(
                      onPressed: AppPrefs.cycleThemeMode,
                      icon: Icon(icon,
                          size: 20, color: theme.colorScheme.foreground),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                'SDM 工具箱',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: theme.colorScheme.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                          theme.colorScheme.primary.withValues(alpha: 0.02),
                          theme.colorScheme.background,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.blur_on_rounded,
                      size: 200,
                      color: theme.colorScheme.primary.withValues(alpha: 0.03),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── 工具网格 ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ToolCard(tool: _tools[index]),
                childCount: _tools.length,
              ),
            ),
          ),
          
          // ── 底部说明 ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '更多创意工具正在研发中',
                        style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.goNamed(tool.routeName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 强制宽度撑满，消除任何潜在的横向空隙
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.card,
                tool.color.withValues(alpha: 0.05),
                tool.color.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: tool.color.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  tool.icon,
                  size: 32,
                  color: tool.color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tool.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tool.description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.mutedForeground,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
