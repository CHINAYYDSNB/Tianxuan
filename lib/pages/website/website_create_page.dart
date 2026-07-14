import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/website_api.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';

class WebsiteCreatePage extends ConsumerStatefulWidget {
  const WebsiteCreatePage({super.key});

  @override
  ConsumerState<WebsiteCreatePage> createState() => _WebsiteCreatePageState();
}

class _WebsiteCreatePageState extends ConsumerState<WebsiteCreatePage> {
  final _formKey = GlobalKey<FormState>();

  // Step tracking
  int _currentStep = 0;

  // Step 1: Basic info
  final _domainCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final int _groupID = 1;

  // Step 1: Type
  String _type = 'static';

  // Step 2: Type-specific fields
  final _proxyCtrl = TextEditingController();
  final _redirectCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  String _appType = 'installed';

  // Step 2: Resources
  bool _createDB = false;
  final _dbNameCtrl = TextEditingController();
  final _dbUserCtrl = TextEditingController();
  final _dbPassCtrl = TextEditingController();
  String _dbType = 'mysql';

  bool _createFTP = false;
  final _ftpUserCtrl = TextEditingController();
  final _ftpPassCtrl = TextEditingController();
  final _ftpPathCtrl = TextEditingController();

  // Loading
  bool _loading = false;
  String? _error;

  static const _types = ['static', 'proxy', 'redirect', 'deployment'];
  static const _typeLabels = {
    'static': '静态网站',
    'proxy': '反向代理',
    'redirect': '重定向',
    'deployment': '部署',
  };
  static const _typeIcons = {
    'static': Icons.description,
    'proxy': Icons.swap_horiz,
    'redirect': Icons.redo,
    'deployment': Icons.rocket_launch,
  };

  @override
  void initState() {
    super.initState();
    _aliasCtrl.text = _domainCtrl.text;
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _aliasCtrl.dispose();
    _remarkCtrl.dispose();
    _proxyCtrl.dispose();
    _redirectCtrl.dispose();
    _portCtrl.dispose();
    _dbNameCtrl.dispose();
    _dbUserCtrl.dispose();
    _dbPassCtrl.dispose();
    _ftpUserCtrl.dispose();
    _ftpPassCtrl.dispose();
    _ftpPathCtrl.dispose();
    super.dispose();
  }

