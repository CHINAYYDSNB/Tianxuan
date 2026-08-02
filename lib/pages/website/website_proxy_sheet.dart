import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import '../../models/website_config.dart';
import 'website_sheet_widgets.dart';

/// 反向代理配置弹层
void showProxySheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '反向代理',
    initialSize: 0.8,
    child: ProxySheet(websiteId: websiteId),
  );
}

class ProxySheet extends StatefulWidget {
  final int websiteId;
  const ProxySheet({super.key, required this.websiteId});

  @override
  State<ProxySheet> createState() => _ProxySheetState();
}

class _ProxySheetState extends State<ProxySheet> {
  late Future<List<WebsiteProxy>> _future;

  @override
  void initState() {
    super.initState();
    _future = WebsiteApi.listProxies(widget.websiteId);
  }

  void _reload() {
    setState(() => _future = WebsiteApi.listProxies(widget.websiteId));
  }

  Future<void> _toggle(WebsiteProxy p) async {
    try {
      await WebsiteApi.updateProxyStatus(
        widget.websiteId,
        p.name,
        p.enable ? 'disable' : 'enable',
      );
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _delete(WebsiteProxy p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除代理规则 ${p.name}？'),
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
        await WebsiteApi.deleteProxy(widget.websiteId, p.name);
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

  Future<void> _edit(WebsiteProxy? p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProxyEditor(
        websiteId: widget.websiteId,
        proxy: p,
        onSaved: () {
          Navigator.of(ctx).pop();
          if (mounted) _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '反向代理规则',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _edit(null),
                label: const Text('新增'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<WebsiteProxy>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return SheetError(error: snap.error!, onRetry: _reload);
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return const Center(child: Text('暂无反向代理规则'));
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    leading: Icon(
                      p.enable ? Icons.swap_horiz : Icons.horizontal_rule,
                      color: p.enable ? Colors.green : const Color(0xFFAAB4BF),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.location} → ${p.proxyPass}'),
                    onTap: () => _edit(p),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'toggle') _toggle(p);
                        if (v == 'delete') _delete(p);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(p.enable ? '停用' : '启用'),
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

class _ProxyEditor extends StatefulWidget {
  final int websiteId;
  final WebsiteProxy? proxy;
  final VoidCallback onSaved;

  const _ProxyEditor({
    required this.websiteId,
    this.proxy,
    required this.onSaved,
  });

  @override
  State<_ProxyEditor> createState() => _ProxyEditorState();
}

class _ProxyEditorState extends State<_ProxyEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _proxyPassCtrl;
  bool _enable = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.proxy;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _locationCtrl = TextEditingController(text: p?.location ?? '/');
    _proxyPassCtrl = TextEditingController(text: p?.proxyPass ?? '');
    _enable = p?.enable ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _proxyPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final proxyPass = _proxyPassCtrl.text.trim();
    if (name.isEmpty || location.isEmpty || proxyPass.isEmpty) return;
    setState(() => _saving = true);
    try {
      await WebsiteApi.updateProxy({
        'websiteID': widget.websiteId,
        'name': name,
        'type': 'location',
        'location': location,
        'enable': _enable,
        'proxyPass': proxyPass,
        'changeDirectory': 0,
        'directory': '',
        'extraParams': [],
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('代理规则已保存')));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.proxy == null ? '新增反向代理' : '编辑反向代理',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '规则名称 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: '匹配路径 *',
                      hintText: '/',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _proxyPassCtrl,
                    decoration: const InputDecoration(
                      labelText: '代理目标 *',
                      hintText: 'http://127.0.0.1:8080',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用'),
                    value: _enable,
                    onChanged: (v) => setState(() => _enable = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  SheetSaveBar(loading: _saving, onSave: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
