import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 流量限制配置弹层
void showLimitSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '流量限制',
    initialSize: 0.6,
    child: LimitSheet(websiteId: websiteId),
  );
}

class LimitSheet extends StatefulWidget {
  final int websiteId;
  const LimitSheet({super.key, required this.websiteId});

  @override
  State<LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<LimitSheet> {
  bool _enable = false;
  final _perServerCtrl = TextEditingController(text: '0');
  final _perIpCtrl = TextEditingController(text: '0');
  final _rateCtrl = TextEditingController(text: '0');
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
    _perServerCtrl.dispose();
    _perIpCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await WebsiteApi.getLimitConfig(widget.websiteId);
      if (mounted) {
        setState(() {
          _enable = cfg.enable;
          _perServerCtrl.text = cfg.perServerLimit.toString();
          _perIpCtrl.text = cfg.perIpLimit.toString();
          _rateCtrl.text = cfg.rateKb.toString();
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
      await WebsiteApi.updateLimitConfig(
        widget.websiteId,
        enable: _enable,
        perServerLimit: int.tryParse(_perServerCtrl.text) ?? 0,
        perIpLimit: int.tryParse(_perIpCtrl.text) ?? 0,
        rateKb: int.tryParse(_rateCtrl.text) ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('流量限制已保存')));
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
          title: const Text('启用流量限制'),
          value: _enable,
          onChanged: (v) => setState(() => _enable = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _perServerCtrl,
          keyboardType: TextInputType.number,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '单服务器并发连接数',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _perIpCtrl,
          keyboardType: TextInputType.number,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '单 IP 并发连接数',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rateCtrl,
          keyboardType: TextInputType.number,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '传输速率 (KB/s)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
