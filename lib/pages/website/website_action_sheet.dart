import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/website_api.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';
import '../file/file_list_page.dart';
import 'website_sheets.dart';

/// 点击网站后弹出的操作面板
void showWebsiteActionSheet(
  BuildContext context,
  WidgetRef ref,
  Website website,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => WebsiteActionSheet(website: website),
  );
}

class WebsiteActionSheet extends ConsumerWidget {
  final Website website;
  const WebsiteActionSheet({super.key, required this.website});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(websiteDetailProvider(website.id));
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return detailAsync.when(
          data: (w) => _buildSheet(context, theme, ref, w, scrollCtrl),
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('详情加载失败'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(websiteDetailProvider(website.id)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheet(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    Website w,
    ScrollController scrollCtrl,
  ) {
    final isRunning = w.isRunning;
    final hasSsl = w.protocol?.toLowerCase() == 'https';

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 拖拽指示条
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFAAB4BF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // 信息卡
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        w.primaryDomain,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      hasSsl ? Icons.lock : Icons.lock_open,
                      color: hasSsl ? Colors.green : const Color(0xFFAAB4BF),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Chip(label: w.typeLabel, color: const Color(0xFF0062F5)),
                    _Chip(
                      label: w.statusLabel,
                      color: isRunning ? Colors.green : Colors.red,
                    ),
                    if (w.remark.isNotEmpty)
                      _Chip(label: w.remark, color: const Color(0xFFAAB4BF)),
                  ],
                ),
                if (w.sitePath != null && w.sitePath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '目录: ${w.sitePath}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 基础操作
        _sectionTitle(context, '基础操作'),
        Card(
          child: Column(
            children: [
              _actionRow(
                context,
                icon: isRunning ? Icons.stop : Icons.play_arrow,
                color: isRunning ? Colors.red : Colors.green,
                title: isRunning ? '停止网站' : '启动网站',
                onTap: () =>
                    _operate(context, ref, w, isRunning ? 'stop' : 'start'),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.refresh,
                color: const Color(0xFF0062F5),
                title: '重启网站',
                onTap: () => _operate(context, ref, w, 'restart'),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.folder_open,
                color: Colors.orange,
                title: '网站目录',
                subtitle: w.sitePath,
                onTap: () => _openDir(context, w),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.delete_outline,
                color: Colors.red,
                title: '删除网站',
                onTap: () => _delete(context, ref, w),
              ),
            ],
          ),
        ),

        // 设置
        _sectionTitle(context, '设置'),
        Card(
          child: Column(
            children: [
              _actionRow(
                context,
                icon: Icons.language,
                color: const Color(0xFF0062F5),
                title: '域名管理',
                subtitle: '添加/编辑/删除绑定域名',
                onTap: () => openDomainSheet(context, w.id, w.primaryDomain),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.folder_special,
                color: Colors.orange,
                title: '默认文档',
                subtitle: '配置 index.html 等默认首页',
                onTap: () => openIndexSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.speed,
                color: Colors.teal,
                title: '流量限制',
                subtitle: '配置并发连接与速率限制',
                onTap: () => openLimitSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.account_circle,
                color: Colors.deepPurple,
                title: '基础信息',
                subtitle: '修改备注、默认端口等',
                onTap: () => openOtherSheet(context, w),
              ),
            ],
          ),
        ),

        // 访问控制
        _sectionTitle(context, '访问控制'),
        Card(
          child: Column(
            children: [
              _actionRow(
                context,
                icon: Icons.swap_horiz,
                color: Colors.purple,
                title: '反向代理',
                subtitle: '配置代理规则',
                onTap: () => openProxySheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.password,
                color: Colors.red,
                title: '密码访问',
                subtitle: '全局或路径级访问密码',
                onTap: () => openAuthSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.public,
                color: const Color(0xFF0062F5),
                title: '跨域 CORS',
                subtitle: '配置跨域访问规则',
                onTap: () => openCorsSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.https,
                color: Colors.green,
                title: 'HTTPS',
                subtitle: '配置 SSL 证书',
                onTap: () => openHttpsSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.dns,
                color: Colors.cyan,
                title: '真实 IP',
                subtitle: '配置代理层真实 IP',
                onTap: () => openRealIpSheet(context, w.id),
              ),
            ],
          ),
        ),

        // 规则与运行
        _sectionTitle(context, '规则与运行'),
        Card(
          child: Column(
            children: [
              _actionRow(
                context,
                icon: Icons.auto_fix_high,
                color: Colors.pink,
                title: '伪静态',
                subtitle: '配置 rewrite 规则',
                onTap: () => openRewriteSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.shield,
                color: Colors.orange,
                title: '防盗链',
                subtitle: '防止资源被外链',
                onTap: () => openLeechSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.arrow_forward,
                color: const Color(0xFF0062F5),
                title: '重定向',
                subtitle: '配置 301/302 跳转',
                onTap: () => openRedirectSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.code,
                color: Colors.deepPurple,
                title: 'PHP 版本',
                subtitle: '切换 PHP 运行环境',
                onTap: () => openPhpSheet(context, w.id),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.storage,
                color: Colors.teal,
                title: '关联资源',
                subtitle: '数据库、FTP 等',
                onTap: () => openResourceSheet(context, w.id),
              ),
            ],
          ),
        ),

        // 诊断
        _sectionTitle(context, '诊断'),
        Card(
          child: Column(
            children: [
              _actionRow(
                context,
                icon: Icons.receipt_long,
                color: Colors.brown,
                title: '日志查看',
                subtitle: '访问/错误日志',
                onTap: () => openLogSheet(
                  context,
                  w.id,
                  accessLogPath: w.accessLogPath,
                  errorLogPath: w.errorLogPath,
                  sitePath: w.sitePath,
                ),
              ),
              _divider(),
              _actionRow(
                context,
                icon: Icons.settings_applications,
                color: Colors.indigo,
                title: '配置文件',
                subtitle: '编辑 nginx 配置',
                onTap: () => openConfigSheet(context, w.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFF686F78),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF686F78),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFAAB4BF)),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 64);

  Future<void> _operate(
    BuildContext context,
    WidgetRef ref,
    Website w,
    String action,
  ) async {
    try {
      await WebsiteApi.operate(w.id, action);
      ref.invalidate(websiteDetailProvider(w.id));
      ref.invalidate(websitesProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${action == "start"
                  ? "启动"
                  : action == "stop"
                  ? "停止"
                  : "重启"}成功',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Website w) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${w.primaryDomain} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await WebsiteApi.delete(w.id);
        ref.invalidate(websitesProvider);
        if (context.mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  Future<void> _openDir(BuildContext context, Website w) async {
    if (w.sitePath == null || w.sitePath!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网站路径未设置')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileListPage(initialPath: w.sitePath)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
