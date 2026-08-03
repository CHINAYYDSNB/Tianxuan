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

    // 有背景图时叠加模糊 + 半透明遮罩保证可读性
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
        // 半透明遮罩（浅色，保证文字可读）
        Container(color: Colors.white.withValues(alpha: 0.82)),
        child,
      ],
    );
  }
}
