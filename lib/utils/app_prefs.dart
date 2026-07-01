import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量的本地偏好存储：记住上次输出目录与主题模式。
class AppPrefs {
  static SharedPreferences? _p;

  /// 主题模式，可监听以驱动全局重建。
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

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
  }

  /// 上次使用的输出目录（为空返回 null）。
  static String? get outputDir {
    final v = _p?.getString('outputDir');
    return (v == null || v.isEmpty) ? null : v;
  }

  static set outputDir(String? v) {
    if (v != null && v.isNotEmpty) _p?.setString('outputDir', v);
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
