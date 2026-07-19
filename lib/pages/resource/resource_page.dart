import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/website_provider.dart';
import '../../providers/installed_app_provider.dart';
import '../website/website_list_page.dart';
import '../file/file_list_page.dart';
import '../docker/container_list_page.dart';
import '../docker/image_list_page.dart';
import '../docker/compose_list_page.dart';
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
    final appCount = ref.watch(installedAppListProvider).when(
      data: (l) => l.length, loading: () => null, error: (_, __) => null);

    return Scaffold(
      appBar: AppBar(title: const Text('资源')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // ─── 容器生态 ───
          _SectionHeader(title: '容器生态'),
          const SizedBox(height: 8),
          _CategoryCard(children: [
            _ResourceRow(
              icon: Icons.view_in_ar_outlined, iconColor: Colors.teal,
              title: '容器', subtitle: '启动 / 停止 / 日志',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerListPage())),
            ),
            _ResourceRow(
              icon: Icons.image_outlined, iconColor: Colors.teal,
              title: '镜像', subtitle: '拉取 / 删除 / 构建',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageListPage())),
            ),
            _ResourceRow(
              icon: Icons.dns_outlined, iconColor: Colors.teal,
              title: 'Compose', subtitle: '编排 / 启动 / 停止',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposeListPage())),
            ),
            _ResourceRow(
              icon: Icons.store, iconColor: Colors.orange,
              title: 'Docker商店', subtitle: '1Panel 应用商店',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppStorePage())),
            ),
            if (appCount != null && appCount > 0)
              _ResourceRow(
                icon: Icons.checklist, iconColor: Colors.purple,
                title: '已安装应用', subtitle: '$appCount 个应用',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstalledListPage())),
              ),
          ]),
          const SizedBox(height: 10),
          // ─── 网站 ───
          _SectionHeader(title: '网站'),
          const SizedBox(height: 8),
          _CategoryCard(children: [
            _ResourceRow(
              icon: Icons.language, iconColor: Colors.blue,
              title: '网站', subtitle: siteCount != null ? '$siteCount 个站点' : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebsiteListPage())),
            ),
          ]),
          const SizedBox(height: 10),
          // ─── 系统工具 ───
          _SectionHeader(title: '系统工具'),
          const SizedBox(height: 8),
          _CategoryCard(children: [
            _ResourceRow(
              icon: Icons.folder, iconColor: Colors.amber,
              title: '文件管理', subtitle: '浏览 / 编辑 / 上传 / 下载',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FileListPage())),
            ),
            _ResourceRow(
              icon: Icons.terminal, iconColor: Colors.green,
              title: 'SSH 终端', subtitle: '远程服务器连接',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SshHomePage())),
            ),
            _ResourceRow(
              icon: Icons.article, iconColor: Colors.indigo,
              title: '脚本商店', subtitle: '浏览 / 安装 / 执行脚本',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScriptStorePage())),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFAAB4BF))),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final List<Widget> children;

  const _CategoryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ResourceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withAlpha(30),
              child: Icon(icon, color: iconColor, size: 20),
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
            const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
          ],
        ),
      ),
    );
  }
}
