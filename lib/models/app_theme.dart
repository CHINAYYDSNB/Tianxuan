/// 个性化设置：主题配色 + 背景

import 'dart:ui';

/// 主题配色方案
class AppColorScheme {
  final String id;
  final String name;
  final Color primary;
  final Color surface;
  final Color onSurface;

  const AppColorScheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.surface,
    required this.onSurface,
  });
}

/// 预设主题配色（6 套）
const appColorSchemes = <AppColorScheme>[
  AppColorScheme(
    id: 'tianxuan',
    name: '经典黑白',
    primary: Color(0xFF0C1014),
    surface: Color(0xFFF6F7F9),
    onSurface: Color(0xFF0C1014),
  ),
  AppColorScheme(
    id: 'aurora',
    name: '极光绿',
    primary: Color(0xFF00A87A),
    surface: Color(0xFFEAF5EF),
    onSurface: Color(0xFF0C1410),
  ),
  AppColorScheme(
    id: 'sunset',
    name: '暖橙',
    primary: Color(0xFFF57C00),
    surface: Color(0xFFFBF1E6),
    onSurface: Color(0xFF1A120A),
  ),
  AppColorScheme(
    id: 'violet',
    name: '暗紫',
    primary: Color(0xFF7C4DFF),
    surface: Color(0xFFF0EDFA),
    onSurface: Color(0xFF120C1F),
  ),
  AppColorScheme(
    id: 'rose',
    name: '玫瑰红',
    primary: Color(0xFFE91E63),
    surface: Color(0xFFFBEDF2),
    onSurface: Color(0xFF1C0A11),
  ),
  AppColorScheme(
    id: 'ocean',
    name: '深海青',
    primary: Color(0xFF00838F),
    surface: Color(0xFFE6F4F5),
    onSurface: Color(0xFF081416),
  ),
];

/// 背景类型
enum AppBackgroundType {
  solid, // 纯色
  asset, // 内置图片
  custom, // 用户相册图（文件路径）
}

/// 个性化设置状态
class AppTheme {
  final String schemeId;
  final AppBackgroundType backgroundType;
  final String? backgroundAsset; // 内置图名
  final String? backgroundPath; // 用户自定义图路径
  final double backgroundBlur; // 背景模糊强度 0-1

  /// 手动指定前景色模式；null 表示自动（按背景亮度检测）
  final bool? darkText;

  /// 背景图平均亮度（0-1，运行时计算，不持久化）
  final double? backgroundLuminance;

  const AppTheme({
    this.schemeId = 'tianxuan',
    this.backgroundType = AppBackgroundType.solid,
    this.backgroundAsset,
    this.backgroundPath,
    this.backgroundBlur = 0.0,
    this.darkText,
    this.backgroundLuminance,
  });

  AppColorScheme get scheme {
    return appColorSchemes.firstWhere(
      (s) => s.id == schemeId,
      orElse: () => appColorSchemes.first,
    );
  }

  AppTheme copyWith({
    String? schemeId,
    AppBackgroundType? backgroundType,
    String? backgroundAsset,
    String? backgroundPath,
    double? backgroundBlur,
    bool? darkText,
    double? backgroundLuminance,
  }) {
    return AppTheme(
      schemeId: schemeId ?? this.schemeId,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundAsset: backgroundAsset ?? this.backgroundAsset,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      darkText: darkText ?? this.darkText,
      backgroundLuminance: backgroundLuminance ?? this.backgroundLuminance,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemeId': schemeId,
    'backgroundType': backgroundType.name,
    'backgroundAsset': backgroundAsset,
    'backgroundPath': backgroundPath,
    'backgroundBlur': backgroundBlur,
    if (darkText != null) 'darkText': darkText,
  };

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    final bgName = json['backgroundType'] as String? ?? 'solid';
    final bgType = AppBackgroundType.values.firstWhere(
      (t) => t.name == bgName,
      orElse: () => AppBackgroundType.solid,
    );
    return AppTheme(
      schemeId: json['schemeId'] as String? ?? 'tianxuan',
      backgroundType: bgType,
      backgroundAsset: json['backgroundAsset'] as String?,
      backgroundPath: json['backgroundPath'] as String?,
      backgroundBlur: (json['backgroundBlur'] as num?)?.toDouble() ?? 0.0,
      darkText: json['darkText'] as bool?,
    );
  }
}
