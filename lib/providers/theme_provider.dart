import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

/// 个性化设置状态管理 + 持久化
class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(const AppTheme()) {
    _load();
  }

  static const _prefsKey = 'app_theme_v1';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      if (raw != null) {
        state = AppTheme.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> setScheme(String id) async {
    state = state.copyWith(schemeId: id);
    await _save();
  }

  Future<void> setBackgroundType(AppBackgroundType type) async {
    state = state.copyWith(backgroundType: type);
    await _save();
  }

  Future<void> setBackgroundAsset(String? asset) async {
    state = state.copyWith(
      backgroundAsset: asset,
      backgroundType: asset == null
          ? AppBackgroundType.solid
          : AppBackgroundType.asset,
    );
    await _save();
  }

  Future<void> setBackgroundPath(String? path) async {
    state = state.copyWith(
      backgroundPath: path,
      backgroundType: path == null
          ? AppBackgroundType.solid
          : AppBackgroundType.custom,
    );
    await _save();
  }

  Future<void> setBackgroundBlur(double v) async {
    state = state.copyWith(backgroundBlur: v);
    await _save();
  }

  Future<void> setDarkText(bool v) async {
    state = state.copyWith(darkText: v);
    await _save();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>(
  (ref) => ThemeNotifier(),
);

/// 由 AppTheme 生成 Material 3 ColorScheme
ColorScheme buildColorScheme(AppTheme theme, Brightness brightness) {
  final scheme = theme.scheme;
  return ColorScheme.fromSeed(
    seedColor: scheme.primary,
    brightness: brightness,
    surface: scheme.surface,
  );
}

/// 生成 ThemeData（应用到全局）
/// [darkText] 为 true 表示深色背景（暗色主题），前景文字用白色。
ThemeData buildAppTheme(AppTheme theme, {bool darkText = false}) {
  const surface = Color(0xFFF6F7F9); // 浅灰背景
  const cardColor = Color(0xFFFFFFFF);
  final onSurface = darkText ? Colors.white : const Color(0xFF0C1014);
  final onSurfaceVariant = darkText
      ? const Color(0xFFB8BEC6)
      : const Color(0xFF6B7280);
  final outline = darkText ? const Color(0xFF3A3F45) : const Color(0xFFD8DCE2);
  final outlineVariant = darkText
      ? const Color(0xFF2E3339)
      : const Color(0xFFE8EAEE);
  final primary = darkText ? Colors.white : const Color(0xFF0C1014);
  final scaffold = darkText ? const Color(0xFF1A1C1F) : surface;

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      surface: scaffold,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      primary: primary,
      secondary: primary,
    ),
    scaffoldBackgroundColor: scaffold,
    canvasColor: darkText ? const Color(0xFF24262A) : cardColor,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      iconTheme: IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: darkText ? const Color(0xFF24262A) : cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(iconColor: onSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkText ? const Color(0xFF24262A) : cardColor,
      surfaceTintColor: Colors.transparent,
      indicatorColor: outlineVariant,
      elevation: 0,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
  );
}