  void _onDomainChanged(String v) {
    if (_aliasCtrl.text == _domainCtrl.text || _aliasCtrl.text.isEmpty) {
      _aliasCtrl.text = v;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final req = WebsiteCreateRequest(
        primaryDomain: _domainCtrl.text.trim(),
        type: _type,
        alias: _aliasCtrl.text.trim(),
        websiteGroupID: _groupID,
        appType: _appType,
        remark: _remarkCtrl.text.trim(),
        proxy: _type == 'proxy' ? _proxyCtrl.text.trim() : null,
        redirectURL: _type == 'redirect' ? _redirectCtrl.text.trim() : null,
        port: int.tryParse(_portCtrl.text),
      );

      await WebsiteApi.create(req);
      if (mounted) {
        ref.invalidate(websitesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网站创建成功')),
        );
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      setState(() => _error = '创建失败: $e');
      debugPrint('Website create error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建网站'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('上一步'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 2) {
              _submit();
            } else {
              setState(() => _currentStep++);
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
          controlsBuilder: (ctx, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _loading ? null : details.onStepContinue,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentStep == 2 ? '创建' : '下一步'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _loading ? null : details.onStepCancel,
                    child: Text(_currentStep == 0 ? '取消' : '上一步'),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('基本信息'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStep1(),
            ),
            Step(
              title: const Text('网站配置'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStep2(),
            ),
            Step(
              title: const Text('确认创建'),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
              content: _buildStep3(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type selection
        Text('网站类型', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((t) {
            final selected = _type == t;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_typeIcons[t], size: 18),
                  const SizedBox(width: 6),
                  Text(_typeLabels[t] ?? t),
                ],
              ),
              selected: selected,
              onSelected: (v) => setState(() => _type = t),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Domain
        TextFormField(
          controller: _domainCtrl,
          decoration: const InputDecoration(
            labelText: '主域名 *',
            hintText: 'example.com',
            border: OutlineInputBorder(),
          ),
          onChanged: _onDomainChanged,
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入域名' : null,
        ),
        const SizedBox(height: 16),

        // Alias
        TextFormField(
          controller: _aliasCtrl,
          decoration: const InputDecoration(
            labelText: '别名 *',
            hintText: '通常与域名相同',
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入别名' : null,
        ),
        const SizedBox(height: 16),

        // Remark
        TextFormField(
          controller: _remarkCtrl,
          decoration: const InputDecoration(
            labelText: '备注',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Port
        TextFormField(
          controller: _portCtrl,
          decoration: const InputDecoration(
            labelText: '端口 (可选)',
            hintText: '默认 80/443',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type-specific fields
        if (_type == 'proxy') ...[
          TextFormField(
            controller: _proxyCtrl,
            decoration: const InputDecoration(
              labelText: '代理地址 *',
              hintText: 'http://127.0.0.1:8080',
              border: OutlineInputBorder(),
            ),
            validator: (v) => _type == 'proxy' && (v == null || v.trim().isEmpty)
                ? '请输入代理地址'
                : null,
          ),
          const SizedBox(height: 16),
        ],

        if (_type == 'redirect') ...[
          TextFormField(
            controller: _redirectCtrl,
            decoration: const InputDecoration(
              labelText: '重定向目标 URL *',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                _type == 'redirect' && (v == null || v.trim().isEmpty)
                    ? '请输入重定向地址'
                    : null,
          ),
          const SizedBox(height: 16),
        ],

        if (_type == 'deployment') ...[
          DropdownButtonFormField<String>(
            initialValue: _appType,
            decoration: const InputDecoration(
              labelText: '部署方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'new', child: Text('安装新应用')),
              DropdownMenuItem(value: 'installed', child: Text('关联已安装应用')),
            ],
            onChanged: (v) => setState(() => _appType = v ?? 'installed'),
          ),
          const SizedBox(height: 16),
        ],

        const Divider(height: 32),

        // Resource checkboxes
        Text('关联资源', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),

        // Database
        CheckboxListTile(
          title: const Text('创建数据库'),
          subtitle: const Text('MySQL / PostgreSQL'),
          value: _createDB,
          onChanged: (v) => setState(() => _createDB = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_createDB) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _dbType,
            decoration: const InputDecoration(
              labelText: '数据库类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'mysql', child: Text('MySQL')),
              DropdownMenuItem(value: 'postgresql', child: Text('PostgreSQL')),
            ],
            onChanged: (v) => setState(() => _dbType = v ?? 'mysql'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dbNameCtrl,
            decoration: const InputDecoration(
              labelText: '数据库名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dbUserCtrl,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dbPassCtrl,
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
        ],

        const SizedBox(height: 8),

        // FTP
        CheckboxListTile(
          title: const Text('创建 FTP'),
          value: _createFTP,
          onChanged: (v) => setState(() => _createFTP = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_createFTP) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _ftpUserCtrl,
            decoration: const InputDecoration(
              labelText: 'FTP 用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ftpPassCtrl,
            decoration: const InputDecoration(
              labelText: 'FTP 密码',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ftpPathCtrl,
            decoration: const InputDecoration(
              labelText: 'FTP 路径',
              hintText: '默认网站根目录',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('确认信息', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _summaryRow('类型', _typeLabels[_type] ?? _type),
        _summaryRow('域名', _domainCtrl.text),
        _summaryRow('别名', _aliasCtrl.text),
        if (_remarkCtrl.text.isNotEmpty) _summaryRow('备注', _remarkCtrl.text),
        if (_proxyCtrl.text.isNotEmpty) _summaryRow('代理地址', _proxyCtrl.text),
        if (_redirectCtrl.text.isNotEmpty) _summaryRow('重定向', _redirectCtrl.text),
        if (_portCtrl.text.isNotEmpty) _summaryRow('端口', _portCtrl.text),
        if (_createDB) _summaryRow('数据库', '${_dbType}: ${_dbNameCtrl.text}'),
        if (_createFTP) _summaryRow('FTP', _ftpUserCtrl.text),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(
              color: const Color(0xFF686F78),
              fontWeight: FontWeight.w500,
            )),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
