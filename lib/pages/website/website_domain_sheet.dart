import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/website_api.dart';
import '../../models/website_config.dart';
import 'website_sheet_widgets.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// 域名管理弹层
void showDomainSheet(BuildContext context, int websiteId, String title) {
  showWebsiteSheet(
    context: context,
    title: '域名管理 · $title',
    initialSize: 0.75,
    child: DomainSheet(websiteId: websiteId),
  );
}

class DomainSheet extends ConsumerStatefulWidget {
  final int websiteId;
  const DomainSheet({super.key, required this.websiteId});

  @override
  ConsumerState<DomainSheet> createState() => _DomainSheetState();
}

class _DomainSheetState extends ConsumerState<DomainSheet> {
  late Future<List<WebsiteDomain>> _future;
  final _newDomainCtrl = TextEditingController();
  final _newPortCtrl = TextEditingController(text: '80');

  @override
  void initState() {
    super.initState();
    _future = WebsiteApi.listDomains(widget.websiteId);
  }

  @override
  void dispose() {
    _newDomainCtrl.dispose();
    _newPortCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = WebsiteApi.listDomains(widget.websiteId));
  }

  Future<void> _addDomain() async {
    final domain = _newDomainCtrl.text.trim();
    if (domain.isEmpty) return;
    try {
      await WebsiteApi.addDomains(widget.websiteId, [
        WebsiteDomainReq(
          domain: domain,
          port: int.tryParse(_newPortCtrl.text) ?? 80,
        ),
      ]);
      if (mounted) {
        _newDomainCtrl.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('域名已添加')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  Future<void> _toggleSsl(WebsiteDomain d) async {
    try {
      await WebsiteApi.updateDomainSsl(d.id, !d.ssl);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _deleteDomain(WebsiteDomain d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除域名 ${d.domain}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await WebsiteApi.deleteDomain(d.id);
        if (mounted) _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 添加域名
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newDomainCtrl,
                  decoration: const InputDecoration(
                    labelText: '新域名',
                    hintText: 'example.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _newPortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: _addDomain,
                tooltip: '添加',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<WebsiteDomain>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return SheetError(error: snap.error!, onRetry: _reload);
              }
              final domains = snap.data ?? const [];
              if (domains.isEmpty) {
                return const Center(child: Text('暂无绑定域名'));
              }
              return ListView.separated(
                itemCount: domains.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = domains[i];
                  return ListTile(
                    leading: Icon(
                      d.ssl ? Icons.lock : Icons.lock_open,
                      color: d.ssl ? Colors.green : AppColors.iconFaint,
                    ),
                    title: Text(d.domain),
                    subtitle: Text('端口 ${d.port}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'ssl') _toggleSsl(d);
                        if (v == 'delete') _deleteDomain(d);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'ssl',
                          child: Text(d.ssl ? '关闭 SSL' : '开启 SSL'),
                        ),
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
