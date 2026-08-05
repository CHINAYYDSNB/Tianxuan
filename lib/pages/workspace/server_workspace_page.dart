import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_page.dart';
import '../file/file_list_page.dart';
import '../docker/docker_home_page.dart';
import '../website/website_list_page.dart';
import '../ssh/ssh_home_page.dart';
import '../settings/ssh_config_page.dart';
import '../settings/connection_test_page.dart';
import '../../providers/ssh_connection_provider.dart';
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
          ),
          _TabNavigator(
            key: _navigators[1],
            builder: (_) => const FileListPage(),
          ),
          _TabNavigator(
            key: _navigators[2],
            builder: (_) => const DockerHomePage(),
          ),
          _TabNavigator(
            key: _navigators[3],
            builder: (_) => const WebsiteListPage(),
          ),
          _TabNavigator(
            key: _navigators[4],
            builder: (_) => const MoreTabPage(),
          ),
          _TabNavigator(
            key: _navigators[5],
            builder: (_) => const ServerSettingsTab(),
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
class _TabNavigator extends StatelessWidget {
  final WidgetBuilder builder;
  const _TabNavigator({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(builder: builder),
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
  int? _sshLatencyMs;
  bool _testingSsh = false;

  Future<void> _testSshLatency() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SSH 未连接，请先配置 SSH 连接')));
      return;
    }
    setState(() {
      _testingSsh = true;
      _sshLatencyMs = null;
    });
    try {
      final start = DateTime.now();
      final res = await ssh.execute('echo pong');
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (!mounted) return;
      setState(() {
        _testingSsh = false;
        _sshLatencyMs = res.isSuccess ? ms : -1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testingSsh = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检测失败: $e')));
    }
  }

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
            subtitle: '测试与服务器的连接状态',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionTestPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.speed_outlined,
            title: 'SSH 延迟检测',
            subtitle: _sshLatencyMs != null
                ? (_sshLatencyMs! >= 0 ? '延迟: $_sshLatencyMs ms' : 'SSH 连接异常')
                : (_testingSsh ? '检测中...' : '测试 SSH 往返延迟'),
            trailing: Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
            onTap: _testingSsh ? null : _testSshLatency,
          ),
          _SettingTile(
            icon: Icons.terminal_outlined,
            title: 'SSH 终端',
            subtitle: '打开远程终端连接',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SshHomePage()),
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
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 22),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing:
            trailing ??
            const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
        onTap: onTap,
      ),
    );
  }
}
