import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'ai/ai_chat_page.dart';
import 'dashboard/dashboard_page.dart';
import 'resource/resource_page.dart';
import 'script_store/script_store_page.dart';
import 'settings/settings_page.dart';

/// 未连接时阻止 API 请求, 显示添加按钮
class _Guard extends ConsumerWidget {
  final Widget child;
  const _Guard(this.child);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));
    if (connected) return child;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('未连接服务器', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('请先添加 1Panel 服务器',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            icon: const Icon(Icons.add),
            label: const Text('添加服务器'),
          ),
        ]),
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _stackIdx = 0;
  bool _showAi = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _showAi ? _stackIdx : _stackIdx,
            children: const [
              _Guard(DashboardPage()),      // 0 概览
              _Guard(const ResourcePage()), // 1 资源
              ScriptStorePage(),               // 2 脚本商店
              SettingsPage(),               // 3 设置
            ],
          ),
          if (_showAi)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: AiChatPage(onClose: _closeAi),
              ),
            ),
        ],
      ),
      floatingActionButton: _showAi
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => _showAi = true),
              tooltip: 'AI 助手',
              child: const Icon(Icons.auto_awesome),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _stackIdx,
        onDestinationSelected: (i) => setState(() { _showAi = false; _stackIdx = i; }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '概览'),
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize), label: '资源'),
          NavigationDestination(icon: Icon(Icons.code_outlined), selectedIcon: Icon(Icons.code), label: '脚本商店'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  void _closeAi() => setState(() => _showAi = false);
}
