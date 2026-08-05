import 'package:flutter/material.dart';

/// 语义化颜色：深色模式下自动切换，页面用这些常量代替硬编码色值。
/// 由 [theme_provider.buildAppTheme] 每次构建时设置 [darkMode]。
class AppColors {
  static bool darkMode = false;

  /// 主文字 / 主图标
  static Color get textMain =>
      darkMode ? Colors.white : const Color(0xFF0C1014);

  /// 次要文字
  static Color get textSecondary =>
      darkMode ? const Color(0xFFB8BEC6) : const Color(0xFF686F78);

  /// 弱化文字 / 提示
  static Color get textMuted =>
      darkMode ? const Color(0xFF7A828C) : const Color(0xFF9AA1A9);

  /// 右箭头等弱图标
  static Color get iconFaint =>
      darkMode ? const Color(0xFF6B7280) : const Color(0xFFAAB4BF);

  /// 边框 / 分隔线
  static Color get divider =>
      darkMode ? const Color(0xFF2E3339) : const Color(0xFFE8EAEE);

  /// 卡片背景
  static Color get card => darkMode ? const Color(0xFF1E2126) : Colors.white;

  /// 页面底色
  static Color get surface =>
      darkMode ? const Color(0xFF121418) : const Color(0xFFF6F7F9);
}
