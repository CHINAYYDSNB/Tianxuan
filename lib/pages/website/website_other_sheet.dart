import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import '../../models/website.dart';
import 'website_sheet_widgets.dart';

/// 基础信息编辑弹层
void showOtherSheet(BuildContext context, Website website) {
  showWebsiteSheet(
    context: context,
    title: '基础信息',
    initialSize: 0.6,
    child: OtherSheet(website: website),
  );
}

class OtherSheet extends StatefulWidget {
  final Website website;
  const OtherSheet({super.key, required this.website});

  @override
  State<OtherSheet> createState() => _OtherSheetState();
}

class _OtherSheetState extends State<OtherSheet> {
  late final TextEditingController _remarkCtrl;
  late final TextEditingController _proxyCtrl;
  late final TextEditingController _redirectCtrl;
  bool _ipv6 = false;
  bool _openBaseDir = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.website;
    _remarkCtrl = TextEditingController(text: w.remark);
    _proxyCtrl = TextEditingController(text: w.proxy ?? '');
    _redirectCtrl = TextEditingController(text: w.redirectURL ?? '');
    _ipv6 = w.iPV6;
    _openBaseDir = w.openBaseDir;
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    _proxyCtrl.dispose();
    _redirectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await WebsiteApi.update(widget.website.id, {
        'remark': _remarkCtrl.text.trim(),
        if (widget.website.type == 'proxy') 'proxy': _proxyCtrl.text.trim(),
        if (widget.website.type == 'redirect')
          'redirectURL': _redirectCtrl.text.trim(),
        'IPV6': _ipv6,
        'openBaseDir': _openBaseDir,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('基础信息已保存')));
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
    final w = widget.website;
    return SheetScroll(
      children: [
        _readonlyRow('类型', w.typeLabel),
        _readonlyRow('域名', w.primaryDomain),
        _readonlyRow('别名', w.alias),
        _readonlyRow('创建时间', w.createdAt),
        const SizedBox(height: 12),
        TextField(
          controller: _remarkCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '备注',
            border: OutlineInputBorder(),
          ),
        ),
        if (w.type == 'proxy') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _proxyCtrl,
            decoration: const InputDecoration(
              labelText: '代理地址',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (w.type == 'redirect') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _redirectCtrl,
            decoration: const InputDecoration(
              labelText: '重定向目标',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('启用 IPV6'),
          value: _ipv6,
          onChanged: (v) => setState(() => _ipv6 = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('开放 basedir'),
          value: _openBaseDir,
          onChanged: (v) => setState(() => _openBaseDir = v),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        SheetSaveBar(loading: _saving, onSave: _save),
      ],
    );
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF686F78), fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
