import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import '../../models/website_config.dart';
import '../../utils/downloader.dart';
import 'website_sheet_widgets.dart';

/// SSL 证书管理弹层（证书列表 + 申请/上传/下载/删除）
void showSslManageSheet(BuildContext context) {
  showWebsiteSheet(
    context: context,
    title: 'SSL 证书管理',
    initialSize: 0.9,
    child: SslManageSheet(),
  );
}

class SslManageSheet extends StatefulWidget {
  const SslManageSheet({super.key});

  @override
  State<SslManageSheet> createState() => _SslManageSheetState();
}

class _SslManageSheetState extends State<SslManageSheet> {
  late Future<Map<String, dynamic>> _future;
  List<SslCertificate> _items = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result = await WebsiteApi.searchSsl(page: 1, pageSize: 50);
    if (mounted) {
      setState(() {
        _items = (result['items'] as List<SslCertificate>);
        _total = result['total'] as int? ?? 0;
      });
    }
    return result;
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _createSelfSigned() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SelfSignedForm(
        onCreated: () {
          Navigator.of(ctx).pop();
          _reload();
        },
      ),
    );
  }

  Future<void> _upload() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _UploadForm(
        onUploaded: () {
          Navigator.of(ctx).pop();
          _reload();
        },
      ),
    );
  }

  Future<void> _obtain(SslCertificate cert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请/续签'),
        content: Text('为证书 ${cert.primaryDomain} 申请/续签？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('申请'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await WebsiteApi.obtainSsl(cert.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已提交申请')));
          _reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('申请失败: $e')));
        }
      }
    }
  }

  Future<void> _download(SslCertificate cert) async {
    try {
      final bytes = await WebsiteApi.downloadSsl(cert.id);
      final result = await saveFile('${cert.primaryDomain}.zip', bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已保存: $result')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    }
  }

  Future<void> _delete(SslCertificate cert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除证书 ${cert.primaryDomain}？'),
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
        await WebsiteApi.deleteSsl([cert.id]);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 $_total 张证书',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_link, size: 18),
                onPressed: _createSelfSigned,
                label: const Text('自签证书'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                onPressed: _upload,
                label: const Text('上传'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return SheetError(error: snap.error!, onRetry: _reload);
              }
              if (_items.isEmpty) {
                return const Center(child: Text('暂无证书，点击上方创建或上传'));
              }
              return ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final cert = _items[i];
                  final expired = _isExpired(cert.expireDate);
                  return ListTile(
                    leading: Icon(
                      Icons.verified_user,
                      color: expired
                          ? Colors.red
                          : cert.status.toLowerCase() == 'ready'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(cert.primaryDomain),
                    subtitle: Text(
                      '${cert.provider.isEmpty ? "手动" : cert.provider} · '
                      '到期 ${cert.expireDate.isEmpty ? "-" : cert.expireDate}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'obtain') _obtain(cert);
                        if (v == 'download') _download(cert);
                        if (v == 'delete') _delete(cert);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'obtain',
                          child: Text('申请/续签'),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Text('下载'),
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

  bool _isExpired(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }
}

class _SelfSignedForm extends StatefulWidget {
  final VoidCallback onCreated;
  const _SelfSignedForm({required this.onCreated});

  @override
  State<_SelfSignedForm> createState() => _SelfSignedFormState();
}

class _SelfSignedFormState extends State<_SelfSignedForm> {
  final _domainCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'CN');
  final _orgCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _domainCtrl.dispose();
    _countryCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final domain = _domainCtrl.text.trim();
    if (domain.isEmpty) return;
    setState(() => _saving = true);
    try {
      await WebsiteApi.createSsl({
        'primaryDomain': domain,
        'type': 'self-signed',
        'selfSigned': {
          'country': _countryCtrl.text.trim(),
          'organization': _orgCtrl.text.trim(),
          'domains': [domain],
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('自签证书已创建')));
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
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
                  const Expanded(
                    child: Text(
                      '创建自签证书',
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
                    controller: _domainCtrl,
                    decoration: const InputDecoration(
                      labelText: '主域名 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(
                      labelText: '国家/地区',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orgCtrl,
                    decoration: const InputDecoration(
                      labelText: '组织名称',
                      border: OutlineInputBorder(),
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

class _UploadForm extends StatefulWidget {
  final VoidCallback onUploaded;
  const _UploadForm({required this.onUploaded});

  @override
  State<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends State<_UploadForm> {
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
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('证书上传成功')));
        widget.onUploaded();
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
