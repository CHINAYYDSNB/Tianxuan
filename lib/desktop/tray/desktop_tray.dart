import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘：最小化到托盘，托盘菜单支持显示/退出。
class DesktopTray implements TrayListener {
  DesktopTray._();
  static final instance = DesktopTray._();
  bool _ready = false;

  Future<void> init() async {
    try {
      await trayManager.setIcon('assets/icon-1024.png');
      await trayManager.setToolTip('Tianxuan Desktop');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: '显示主窗口'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: '退出'),
          ],
        ),
      );
      trayManager.addListener(this);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (_ready) windowManager.show();
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    if (_ready) trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'quit':
        windowManager.destroy();
        break;
    }
  }
}
