import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'shell/desktop_home_page.dart';

/// 桌面版 MaterialApp：纯 SSH 多服务器管理器。
class DesktopApp extends ConsumerWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final darkText = ref.watch(effectiveDarkTextProvider);
    return MaterialApp(
      title: 'Tianxuan Desktop',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(theme, darkText: darkText),
      home: const DesktopHomePage(),
    );
  }
}
