import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../providers/theme_provider.dart';

/// 可复用背景容器：根据主题设置叠加背景图/纯色 + 模糊，内容在上层。
class AppBackground extends ConsumerWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final darkText = ref.watch(effectiveDarkTextProvider);
    final scheme = theme.scheme;

    Widget? bgImage;
    if (theme.backgroundType == AppBackgroundType.asset &&
        theme.backgroundAsset != null) {
      bgImage = Image.asset(
        theme.backgroundAsset!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (theme.backgroundType == AppBackgroundType.custom &&
        theme.backgroundPath != null &&
        theme.backgroundPath!.isNotEmpty) {
      final path = theme.backgroundPath!;
      // 网络图或本地路径
      if (path.startsWith('http')) {
        bgImage = Image.network(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (File(path).existsSync()) {
        bgImage = Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    if (bgImage == null) {
      return Container(color: scheme.surface, child: child);
    }

    // 有背景图时叠加模糊 + 浅色遮罩压浅，保证黑字在任何明暗背景下都可读
    // 暗图用更浓的白色遮罩（0.55），亮图用 0.82
    final maskColor = darkText
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.82);
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: theme.backgroundBlur * 12,
            sigmaY: theme.backgroundBlur * 12,
          ),
          child: bgImage,
        ),
        // 半透明遮罩（暗色主题用深色遮罩，保证白字可读）
        Container(color: maskColor),
        child,
      ],
    );
  }
}
