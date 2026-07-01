import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_prefs.dart';

/// 统一解析输出目录：优先使用用户选择的目录，其次上次记住的目录，
/// 再回退到系统下载目录、临时目录；可选在其下创建子文件夹。
/// 返回前确保目录已存在。
Future<String> resolveOutputDir({String? preferred, String? subfolder}) async {
  String base;
  final remembered = preferred ?? AppPrefs.outputDir;
  if (remembered != null && remembered.isNotEmpty) {
    base = remembered;
  } else {
    final downloads = await getDownloadsDirectory();
    base = downloads?.path ?? (await getTemporaryDirectory()).path;
    if (subfolder != null && subfolder.isNotEmpty) {
      base = p.join(base, subfolder);
    }
  }
  await Directory(base).create(recursive: true);
  return base;
}

/// 在系统文件管理器中定位并高亮某个文件（或打开某个目录）。
Future<void> revealInFileManager(String path) async {
  try {
    final type = FileSystemEntity.typeSync(path);
    final isFile = type == FileSystemEntityType.file;
    if (Platform.isWindows) {
      if (isFile) {
        // explorer /select, 正常成功也会返回非零退出码，忽略即可。
        await Process.run('explorer.exe', ['/select,', path]);
      } else {
        await Process.run('explorer.exe', [path]);
      }
    } else if (Platform.isMacOS) {
      await Process.run('open', isFile ? ['-R', path] : [path]);
    } else {
      final dir = isFile ? p.dirname(path) : path;
      await Process.run('xdg-open', [dir]);
    }
  } catch (_) {}
}

/// 用系统默认程序打开文件或目录。
Future<void> openPath(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  } catch (_) {}
}

/// 若目标文件已存在，自动追加 (1)、(2)… 以避免覆盖。
String uniquePath(String dir, String baseName, String ext) {
  var candidate = p.join(dir, '$baseName$ext');
  var i = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$baseName($i)$ext');
    i++;
  }
  return candidate;
}

/// 人类可读的体积格式化。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}
