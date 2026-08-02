import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 跨域 CORS 配置弹层
void showCorsSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '跨域 CORS',
    initialSize: 0.6,
    child: CorsSheet(websiteId: websiteId),
  );
}

class CorsSheet extends StatefulWidget {
  final int websiteId;
  const CorsSheet({super.key, required this.websiteId});

  @override
  State<CorsSheet> createState() => _CorsSheetState();
}

class _CorsSheetState extends State<CorsSheet> {
  bool _enable = false;
  final _originCtrl = TextEditingController();
  final _methodCtrl = TextEditingController(
    text: 'GET, POST, PUT, DELETE, OPTIONS',
  );
  final _headersCtrl = TextEditingController();
  bool _cookie = false;
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
    _originCtrl.dispose();
    _methodCtrl.dispose();
    _headersCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await WebsiteApi.getCors(widget.websiteId);
      if (mounted) {
        setState(() {
          _enable = cfg.enable;
          _originCtrl.text = cfg.origin;
          _methodCtrl.text = cfg.method;
          _headersCtrl.text = cfg.headers;
          _cookie = cfg.cookie;
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
      await WebsiteApi.updateCors({
        'enable': _enable,
        'origin': _originCtrl.text.trim(),
        'method': _methodCtrl.text.trim(),
        'headers': _headersCtrl.text.trim(),
        'cookie': _cookie,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CORS 配置已保存')));
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
          title: const Text('启用 CORS'),
          value: _enable,
          onChanged: (v) => setState(() => _enable = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _originCtrl,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '允许的源 Origin',
            hintText: 'https://example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _methodCtrl,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '允许的方法',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _headersCtrl,
          enabled: _enable,
          decoration: const InputDecoration(
            labelText: '允许的请求头',
            hintText: '留空表示允许所有',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('允许携带 Cookie'),
          value: _cookie,
          onChanged: (v) => setState(() => _cookie = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }
}
