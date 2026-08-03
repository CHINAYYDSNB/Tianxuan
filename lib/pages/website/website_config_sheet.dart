import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 配置文件编辑弹层
void showConfigSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '配置文件',
    initialSize: 0.9,
    child: ConfigSheet(websiteId: websiteId),
  );
}

class ConfigSheet extends StatefulWidget {
  final int websiteId;
  const ConfigSheet({super.key, required this.websiteId});

  @override
  State<ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<ConfigSheet> {
  late final TextEditingController _ctrl;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 优先读取网站 OpenResty 配置，回退到 nginx config
      final content =
          await WebsiteApi.getWebsiteConfig(widget.websiteId) ??
          await WebsiteApi.getConfig(widget.websiteId);
      if (mounted) {
        setState(() {
          _ctrl.text = content ?? '';
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
    setState(() => _saving = true);
    try {
      await WebsiteApi.updateNginx(widget.websiteId, _ctrl.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存并重载')));
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
    if (_loading) return const SheetLoading();
    if (_error != null) return SheetError(error: _error!, onRetry: _load);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'nginx 配置（保存后自动重载）',
                  style: TextStyle(color: Color(0xFF686F78), fontSize: 12),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _load,
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
