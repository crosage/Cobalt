import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const PaperReaderApp());
}

class PaperReaderApp extends StatelessWidget {
  const PaperReaderApp({super.key});

  // ── 手调配色：暖纸色底 + 靛蓝主色 ──
  // 灵感：Notion / Readwise / 纸质书
  static const _seed = Color(0xFF4A6FA5); // 沉稳靛蓝

  static final _lightScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  ).copyWith(
    // 背景: 微暖的纸色，不是纯白
    surface: const Color(0xFFF9F7F4),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFF5F3F0),
    surfaceContainer: const Color(0xFFEFEDE9),
    surfaceContainerHigh: const Color(0xFFE9E7E3),
    surfaceContainerHighest: const Color(0xFFE3E1DD),
    // 主色: 靛蓝，不刺眼
    primary: const Color(0xFF4A6FA5),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD6E3F8),
    onPrimaryContainer: const Color(0xFF1A3A5C),
    // 辅色: 暖棕，用于笔记/次要信息
    secondary: const Color(0xFF7C6F64),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF0E8DF),
    onSecondaryContainer: const Color(0xFF3B3128),
    // 第三色: 柔绿，用于状态/成功
    tertiary: const Color(0xFF5B8A72),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFD5F0E3),
    onTertiaryContainer: const Color(0xFF1E3A2C),
    // 轮廓
    outline: const Color(0xFF9E9A94),
    outlineVariant: const Color(0xFFD5D2CD),
    // 错误
    error: const Color(0xFFBA4A4A),
    onError: Colors.white,
  );

  static final _darkScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1C1B19),
    surfaceContainerLowest: const Color(0xFF141312),
    surfaceContainerLow: const Color(0xFF222120),
    surfaceContainer: const Color(0xFF2A2928),
    surfaceContainerHigh: const Color(0xFF333231),
    surfaceContainerHighest: const Color(0xFF3D3C3A),
    primary: const Color(0xFF9DB8DB),
    onPrimary: const Color(0xFF1A3A5C),
    primaryContainer: const Color(0xFF2E4F7A),
    onPrimaryContainer: const Color(0xFFD6E3F8),
    secondary: const Color(0xFFCFC1B4),
    onSecondary: const Color(0xFF3B3128),
    secondaryContainer: const Color(0xFF4A4039),
    onSecondaryContainer: const Color(0xFFF0E8DF),
    tertiary: const Color(0xFFA3CEBC),
    onTertiary: const Color(0xFF1E3A2C),
    tertiaryContainer: const Color(0xFF345C49),
    onTertiaryContainer: const Color(0xFFD5F0E3),
    outline: const Color(0xFF8A8780),
    outlineVariant: const Color(0xFF4A4845),
    error: const Color(0xFFE8A0A0),
    onError: const Color(0xFF3C1111),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper Reader',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(_lightScheme, Brightness.light),
      darkTheme: _buildTheme(_darkScheme, Brightness.dark),
      home: const HomePage(),
    );
  }

  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: brightness,

      // 字体: 系统默认，不依赖网络
      fontFamily: null, // 系统字体

      scaffoldBackgroundColor: cs.surface,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),

      cardTheme: CardTheme(
        elevation: 0,
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: cs.outline.withOpacity(0.5)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.primary, size: 24);
          }
          return IconThemeData(color: cs.outline, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            );
          }
          return TextStyle(fontSize: 12, color: cs.outline);
        }),
      ),

      tabBarTheme: TabBarTheme(
        indicatorSize: TabBarIndicatorSize.label,
        dividerHeight: 0,
        labelColor: cs.primary,
        unselectedLabelColor: cs.outline,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant.withOpacity(0.3)),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
