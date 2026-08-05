import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_page.dart';
import '../file/file_list_page.dart';
import '../docker/docker_home_page.dart';
import '../website/website_list_page.dart';
import '../settings/ssh_config_page.dart';
import '../settings/connection_test_page.dart';
import 'server_system_page.dart';
import 'server_cronjob_page.dart';
import 'workspace_more_panel.dart';

/// 服务器工作台 — 点服务器卡片进入，底部六 tab 导航。
/// 每个 tab 拥有独立 Navigator，保持各自页面栈与底部 bar 常驻。
class ServerWorkspacePage extends ConsumerStatefulWidget {
  const ServerWorkspacePage({super.key});

  @override
  ConsumerState<ServerWorkspacePage> createState() =>
      _ServerWorkspacePageState();
}

class _ServerWorkspacePageState extends ConsumerState<ServerWorkspacePage> {
  int _tab = 0;
  final _navigators = List.generate(6, (_) => GlobalKey<NavigatorState>());

  static const _tabs = [
    (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: '概览'),
    (icon: Icons.folder_outlined, active: Icons.folder, label: '文件'),
    (
      icon: Icons.view_in_ar_outlined,
      active: Icons.view_in_ar,
      label: 'Docker',
    ),
    (icon: Icons.language_outlined, active: Icons.language, label: '网站'),
    (icon: Icons.apps_outlined, active: Icons.apps, label: '更多'),
    (icon: Icons.settings_outlined, active: Icons.settings, label: '设置'),
  ];

  void _onTabTap(int i) {
    if (i == 4) {
      // 「更多」→ 弹出功能入口面板
      showWorkspaceMorePanel(context);
      return;
    }
    setState(() => _tab = i);
  }

  /// 返回键：非概览 tab 先切回概览（上一级菜单），概览才退出工作台
  void _handleTabBack() {
    if (_tab == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _tab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _TabNavigator(
            key: _navigators[0],
            builder: (_) => const DashboardPage(),
            onRootBack: _handleTabBack,
          ),
          _TabNavigator(
            key: _navigators[1],
            builder: (_) => FileListPage(onRootBack: _handleTabBack),
            onRootBack: _handleTabBack,
          ),
          _TabNavigator(
            key: _navigators[2],
            builder: (_) => const DockerHomePage(),
            onRootBack: _handleTabBack,
          ),
          _TabNavigator(
            key: _navigators[3],
            builder: (_) => const WebsiteListPage(),
            onRootBack: _handleTabBack,
          ),
          _TabNavigator(
            key: _navigators[4],
            builder: (_) => const MoreTabPage(),
            onRootBack: _handleTabBack,
          ),
          _TabNavigator(
            key: _navigators[5],
            builder: (_) => const ServerSettingsTab(),
            onRootBack: _handleTabBack,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          border: Border(top: BorderSide(color: Color(0xFFE8E9EB))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final selected = i == _tab;
                return Expanded(
                  child: InkWell(
                    onTap: () => _onTabTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? t.active : t.icon,
                          size: 22,
                          color: selected
                              ? const Color(0xFF0C1014)
                              : const Color(0xFF9AA1A9),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? const Color(0xFF0C1014)
                                : const Color(0xFF9AA1A9),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 每个 tab 的独立 Navigator 容器
/// 根 route 包 PopScope(canPop:false)：tab 根不直接 pop（否则内层栈空白屏），
/// 返回时通过 [onRootBack] 交给工作台处理（切回概览 / 退出）。
class _TabNavigator extends StatelessWidget {
  final WidgetBuilder builder;
  final VoidCallback onRootBack;
  const _TabNavigator({
    super.key,
    required this.builder,
    required this.onRootBack,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) onRootBack();
          },
          child: builder(context),
        ),
      ),
    );
  }
}

/// 「更多」tab — 弹窗入口面板
class MoreTabPage extends StatelessWidget {
  const MoreTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更多')),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => showWorkspaceMorePanel(context),
          icon: const Icon(Icons.apps),
          label: const Text('打开功能面板'),
        ),
      ),
    );
  }
}

/// 「设置」tab — 服务器相关设置
class ServerSettingsTab extends ConsumerStatefulWidget {
  const ServerSettingsTab({super.key});

  @override
  ConsumerState<ServerSettingsTab> createState() => _ServerSettingsTabState();
}

class _ServerSettingsTabState extends ConsumerState<ServerSettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SettingTile(
            icon: Icons.terminal,
            title: 'SSH 连接',
            subtitle: '配置 Docker SSH 管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SshConfigPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.wifi_find_outlined,
            title: '连接检测',
            subtitle: '测试 API 与 SSH 连接状态和延迟',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionTestPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.computer_outlined,
            title: '系统设置',
            subtitle: 'DNS / 主机名 / 密码 / NTP / 时区',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerSystemPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.schedule_outlined,
            title: '计划任务',
            subtitle: '管理服务器定时任务',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerCronjobPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 22),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: onTap,
      ),
    );
  }
}
