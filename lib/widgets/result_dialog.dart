import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../utils/file_utils.dart';

/// 统一的成功结果弹窗：带「打开文件夹」「打开文件」快捷操作。
/// [outputPath] 为生成的文件或目录路径；[isFile] 为 true 时额外提供「打开文件」。
void showResultDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? outputPath,
  bool isFile = true,
}) {
  showShadDialog(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text(title),
      description: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        if (outputPath != null)
          ShadButton.outline(
            onPressed: () => revealInFileManager(outputPath),
            leading: const Icon(Icons.folder_open_rounded, size: 16),
            child: const Text('打开文件夹'),
          ),
        if (outputPath != null && isFile)
          ShadButton.secondary(
            onPressed: () => openPath(outputPath),
            leading: const Icon(Icons.open_in_new_rounded, size: 16),
            child: const Text('打开文件'),
          ),
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('完成'),
        ),
      ],
    ),
  );
}

/// 统一的错误弹窗，可复制错误信息。
void showErrorDialog(BuildContext context, String message) {
  showShadDialog(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: const Text('出错了'),
      description: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText(message),
      ),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
