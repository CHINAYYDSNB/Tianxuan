import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/backup_provider.dart';
import '../../services/backup_service.dart';

/// 备份账号表单（新增/编辑）。
class BackupAccountFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;

  const BackupAccountFormSheet({super.key, this.existing});

  @override
  ConsumerState<BackupAccountFormSheet> createState() =>
      _BackupAccountFormSheetState();
}

const _backupTypes = [
  'SFTP',
  'OSS',
  'COS',
  'S3',
  'MINIO',
  'KODO',
  'UPYUN',
  'WebDAV',
  'OneDrive',
  'GoogleDrive',
  'ALIYUN',
  'LOCAL',
];

class _BackupAccountFormSheetState
    extends ConsumerState<BackupAccountFormSheet> {
  final _nameCtrl = TextEditingController();
  final _accessKeyCtrl = TextEditingController();
  final _credentialCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _bucketCtrl = TextEditingController();
  final _backupPathCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _passphraseCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _driveIdCtrl = TextEditingController();

  String _type = 'SFTP';
  String _authMode = 'password';
  bool _isCN = false;
  bool _testing = false;
  bool _saving = false;
  List<dynamic> _buckets = [];
  bool _loadingBuckets = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _nameCtrl.text = e['name']?.toString() ?? '';
      _type = e['type']?.toString() ?? 'SFTP';
      _backupPathCtrl.text = e['backupPath']?.toString() ?? '';
      _bucketCtrl.text = e['bucket']?.toString() ?? '';
      _accessKeyCtrl.text = e['accessKey']?.toString() ?? '';
      _credentialCtrl.text = e['credential']?.toString() ?? '';
      final vars = e['varsJson'];
      final varsMap = vars is Map<String, dynamic> ? vars : <String, dynamic>{};
      _endpointCtrl.text =
          varsMap['endpointItem']?.toString() ??
          varsMap['endpoint']?.toString() ??
          '';
      _regionCtrl.text = varsMap['region']?.toString() ?? '';
      _addressCtrl.text = varsMap['address']?.toString() ?? '';
      _portCtrl.text = '${varsMap['port'] ?? 22}';
      _authMode = varsMap['authMode']?.toString() ?? 'password';
      _passphraseCtrl.text = varsMap['passPhrase']?.toString() ?? '';
      _domainCtrl.text = varsMap['domain']?.toString() ?? '';
      _tokenCtrl.text = varsMap['refresh_token']?.toString() ?? '';
      _driveIdCtrl.text = varsMap['drive_id']?.toString() ?? '';
      _isCN = varsMap['isCN'] == 'true';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _accessKeyCtrl.dispose();
    _credentialCtrl.dispose();
    _endpointCtrl.dispose();
    _regionCtrl.dispose();
    _bucketCtrl.dispose();
    _backupPathCtrl.dispose();
    _addressCtrl.dispose();
    _portCtrl.dispose();
    _passphraseCtrl.dispose();
    _domainCtrl.dispose();
    _tokenCtrl.dispose();
    _driveIdCtrl.dispose();
    super.dispose();
  }

  BackupService get _svc => ref.read(backupServiceProvider);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _isEdit ? '编辑备份账号' : '添加备份账号',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _field('账号名称', _nameCtrl, '请输入名称'),
            _typePicker(),
            const Divider(height: 32),
            const Text(
              '认证信息',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._buildAuthFields(),
            const Divider(height: 32),
            const Text(
              '存储设置',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._buildStorageFields(),
            const SizedBox(height: 24),
            if (_type != 'LOCAL') ...[
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('测试连接'),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _typePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(
          labelText: '类型',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _backupTypes
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _type = v;
            _buckets = [];
            _bucketCtrl.clear();
          });
        },
      ),
    );
  }

  List<Widget> _buildAuthFields() {
    switch (_type) {
      case 'SFTP':
        return [
          _field('地址', _addressCtrl, '服务器地址'),
          _field('端口', _portCtrl, '22', keyboard: TextInputType.number),
          _field('用户名', _accessKeyCtrl, 'SSH 用户名'),
          _authModePicker(),
          if (_authMode == 'password')
            _field('密码', _credentialCtrl, 'SSH 密码', obscure: true)
          else ...[
            _field('私钥', _credentialCtrl, '私钥内容', obscure: true),
            _field('私钥口令', _passphraseCtrl, '可选', obscure: true),
          ],
        ];
      case 'WebDAV':
        return [
          _field('地址', _addressCtrl, 'WebDAV 地址'),
          _field('用户名', _accessKeyCtrl, 'WebDAV 用户名'),
          _field('密码', _credentialCtrl, 'WebDAV 密码', obscure: true),
        ];
      case 'UPYUN':
        return [
          _field('操作员', _accessKeyCtrl, '操作员名称'),
          _field('密码', _credentialCtrl, '操作员密码', obscure: true),
        ];
      case 'KODO':
        return [
          _field('Access Key', _accessKeyCtrl, 'Access Key ID'),
          _field(
            'Secret Key',
            _credentialCtrl,
            'Access Key Secret',
            obscure: true,
          ),
          _field('域名', _domainCtrl, 'http://example.com'),
        ];
      case 'OneDrive':
      case 'GoogleDrive':
        return [
          _field('Refresh Token', _tokenCtrl, 'Refresh Token', obscure: true),
          _isCnToggle(),
        ];
      case 'ALIYUN':
        return [
          _field('Refresh Token', _tokenCtrl, 'Refresh Token', obscure: true),
          _field('Drive ID', _driveIdCtrl, 'Drive ID'),
        ];
      case 'LOCAL':
        return const [];
      default:
        return [
          _field('Access Key', _accessKeyCtrl, 'Access Key ID'),
          _field(
            'Secret Key',
            _credentialCtrl,
            'Access Key Secret',
            obscure: true,
          ),
          _field('Endpoint', _endpointCtrl, _endpointPlaceholder),
          if (_type == 'COS' || _type == 'S3')
            _field('Region', _regionCtrl, 'e.g. ap-guangzhou'),
        ];
    }
  }

  Widget _isCnToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Expanded(child: Text('中国区')),
          Switch(value: _isCN, onChanged: (v) => setState(() => _isCN = v)),
        ],
      ),
    );
  }

  Widget _authModePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Expanded(child: Text('认证方式')),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'password', label: Text('密码')),
              ButtonSegment(value: 'key', label: Text('密钥')),
            ],
            selected: {_authMode},
            onSelectionChanged: (s) => setState(() => _authMode = s.first),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStorageFields() {
    final fields = <Widget>[];
    if (_type != 'LOCAL' &&
        _type != 'SFTP' &&
        _type != 'WebDAV' &&
        _type != 'OneDrive' &&
        _type != 'GoogleDrive' &&
        _type != 'ALIYUN') {
      fields.add(_bucketRow());
    }
    fields.add(
      _field('备份路径', _backupPathCtrl, _type == 'SFTP' ? '远程备份目录' : '可选'),
    );
    return fields;
  }

  Widget _bucketRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(_type == 'UPYUN' ? '服务名' : 'Bucket')),
          if (_buckets.isNotEmpty)
            DropdownButton<String>(
              value: _bucketCtrl.text.isEmpty ? null : _bucketCtrl.text,
              hint: const Text('选择 Bucket'),
              items: _buckets
                  .map((b) => DropdownMenuItem(value: '$b', child: Text('$b')))
                  .toList(),
              onChanged: (v) => setState(() => _bucketCtrl.text = v ?? ''),
            )
          else
            TextButton(
              onPressed: _loadingBuckets ? null : _loadBuckets,
              child: _loadingBuckets
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('加载 Bucket'),
            ),
        ],
      ),
    );
  }

  String get _endpointPlaceholder {
    switch (_type) {
      case 'OSS':
        return 'https://oss-cn-hangzhou.aliyuncs.com';
      case 'COS':
        return 'https://cos.ap-guangzhou.myqcloud.com';
      case 'S3':
        return 'https://s3.amazonaws.com';
      case 'MINIO':
        return 'http://minio.example.com:9000';
      default:
        return 'http://...';
    }
  }

  Map<String, dynamic> _buildPayload() {
    final varsMap = <String, dynamic>{};
    switch (_type) {
      case 'SFTP':
        varsMap['address'] = _addressCtrl.text.trim();
        varsMap['port'] = int.tryParse(_portCtrl.text) ?? 22;
        varsMap['authMode'] = _authMode;
        if (_authMode == 'key') {
          varsMap['passPhrase'] = _passphraseCtrl.text;
        }
        break;
      case 'WebDAV':
        varsMap['address'] = _addressCtrl.text.trim();
        break;
      case 'KODO':
        varsMap['domain'] = _domainCtrl.text.trim();
        break;
      case 'OneDrive':
      case 'GoogleDrive':
        varsMap['refresh_token'] = _tokenCtrl.text.trim();
        varsMap['isCN'] = _isCN ? 'true' : 'false';
        break;
      case 'ALIYUN':
        varsMap['refresh_token'] = _tokenCtrl.text.trim();
        varsMap['drive_id'] = _driveIdCtrl.text.trim();
        break;
      default:
        varsMap['endpoint'] = _endpointCtrl.text.trim();
        if (_regionCtrl.text.isNotEmpty) {
          varsMap['region'] = _regionCtrl.text.trim();
        }
    }
    return {
      'name': _nameCtrl.text.trim(),
      'type': _type,
      'accessKey': base64.encode(utf8.encode(_accessKeyCtrl.text.trim())),
      'credential': base64.encode(utf8.encode(_credentialCtrl.text)),
      'bucket': _bucketCtrl.text.trim(),
      'backupPath': _backupPathCtrl.text.trim(),
      'vars': jsonEncode(varsMap),
      if (_isEdit) 'id': widget.existing!['id'],
    };
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      await _svc.checkConnection(_buildPayload());
      if (!mounted) return;
      _snack('连接成功', green: true);
    } catch (e) {
      if (mounted) _snack('连接失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _loadBuckets() async {
    setState(() => _loadingBuckets = true);
    try {
      final buckets = await _svc.listBuckets(_buildPayload());
      if (!mounted) return;
      setState(() => _buckets = buckets);
    } catch (e) {
      if (mounted) _snack('加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingBuckets = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('请输入账号名称');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      if (_isEdit) {
        await _svc.updateAccount(payload);
      } else {
        await _svc.createAccount(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('保存失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool green = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: green ? Colors.green : Colors.red,
      ),
    );
  }
}
