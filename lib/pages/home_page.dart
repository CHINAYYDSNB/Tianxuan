import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/animated_nav_bar.dart';
import 'ai/ai_chat_page.dart';
import 'settings/settings_page.dart';
import 'servers/server_cards_page.dart';

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
              children: const [ServerCardsPage(), SettingsPage()],
            ),
          if (_showAi)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: AiChatPage(onClose: _closeAi),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120 + bottomInset,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.5, 1.0],
                    colors: [
                      Color(0xFFEBEDF5),
                      Color(0xBFEBEDF5),
                      Color(0x00EBEDF5),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                      onTap: (i) => setState(() {
                        _stackIdx = i;
                      }),
                      items: const [
                        AnimatedNavItem(
                          icon: Icons.dns_outlined,
                          activeIcon: Icons.dns,
                          label: '服务器',
                        ),
                        AnimatedNavItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: '设置',
                        ),
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
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF0C1014),
                        ),
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
