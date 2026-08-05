import 'package:flutter/material.dart';
import 'container_list_page.dart';
import 'image_list_page.dart';
import 'compose_list_page.dart';
import 'docker_daemon_page.dart';
import 'package:tianxuan/theme/app_colors.dart';

class DockerHomePage extends StatelessWidget {
  const DockerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('容器管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DockerCard(
            icon: Icons.view_in_ar_outlined,
            title: '容器',
            subtitle: '启动 / 停止 / 重启 / 日志',
            color: const Color(0xFF1976D2),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContainerListPage()),
            ),
          ),
          const SizedBox(height: 10),
          _DockerCard(
            icon: Icons.image_outlined,
            title: '镜像',
            subtitle: '拉取 / 删除 / 构建',
            color: const Color(0xFF7B61FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImageListPage()),
            ),
          ),
          const SizedBox(height: 10),
          _DockerCard(
            icon: Icons.dns_outlined,
            title: 'Compose',
            subtitle: '编排 / 启动 / 停止',
            color: const Color(0xFF00838F),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComposeListPage()),
            ),
          ),
          const SizedBox(height: 10),
          _DockerCard(
            icon: Icons.settings_applications_outlined,
            title: 'Docker 管理',
            subtitle: '守护进程状态与配置',
            color: const Color(0xFFF57C00),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DockerDaemonPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _DockerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.iconFaint),
            ],
          ),
        ),
      ),
    );
  }
}
