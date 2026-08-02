import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// HTTPS 配置弹层
void showHttpsSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: 'HTTPS',
    initialSize: 0.8,
    child: HttpsSheet(websiteId: websiteId),
  );
}

class HttpsSheet extends StatefulWidget {
  final int websiteId;
  const HttpsSheet({super.key, required this.websiteId});

  @override
  State<HttpsSheet> createState() => _HttpsSheetState();
}

class _HttpsSheetState extends State<HttpsSheet> {
  Map<String, dynamic>? _config;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await WebsiteApi.getHttps(widget.websiteId);
      if (mounted) {
        setState(() {
          _config = cfg;
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

  Future<void> _applyLetsEncrypt() async {
    final emailCtrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("申请 Let's Encrypt"),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: '邮箱地址',
            hintText: 'admin@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, emailCtrl.text),
            child: const Text('申请'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await WebsiteApi.updateHttps(widget.websiteId, {
        'enable': true,
        'type': 'letsencrypt',
        'email': email,
        'primaryDomain': '',
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已提交申请')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('申请失败: $e')));
      }
    }
  }

  Future<void> _uploadCert() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CertUpload(
        websiteId: widget.websiteId,
        onSaved: () {
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  Future<void> _toggleHttps(bool enable) async {
    try {
      await WebsiteApi.updateHttps(widget.websiteId, {'enable': enable});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enable ? '已启用 HTTPS' : '已禁用 HTTPS')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SheetLoading();
    if (_error != null) return SheetError(error: _error!, onRetry: _load);

    final cfg = _config ?? {};
    final enable = cfg['enable'] == true;
    final ssl = cfg['SSL'] is Map ? cfg['SSL'] as Map : null;

    return SheetScroll(
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              enable ? Icons.lock : Icons.lock_open,
              color: enable ? Colors.green : const Color(0xFFAAB4BF),
            ),
            title: Text(enable ? 'HTTPS 已启用' : 'HTTPS 未启用'),
            subtitle: Text(enable ? '证书已配置' : '点击下方按钮配置 SSL'),
          ),
        ),
        if (ssl != null && ssl.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('证书信息', style: Theme.of(context).textTheme.titleSmall),
                  const Divider(),
                  _info('域名', ssl['primaryDomain']?.toString() ?? '-'),
                  _info('颁发者', ssl['provider']?.toString() ?? '-'),
                  _info('状态', ssl['status']?.toString() ?? '-'),
                  _info('过期时间', ssl['expireDate']?.toString() ?? '-'),
                  _info('自动续签', ssl['autoRenew'] == true ? '是' : '否'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _applyLetsEncrypt,
          icon: const Icon(Icons.security),
          label: const Text("申请 Let's Encrypt"),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadCert,
          icon: const Icon(Icons.upload_file),
          label: const Text('上传证书'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _toggleHttps(!enable),
          icon: Icon(enable ? Icons.lock_open : Icons.lock),
          label: Text(enable ? '禁用 HTTPS' : '启用 HTTPS'),
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
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

class _CertUpload extends StatefulWidget {
  final int websiteId;
  final VoidCallback onSaved;

  const _CertUpload({required this.websiteId, required this.onSaved});

  @override
  State<_CertUpload> createState() => _CertUploadState();
}

class _CertUploadState extends State<_CertUpload> {
  final _descCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _certCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cert = _certCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (cert.isEmpty || key.isEmpty) return;
    setState(() => _saving = true);
    try {
      await WebsiteApi.uploadSsl({
        'type': 'paste',
        'certificate': cert,
        'privateKey': key,
        'description': _descCtrl.text.trim(),
        'websiteSSLId': widget.websiteId,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('证书上传成功')));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '上传证书',
                      style: TextStyle(
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
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _certCtrl,
                    maxLines: 8,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: '证书内容 (PEM) *',
                      hintText: '-----BEGIN CERTIFICATE-----',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    maxLines: 8,
                    obscureText: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: '私钥 (PEM) *',
                      hintText: '-----BEGIN PRIVATE KEY-----',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
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
