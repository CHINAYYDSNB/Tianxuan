import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_config.dart';
import '../providers/ai_provider.dart';
import '../providers/settings_provider.dart';
import 'ai/ai_chat_page.dart';
import 'dashboard/dashboard_page.dart';
import 'management/management_page.dart';
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
  bool _fabOpenedAi = false;
  bool _isFloating = false;

  late final List<Widget> _stablePages;

  @override
  void initState() {
    super.initState();
    _buildPages();
    ref.listenManual(aiConfigProvider.select((c) => c.entryMode), (prev, next) {
      final f = next == AiEntryMode.floating;
      if (f != _isFloating) {
        _isFloating = f;
        _buildPages();
        setState(() {});
      }
    });
  }

  void _buildPages() {
    final ai = AiChatPage(onClose: _isFloating ? _closeAi : null);
    _stablePages = [
      _Guard(DashboardPage()),
      const ManagementPage(),
      ScriptStorePage(),
      ai,
      SettingsPage(),
    ];
  }

  int _navToStack(int navIdx) => _isFloating && navIdx >= 3 ? navIdx + 1 : navIdx;
  int _stackToNav(int stackIdx) {
    if (!_isFloating) return stackIdx;
    if (stackIdx == 3) return 0;
    return stackIdx > 3 ? stackIdx - 1 : stackIdx;
  }

  void _onTapNav(int navIdx) {
    setState(() { _fabOpenedAi = false; _stackIdx = _navToStack(navIdx); });
  }

  void _openAi() => setState(() { _stackIdx = 3; _fabOpenedAi = true; });
  void _closeAi() => setState(() { _fabOpenedAi = false; _stackIdx = 0; });

  @override
  Widget build(BuildContext context) {
    final showAiTab = !_isFloating;
    final showIdx = (!showAiTab && !_fabOpenedAi && _stackIdx == 3) ? 4 : _stackIdx;
    final navIdx = _stackToNav(showIdx);

    return Scaffold(
      body: IndexedStack(index: showIdx, children: _stablePages),
      floatingActionButton: _isFloating && showIdx < 2
          ? FloatingActionButton(
              onPressed: _openAi,
              tooltip: 'AI 助手',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: NavigationBar(
        indicatorColor: Colors.transparent,
        selectedIndex: navIdx,
        onDestinationSelected: _onTapNav,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '概览'),
          const NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: '管理'),
          const NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: '商店'),
          if (showAiTab)
            const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
      ),
    );
  }
}
