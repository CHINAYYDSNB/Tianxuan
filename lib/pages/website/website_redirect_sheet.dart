import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import '../../models/website_config.dart';
import 'website_sheet_widgets.dart';

/// 重定向配置弹层
void showRedirectSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '重定向',
    initialSize: 0.8,
    child: RedirectSheet(websiteId: websiteId),
  );
}

class RedirectSheet extends StatefulWidget {
  final int websiteId;
  const RedirectSheet({super.key, required this.websiteId});

  @override
  State<RedirectSheet> createState() => _RedirectSheetState();
}

class _RedirectSheetState extends State<RedirectSheet> {
  late Future<List<WebsiteRedirect>> _future;

  @override
  void initState() {
    super.initState();
    _future = WebsiteApi.getRedirects(widget.websiteId);
  }

  void _reload() {
    setState(() => _future = WebsiteApi.getRedirects(widget.websiteId));
  }

  Future<void> _edit(WebsiteRedirect? r) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RedirectEditor(
        websiteId: widget.websiteId,
        redirect: r,
        onSaved: () {
          Navigator.of(ctx).pop();
          _reload();
        },
      ),
    );
  }

  Future<void> _toggle(WebsiteRedirect r) async {
    try {
      await WebsiteApi.updateRedirect({
        'websiteID': widget.websiteId,
        'operate': r.enable ? 'disable' : 'enable',
        'name': r.name,
      });
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _delete(WebsiteRedirect r) async {
    try {
      await WebsiteApi.updateRedirect({
        'websiteID': widget.websiteId,
        'operate': 'delete',
        'name': r.name,
      });
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
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
                  '重定向规则',
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
          child: FutureBuilder<List<WebsiteRedirect>>(
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
                return const Center(child: Text('暂无重定向规则'));
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ListTile(
                    leading: Icon(
                      r.enable ? Icons.arrow_forward : Icons.block,
                      color: r.enable
                          ? const Color(0xFF0062F5)
                          : const Color(0xFFAAB4BF),
                    ),
                    title: Text(r.name),
                    subtitle: Text('${r.source} → ${r.target}'),
                    onTap: () => _edit(r),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'toggle') _toggle(r);
                        if (v == 'delete') _delete(r);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(r.enable ? '停用' : '启用'),
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

class _RedirectEditor extends StatefulWidget {
  final int websiteId;
  final WebsiteRedirect? redirect;
  final VoidCallback onSaved;

  const _RedirectEditor({
    required this.websiteId,
    this.redirect,
    required this.onSaved,
  });

  @override
  State<_RedirectEditor> createState() => _RedirectEditorState();
}

class _RedirectEditorState extends State<_RedirectEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sourceCtrl;
  late final TextEditingController _targetCtrl;
  bool _enable = true;
  int _statusCode = 301;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.redirect;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _sourceCtrl = TextEditingController(text: r?.source ?? '');
    _targetCtrl = TextEditingController(text: r?.target ?? '');
    _enable = r?.enable ?? true;
    _statusCode = r?.statusCode ?? 301;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sourceCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final source = _sourceCtrl.text.trim();
    final target = _targetCtrl.text.trim();
    if (name.isEmpty || source.isEmpty || target.isEmpty) return;
    setState(() => _saving = true);
    try {
      await WebsiteApi.updateRedirect({
        'websiteID': widget.websiteId,
        'operate': widget.redirect == null ? 'add' : 'update',
        'name': name,
        'type': 'domain',
        'source': source,
        'target': target,
        'enable': _enable,
        'keepPath': false,
        'keepQuery': 0,
        'statusCode': _statusCode,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重定向规则已保存')));
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
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.redirect == null ? '新增重定向' : '编辑重定向',
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
                    controller: _sourceCtrl,
                    decoration: const InputDecoration(
                      labelText: '来源路径 *',
                      hintText: '/old',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetCtrl,
                    decoration: const InputDecoration(
                      labelText: '目标地址 *',
                      hintText: 'https://example.com/new',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _statusCode,
                    decoration: const InputDecoration(
                      labelText: '状态码',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 301, child: Text('301 永久重定向')),
                      DropdownMenuItem(value: 302, child: Text('302 临时重定向')),
                      DropdownMenuItem(value: 307, child: Text('307 临时重定向')),
                    ],
                    onChanged: (v) => setState(() => _statusCode = v ?? 301),
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
