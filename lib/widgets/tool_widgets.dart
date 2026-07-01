import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 各工具页统一的顶部导航栏（返回首页 + 标题 + 右侧操作）。
AppBar toolAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
}) {
  final theme = ShadTheme.of(context);
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: ShadIconButton.ghost(
      onPressed: () => context.go('/'),
      icon: Icon(Icons.arrow_back_ios_new,
          size: 20, color: theme.colorScheme.foreground),
    ),
    title: Text(
      title,
      style: TextStyle(
        color: theme.colorScheme.foreground,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    actions: actions,
  );
}

/// 页面渐变背景容器。
class ToolBackground extends StatelessWidget {
  final Widget child;
  const ToolBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
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
      child: child,
    );
  }
}

/// 小节标题（图标 + 文字）。
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const SectionHeader(this.title, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 带标签的设置项容器。
class SettingTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const SettingTile(
      {super.key,
      required this.title,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.mutedForeground)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// 可点击的胶囊选项。
class ToolChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const ToolChip(
      {super.key,
      required this.label,
      this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? theme.colorScheme.primaryForeground
                      : theme.colorScheme.foreground),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.foreground)),
          ],
        ),
      ),
    );
  }
}

/// 摘要信息行。
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 10),
        Text(label,
            style:
                TextStyle(color: theme.colorScheme.mutedForeground, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// 输出目录选择行。
class OutputDirRow extends StatelessWidget {
  final String? directory;
  final String placeholder;
  final VoidCallback onPick;
  const OutputDirRow({
    super.key,
    required this.directory,
    required this.onPick,
    this.placeholder = '默认下载文件夹',
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            directory ?? placeholder,
            style: TextStyle(
              fontSize: 13,
              color: directory != null
                  ? theme.colorScheme.foreground
                  : theme.colorScheme.mutedForeground,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        ShadButton.secondary(
          onPressed: onPick,
          size: ShadButtonSize.sm,
          leading: const Icon(Icons.edit_location_alt_rounded, size: 16),
          child: const Text('更改'),
        ),
      ],
    );
  }
}
