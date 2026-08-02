import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 防盗链配置弹层
void showLeechSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '防盗链',
    initialSize: 0.7,
    child: LeechSheet(websiteId: websiteId),
  );
}

class LeechSheet extends StatefulWidget {
  final int websiteId;
  const LeechSheet({super.key, required this.websiteId});

  @override
  State<LeechSheet> createState() => _LeechSheetState();
}

class _LeechSheetState extends State<LeechSheet> {
  bool _enable = false;
  String _type = 'black';
  final _serversCtrl = TextEditingController();
  final _returnsCtrl = TextEditingController(text: '403');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serversCtrl.dispose();
    _returnsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await WebsiteApi.getLeech(widget.websiteId);
      if (mounted) {
        setState(() {
          _enable = cfg.enable;
          _type = cfg.type.isEmpty ? 'black' : cfg.type;
          _serversCtrl.text = cfg.servers;
          _returnsCtrl.text = cfg.returns.isEmpty ? '403' : cfg.returns;
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
      await WebsiteApi.updateLeech({
        'enable': _enable,
        'type': _type,
        'servers': _serversCtrl.text.trim(),
        'returns': _returnsCtrl.text.trim(),
        'suffixs': ['jpg', 'png', 'gif', 'zip', 'mp3', 'mp4', 'rar'],
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('防盗链配置已保存')));
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

    return SheetScroll(
      children: [
        SwitchListTile(
          title: const Text('启用防盗链'),
          value: _enable,
          onChanged: (v) => setState(() => _enable = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'black', label: Text('黑名单')),
            ButtonSegment(value: 'white', label: Text('白名单')),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() => _type = v.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _serversCtrl,
          enabled: _enable,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _type == 'black' ? '禁止的域名来源' : '允许的域名来源',
            hintText: '每行一个域名，如 example.com',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _returnsCtrl,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '拒绝时返回',
            hintText: '403',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
