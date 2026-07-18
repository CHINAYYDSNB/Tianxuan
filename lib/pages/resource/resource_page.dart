import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/website_provider.dart';
import '../../providers/container_provider.dart';
import '../../providers/installed_app_provider.dart';
import '../website/website_list_page.dart';
import '../file/file_list_page.dart';
import '../docker/docker_home_page.dart';
import '../docker/installed_list_page.dart';
import '../docker/app_store_page.dart';
import '../ssh/ssh_home_page.dart';
import '../script_store/script_store_page.dart';

/// 资源页 — 入口卡片列表，点进具体功能
class ResourcePage extends ConsumerWidget {
  const ResourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteCount = ref.watch(websitesProvider).when(
      data: (l) => l.length, loading: () => null, error: (_, __) => null);
    final containerCount = ref.watch(containerListProvider).when(
      data: (l) => '${l.where((c) => c.isRunning).length}/${l.length}', loading: () => null, error: (_, __) => null);
    final appCount = ref.watch(installedAppListProvider).when(
      data: (l) => l.length, loading: () => null, error: (_, __) => null);

    return Scaffold(
      appBar: AppBar(title: const Text('资源')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResourceCard(
            icon: Icons.language,
            iconColor: Colors.blue,
            title: '网站',
            subtitle: siteCount != null ? '$siteCount 个站点' : null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebsiteListPage())),
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.folder,
            iconColor: Colors.amber,
            title: '文件管理',
            subtitle: '浏览 / 编辑 / 上传 / 下载',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileListPage())),
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.view_in_ar,
            iconColor: Colors.teal,
            title: '容器管理',
            subtitle: containerCount != null ? '$containerCount 运行/总数' : null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DockerHomePage())),
          ),
          if (appCount != null && appCount > 0) ...[
            const SizedBox(height: 10),
            _ResourceCard(
              icon: Icons.checklist,
              iconColor: Colors.purple,
              title: '已安装应用',
              subtitle: '$appCount 个应用',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstalledListPage())),
            ),
          ],
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.terminal,
            iconColor: Colors.green,
            title: 'SSH 终端',
            subtitle: '远程服务器连接',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshHomePage())),
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.article,
            iconColor: Colors.indigo,
            title: '脚本',
            subtitle: '浏览 / 执行脚本',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScriptStorePage())),
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.store,
            iconColor: Colors.orange,
            title: 'Docker商店',
            subtitle: '1Panel 应用商店',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppStorePage())),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withAlpha(30),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF686F78))),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
            ],
          ),
        ),
      ),
    );
  }
}
