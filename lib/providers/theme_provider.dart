import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
    _recomputeLuminance();
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
    _recomputeLuminance();
  }

  Future<void> setBackgroundAsset(String? asset) async {
    state = state.copyWith(
      backgroundAsset: asset,
      backgroundType: asset == null
          ? AppBackgroundType.solid
          : AppBackgroundType.asset,
    );
    await _save();
    _recomputeLuminance();
  }

  Future<void> setBackgroundPath(String? path) async {
    state = state.copyWith(
      backgroundPath: path,
      backgroundType: path == null
          ? AppBackgroundType.solid
          : AppBackgroundType.custom,
    );
    await _save();
    _recomputeLuminance();
  }

  Future<void> setBackgroundBlur(double v) async {
    state = state.copyWith(backgroundBlur: v);
    await _save();
  }

  /// 手动指定暗色模式；null 恢复自动检测
  Future<void> setDarkText(bool? v) async {
    state = state.copyWith(darkText: v);
    await _save();
  }

  /// 根据当前背景重算平均亮度（异步，不阻塞 UI）
  Future<void> _recomputeLuminance() async {
    Uint8List? bytes;
    final t = state;
    if (t.backgroundType == AppBackgroundType.asset &&
        t.backgroundAsset != null) {
      final b = await rootBundle.load(t.backgroundAsset!);
      bytes = b.buffer.asUint8List();
    } else if (t.backgroundType == AppBackgroundType.custom &&
        t.backgroundPath != null &&
        t.backgroundPath!.isNotEmpty) {
      final path = t.backgroundPath!;
      try {
        if (path.startsWith('http')) {
          final client = HttpClient();
          try {
            final req = await client.getUrl(Uri.parse(path));
            final resp = await req.close();
            bytes = await consolidateHttpClientResponseBytes(resp);
          } finally {
            client.close();
          }
        } else {
          bytes = await File(path).readAsBytes();
        }
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) {
      state = state.copyWith(backgroundLuminance: null);
      return;
    }

    try {
      final lum = await _imageLuminance(bytes);
      if (mounted) {
        state = state.copyWith(backgroundLuminance: lum);
      }
    } catch (_) {
      if (mounted) state = state.copyWith(backgroundLuminance: null);
    }
  }

  /// 解码并采样图片平均亮度（0-1）
  static Future<double> _imageLuminance(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width;
    final h = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (w == 0 || h == 0 || data == null) return 0.5;
    final b = data.buffer.asUint8List();

    // 等距采样 16x16 像素
    final stepX = (w / 16).ceil();
    final stepY = (h / 16).ceil();
    double sum = 0;
    int n = 0;
    for (var y = 0; y < h; y += stepY) {
      for (var x = 0; x < w; x += stepX) {
        final i = (y * w + x) * 4;
        if (i + 2 >= b.length) continue;
        final r = b[i] / 255.0;
        final g = b[i + 1] / 255.0;
        final bb = b[i + 2] / 255.0;
        sum += 0.2126 * r + 0.7152 * g + 0.0722 * bb;
        n++;
      }
    }
    return n == 0 ? 0.5 : sum / n;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>(
  (ref) => ThemeNotifier(),
);

/// 有效前景模式：手动值优先，否则按背景亮度自动判定
/// 亮背景（亮度高）→ 黑字；暗背景 → 白字
final effectiveDarkTextProvider = Provider<bool>((ref) {
  final t = ref.watch(themeProvider);
  if (t.darkText != null) return t.darkText!;

  if (t.backgroundLuminance != null) {
    return t.backgroundLuminance! < 0.4;
  }
  // 纯色背景用表面色亮度判定
  return t.scheme.surface.computeLuminance() < 0.4;
});

/// 由 AppTheme 生成 Material 3 ColorScheme
ColorScheme buildColorScheme(AppTheme theme, Brightness brightness) {
  final scheme = theme.scheme;
  return ColorScheme.fromSeed(
    seedColor: scheme.primary,
    brightness: brightness,
    surface: scheme.surface,
  );
}

/// 生成 ThemeData（应用到全局），配色取自 [theme.scheme]，
/// [darkText] 为 true 表示深色背景（暗色主题），前景文字用白色。
ThemeData buildAppTheme(AppTheme theme, {bool darkText = false}) {
  final scheme = theme.scheme;
  final surface = scheme.surface;
  const cardColor = Color(0xFFFFFFFF);
  final onSurface = darkText ? Colors.white : scheme.onSurface;
  final onSurfaceVariant = darkText
      ? const Color(0xFFB8BEC6)
      : const Color(0xFF6B7280);
  final outline = darkText ? const Color(0xFF3A3F45) : const Color(0xFFD8DCE2);
  final outlineVariant = darkText
      ? const Color(0xFF2E3339)
      : const Color(0xFFE8EAEE);
  final primary = darkText ? Colors.white : scheme.primary;
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
