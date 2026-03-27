import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'router/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.router(
      title: 'SDM 工具箱',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadColorScheme(
          background: Colors.white,
          foreground: Color(0xFF09090B),
          card: Colors.white,
          cardForeground: Color(0xFF09090B),
          popover: Colors.white,
          popoverForeground: Color(0xFF09090B),
          primary: Color(0xFF18181B),
          primaryForeground: Colors.white,
          secondary: Color(0xFFF4F4F5),
          secondaryForeground: Color(0xFF18181B),
          muted: Color(0xFFF4F4F5),
          mutedForeground: Color(0xFF71717A),
          accent: Color(0xFFF4F4F5),
          accentForeground: Color(0xFF18181B),
          destructive: Color(0xFFEF4444),
          destructiveForeground: Colors.white,
          border: Color(0xFFE4E4E7),
          input: Color(0xFFE4E4E7),
          ring: Color(0xFF18181B),
          selection: Color(0xFF18181B),
        ),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadColorScheme(
          background: Color(0xFF09090B),
          foreground: Color(0xFFFAFAFA),
          card: Color(0xFF18181B),
          cardForeground: Color(0xFFFAFAFA),
          popover: Color(0xFF18181B),
          popoverForeground: Color(0xFFFAFAFA),
          primary: Color(0xFFFAFAFA),
          primaryForeground: Color(0xFF18181B),
          secondary: Color(0xFF27272A),
          secondaryForeground: Color(0xFFFAFAFA),
          muted: Color(0xFF27272A),
          mutedForeground: Color(0xFFA1A1AA),
          accent: Color(0xFF27272A),
          accentForeground: Color(0xFFFAFAFA),
          destructive: Color(0xFF7F1D1D),
          destructiveForeground: Color(0xFFFAFAFA),
          border: Color(0xFF27272A),
          input: Color(0xFF27272A),
          ring: Color(0xFFD4D4D8),
          selection: Color(0xFFD4D4D8),
        ),
      ),
    );
  }
}
