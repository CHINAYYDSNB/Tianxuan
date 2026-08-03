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
ThemeData buildAppTheme(AppTheme theme) {
  final scheme = theme.scheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      onSurfaceVariant: const Color(0xFF686F78),
      outline: const Color(0xFFAAB4BF),
      primary: scheme.primary,
    ),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFFFFFFF),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(17)),
      ),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
  );
}
