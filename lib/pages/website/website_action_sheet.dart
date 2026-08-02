import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/website_api.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';
import '../file/file_list_page.dart';
import 'website_sheets.dart';

/// 点击网站后弹出的操作面板（朴素风格）
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return detailAsync.when(
          data: (w) => _buildSheet(context, ref, w, scrollCtrl),
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
    WidgetRef ref,
    Website w,
    ScrollController scrollCtrl,
  ) {
    final isRunning = w.isRunning;

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
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
        // 标题信息
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      w.primaryDomain,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    w.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isRunning ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${w.typeLabel} · ${w.alias}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF686F78)),
              ),
              if (w.sitePath != null && w.sitePath!.isNotEmpty)
                Text(
                  w.sitePath!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAAB4BF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 基础操作
        _sectionTitle(context, '基础操作'),
        _row(
          context,
          Icons.play_arrow,
          isRunning ? '停止网站' : '启动网站',
          () => _operate(context, ref, w, isRunning ? 'stop' : 'start'),
        ),
        _divider(),
        _row(
          context,
          Icons.refresh,
          '重启网站',
          () => _operate(context, ref, w, 'restart'),
        ),
        _divider(),
        _row(
          context,
          Icons.folder_open,
          '网站目录',
          () => _openDir(context, w),
          subtitle: w.sitePath,
        ),
        _divider(),
        _row(
          context,
          Icons.delete_outline,
          '删除网站',
          () => _delete(context, ref, w),
        ),

        // 设置
        _sectionTitle(context, '设置'),
        _row(
          context,
          Icons.language,
          '域名管理',
          () => openDomainSheet(context, w.id, w.primaryDomain),
          subtitle: '添加/编辑/删除绑定域名',
        ),
        _divider(),
        _row(
          context,
          Icons.description,
          '默认文档',
          () => openIndexSheet(context, w.id),
          subtitle: '配置默认首页文件',
        ),
        _divider(),
        _row(
          context,
          Icons.speed,
          '流量限制',
          () => openLimitSheet(context, w.id),
          subtitle: '并发与速率限制',
        ),
        _divider(),
        _row(
          context,
          Icons.edit_note,
          '基础信息',
          () => openOtherSheet(context, w),
          subtitle: '修改备注、端口等',
        ),

        // 访问控制
        _sectionTitle(context, '访问控制'),
        _row(
          context,
          Icons.swap_horiz,
          '反向代理',
          () => openProxySheet(context, w.id),
        ),
        _divider(),
        _row(
          context,
          Icons.password,
          '密码访问',
          () => openAuthSheet(context, w.id),
        ),
        _divider(),
        _row(
          context,
          Icons.public,
          '跨域 CORS',
          () => openCorsSheet(context, w.id),
        ),
        _divider(),
        _row(context, Icons.lock, 'HTTPS', () => openHttpsSheet(context, w.id)),
        _divider(),
        _row(
          context,
          Icons.verified_user,
          '证书管理',
          () => openSslManageSheet(context),
        ),
        _divider(),
        _row(context, Icons.dns, '真实 IP', () => openRealIpSheet(context, w.id)),

        // 规则与运行
        _sectionTitle(context, '规则与运行'),
        _row(
          context,
          Icons.auto_fix_high,
          '伪静态',
          () => openRewriteSheet(context, w.id),
        ),
        _divider(),
        _row(context, Icons.shield, '防盗链', () => openLeechSheet(context, w.id)),
        _divider(),
        _row(
          context,
          Icons.arrow_forward,
          '重定向',
          () => openRedirectSheet(context, w.id),
        ),
        _divider(),
        _row(context, Icons.code, 'PHP 版本', () => openPhpSheet(context, w.id)),
        _divider(),
        _row(
          context,
          Icons.storage,
          '关联资源',
          () => openResourceSheet(context, w.id),
        ),

        // 诊断
        _sectionTitle(context, '诊断'),
        _row(
          context,
          Icons.receipt_long,
          '日志查看',
          () => openLogSheet(
            context,
            w.id,
            accessLogPath: w.accessLogPath,
            errorLogPath: w.errorLogPath,
            sitePath: w.sitePath,
          ),
        ),
        _divider(),
        _row(
          context,
          Icons.settings,
          '配置文件',
          () => openConfigSheet(context, w.id),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF686F78),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: const Color(0xFF686F78)),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFFAAB4BF)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56);

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
