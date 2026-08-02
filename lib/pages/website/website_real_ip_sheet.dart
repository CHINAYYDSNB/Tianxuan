import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 真实 IP 配置弹层
void showRealIpSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '真实 IP',
    initialSize: 0.55,
    child: RealIpSheet(websiteId: websiteId),
  );
}

class RealIpSheet extends StatefulWidget {
  final int websiteId;
  const RealIpSheet({super.key, required this.websiteId});

  @override
  State<RealIpSheet> createState() => _RealIpSheetState();
}

class _RealIpSheetState extends State<RealIpSheet> {
  bool _enable = false;
  final _headerCtrl = TextEditingController();
  final _ipsCtrl = TextEditingController();
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
    _headerCtrl.dispose();
    _ipsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await WebsiteApi.getRealIp(widget.websiteId);
      if (mounted) {
        setState(() {
          _enable = cfg.enable;
          _headerCtrl.text = cfg.proxyHeader;
          _ipsCtrl.text = cfg.proxyIps;
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
      await WebsiteApi.updateRealIp({
        'enable': _enable,
        'proxyHeader': _headerCtrl.text.trim(),
        'proxyIps': _ipsCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('真实 IP 配置已保存')));
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
          title: const Text('启用真实 IP'),
          value: _enable,
          onChanged: (v) => setState(() => _enable = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _headerCtrl,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '代理请求头',
            hintText: 'X-Forwarded-For',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ipsCtrl,
          enabled: _enable,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '信任的代理 IP',
            hintText: '每行一个，或用逗号分隔',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
