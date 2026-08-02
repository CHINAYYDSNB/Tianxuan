import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 伪静态（rewrite）配置弹层
void showRewriteSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '伪静态',
    initialSize: 0.8,
    child: RewriteSheet(websiteId: websiteId),
  );
}

class RewriteSheet extends StatefulWidget {
  final int websiteId;
  const RewriteSheet({super.key, required this.websiteId});

  @override
  State<RewriteSheet> createState() => _RewriteSheetState();
}

class _RewriteSheetState extends State<RewriteSheet> {
  final _nameCtrl = TextEditingController();
  late final TextEditingController _contentCtrl;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<String> _templates = [];

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController();
    _loadTemplates();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final t = await WebsiteApi.getCustomRewriteTemplates();
      if (mounted) setState(() => _templates = t);
    } catch (_) {}
  }

  Future<void> _loadContent(String name) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await WebsiteApi.getRewriteContent(
        widget.websiteId,
        name,
      );
      if (mounted) {
        setState(() {
          _nameCtrl.text = name;
          _contentCtrl.text = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await WebsiteApi.updateRewrite(widget.websiteId, name, _contentCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('伪静态配置已保存')));
        Navigator.of(context).pop();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '规则名称 *',
                    hintText: 'wordpress',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_templates.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.folder_open),
                  tooltip: '从模板加载',
                  onSelected: (v) => _loadContent(v),
                  itemBuilder: (_) => [
                    for (final t in _templates)
                      PopupMenuItem(value: t, child: Text(t)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const SheetLoading()
              : _error != null
              ? SheetError(error: _error!, onRetry: () {})
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'location / {\n    # rewrite 规则\n}',
                    ),
                  ),
                ),
        ),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
