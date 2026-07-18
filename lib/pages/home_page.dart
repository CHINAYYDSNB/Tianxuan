import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../widgets/animated_nav_bar.dart';
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          if (!_showAi)
            IndexedStack(
              index: _stackIdx,
              children: const [
                _Guard(DashboardPage()),
                _Guard(ResourcePage()),
                SettingsPage(),
              ],
            ),
          if (_showAi)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: AiChatPage(onClose: _closeAi),
              ),
            ),
          // 底部渐变遮罩
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 120 + bottomInset,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.5, 1.0],
                    colors: [Color(0xFFEBEDF5), Color(0xBFEBEDF5), Color(0x00EBEDF5)],
                  ),
                ),
              ),
            ),
          ),
          // 悬浮导航栏 + AI 按钮
          if (!_showAi)
            Positioned(
              bottom: bottomInset + 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AnimatedNavBar(
                      currentIndex: _stackIdx,
                      onTap: (i) => setState(() { _stackIdx = i; }),
                      items: const [
                        AnimatedNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: '概览'),
                        AnimatedNavItem(icon: Icons.dashboard_customize_outlined, activeIcon: Icons.dashboard_customize, label: '资源'),
                        AnimatedNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '设置'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Material(
                      elevation: 0,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(29),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(29),
                        onTap: () => setState(() => _showAi = true),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF0062F5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _closeAi() => setState(() => _showAi = false);
}
