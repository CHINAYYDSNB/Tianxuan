import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/website_api.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';
import '../file/file_list_page.dart';
import 'website_sheets.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// 点击网站后弹出的操作面板
/// UI 风格：品牌渐变头部 + 基础操作网格宫格 + 配置项分组折叠（与 Mono-Dash 的列表平铺明显区分）
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
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      children: [
        // ── 品牌渐变头部 ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.primary.withAlpha(180)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      w.typeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? Colors.green.withAlpha(120)
                          : Colors.red.withAlpha(120),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      w.statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                w.primaryDomain,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (w.sitePath != null && w.sitePath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    w.sitePath!,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),

        // ── 基础操作（4 列网格宫格） ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              _gridAction(
                context,
                icon: isRunning ? Icons.stop_circle : Icons.play_circle,
                label: isRunning ? '停止' : '启动',
                color: isRunning ? Colors.red : Colors.green,
                onTap: () =>
                    _operate(context, ref, w, isRunning ? 'stop' : 'start'),
              ),
              _gridAction(
                context,
                icon: Icons.refresh,
                label: '重启',
                color: scheme.primary,
                onTap: () => _operate(context, ref, w, 'restart'),
              ),
              _gridAction(
                context,
                icon: Icons.folder_open,
                label: '网站目录',
                color: Colors.orange,
                onTap: () => _openDir(context, w),
              ),
              _gridAction(
                context,
                icon: Icons.delete_outline,
                label: '删除',
                color: Colors.red,
                onTap: () => _delete(context, ref, w),
              ),
            ],
          ),
        ),

        // ── 配置分组（ExpansionTile 折叠） ──
        _buildGroup(context, '设置', [
          _configRow(
            context,
            Icons.language,
            '域名管理',
            () => openDomainSheet(context, w.id, w.primaryDomain),
          ),
          _configRow(
            context,
            Icons.description,
            '默认文档',
            () => openIndexSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.speed,
            '流量限制',
            () => openLimitSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.edit_note,
            '基础信息',
            () => openOtherSheet(context, w),
          ),
        ]),

        _buildGroup(context, '访问控制', [
          _configRow(
            context,
            Icons.swap_horiz,
            '反向代理',
            () => openProxySheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.password,
            '密码访问',
            () => openAuthSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.public,
            '跨域 CORS',
            () => openCorsSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.lock,
            'HTTPS',
            () => openHttpsSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.verified_user,
            '证书管理',
            () => openSslManageSheet(context),
          ),
          _configRow(
            context,
            Icons.dns,
            '真实 IP',
            () => openRealIpSheet(context, w.id),
          ),
        ]),

        _buildGroup(context, '规则与运行', [
          _configRow(
            context,
            Icons.auto_fix_high,
            '伪静态',
            () => openRewriteSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.shield,
            '防盗链',
            () => openLeechSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.arrow_forward,
            '重定向',
            () => openRedirectSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.code,
            'PHP 版本',
            () => openPhpSheet(context, w.id),
          ),
          _configRow(
            context,
            Icons.storage,
            '关联资源',
            () => openResourceSheet(context, w.id),
          ),
        ]),

        _buildGroup(context, '诊断', [
          _configRow(
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
          _configRow(
            context,
            Icons.settings,
            '配置文件',
            () => openConfigSheet(context, w.id),
          ),
        ]),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── 基础操作网格项 ──
  Widget _gridAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 分组折叠 ──
  Widget _buildGroup(BuildContext context, String title, List<Widget> rows) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: rows,
      ),
    );
  }

  // ── 配置项行 ──
  Widget _configRow(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
    );
  }

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
