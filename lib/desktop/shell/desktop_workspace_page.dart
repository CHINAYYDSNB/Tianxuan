import 'package:flutter/material.dart';
import '../models/desktop_server.dart';
import '../pages/terminal_tab.dart';
import '../pages/file_tab.dart';
import '../pages/panel_tab.dart';
import '../pages/monitor_tab.dart';

enum _WorkspaceTab { terminal, files, panel, monitor }

class DesktopWorkspacePage extends StatefulWidget {
  final DesktopServer server;
  const DesktopWorkspacePage({super.key, required this.server});

  @override
  State<DesktopWorkspacePage> createState() => _DesktopWorkspacePageState();
}

class _DesktopWorkspacePageState extends State<DesktopWorkspacePage> {
  _WorkspaceTab _tab = _WorkspaceTab.terminal;

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.dns, size: 20),
            const SizedBox(width: 8),
            Text(server.name.isNotEmpty ? server.name : server.host),
            const SizedBox(width: 8),
            Text(
              '${server.username}@${server.host}:${server.port}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.terminal), text: '终端'),
            Tab(icon: Icon(Icons.folder), text: '文件'),
            Tab(icon: Icon(Icons.language), text: '面板'),
            Tab(icon: Icon(Icons.monitor_heart), text: '监控'),
          ],
          onTap: (i) => setState(() => _tab = _WorkspaceTab.values[i]),
        ),
      ),
      body: IndexedStack(
        index: _tab.index,
        children: [
          TerminalTab(server: server),
          FileTab(server: server),
          PanelTab(server: server),
          MonitorTab(server: server),
        ],
      ),
    );
  }
}
