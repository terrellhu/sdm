import 'dart:io';
import 'package:flutter/material.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量的本地偏好存储：记住上次输出目录与主题模式。
/// 在 macOS 沙盒下通过安全书签持久化对输出目录的访问权限。
class AppPrefs {
  static SharedPreferences? _p;

  /// 主题模式，可监听以驱动全局重建。
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  static final SecureBookmarks _bookmarks = SecureBookmarks();
  static FileSystemEntity? _accessed; // 当前正在访问的安全资源

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    switch (_p?.getString('themeMode')) {
      case 'light':
        themeMode.value = ThemeMode.light;
      case 'dark':
        themeMode.value = ThemeMode.dark;
      default:
        themeMode.value = ThemeMode.system;
    }
    if (Platform.isMacOS) {
      final bm = _p?.getString('outputDirBookmark');
      if (bm != null && bm.isNotEmpty) await _startAccess(bm);
    }
  }

  /// 上次使用的输出目录（为空返回 null）。
  static String? get outputDir {
    final v = _p?.getString('outputDir');
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 记住输出目录。macOS 会创建安全书签并立即开始访问，
  /// 以便下次启动后仍可写入该目录（沙盒要求）。
  static Future<void> rememberOutputDir(String path) async {
    await _p?.setString('outputDir', path);
    if (Platform.isMacOS) {
      try {
        final bookmark = await _bookmarks.bookmark(Directory(path));
        await _p?.setString('outputDirBookmark', bookmark);
        await _startAccess(bookmark);
      } catch (_) {}
    }
  }

  static Future<void> _startAccess(String bookmark) async {
    try {
      final resolved = await _bookmarks.resolveBookmark(bookmark);
      if (_accessed != null) {
        try {
          await _bookmarks.stopAccessingSecurityScopedResource(_accessed!);
        } catch (_) {}
      }
      await _bookmarks.startAccessingSecurityScopedResource(resolved);
      _accessed = resolved;
    } catch (_) {}
  }

  static void setThemeMode(ThemeMode m) {
    themeMode.value = m;
    _p?.setString('themeMode', m.name);
  }

  /// 在 系统 → 亮 → 暗 之间循环切换。
  static void cycleThemeMode() {
    final next = switch (themeMode.value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setThemeMode(next);
  }
}
