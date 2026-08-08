import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'tray/desktop_tray.dart';
import 'updater/desktop_updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    title: 'Tianxuan Desktop',
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  DesktopTray.instance.init();
  DesktopUpdater.instance.checkOnStartup();

  runApp(const ProviderScope(child: DesktopApp()));
  // 桌面端禁用系统快捷键（如 Ctrl+W 关闭窗口交给快捷键系统）
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
