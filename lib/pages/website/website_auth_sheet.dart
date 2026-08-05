import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import '../../models/website_config.dart';
import 'website_sheet_widgets.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// 密码访问配置弹层（全局 + 路径级）
void showAuthSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '密码访问',
    initialSize: 0.8,
    child: AuthSheet(websiteId: websiteId),
  );
}

class AuthSheet extends StatefulWidget {
  final int websiteId;
  const AuthSheet({super.key, required this.websiteId});

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  WebsiteAuth? _global;
  List<WebsitePathAuth> _paths = [];
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
      final global = await WebsiteApi.getAuth(widget.websiteId);
      final paths = await WebsiteApi.listPathAuths(widget.websiteId);
      if (mounted) {
        setState(() {
          _global = global;
          _paths = paths;
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

  Future<void> _saveGlobal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GlobalAuthEditor(
        websiteId: widget.websiteId,
        auth: _global,
        onSaved: () {
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  Future<void> _editPath(WebsitePathAuth? p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PathAuthEditor(
        websiteId: widget.websiteId,
        pathAuth: p,
        onSaved: () {
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  Future<void> _deletePath(WebsitePathAuth p) async {
    try {
      await WebsiteApi.updatePathAuth({
        'websiteID': widget.websiteId,
        'operate': 'delete',
        'path': p.name,
      });
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SheetLoading();
    if (_error != null) return SheetError(error: _error!, onRetry: _load);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        SheetSectionTitle(title: '全局访问密码'),
        Card(
          child: ListTile(
            leading: Icon(
              _global?.enable == true ? Icons.lock : Icons.lock_open,
              color: _global?.enable == true
                  ? Colors.green
                  : AppColors.iconFaint,
            ),
            title: Text(
              _global?.enable == true
                  ? '已启用 (用户: ${_global?.username ?? ""})'
                  : '未启用',
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: _saveGlobal,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                '路径级密码',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () => _editPath(null),
              tooltip: '新增',
            ),
          ],
        ),
        if (_paths.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('暂无路径级密码')),
          )
        else
          ..._paths.map(
            (p) => Card(
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.orange),
                title: Text(p.name),
                subtitle: Text('用户: ${p.username}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editPath(p);
                    if (v == 'delete') _deletePath(p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlobalAuthEditor extends StatefulWidget {
  final int websiteId;
  final WebsiteAuth? auth;
  final VoidCallback onSaved;

  const _GlobalAuthEditor({
    required this.websiteId,
    this.auth,
    required this.onSaved,
  });

  @override
  State<_GlobalAuthEditor> createState() => _GlobalAuthEditorState();
}

class _GlobalAuthEditorState extends State<_GlobalAuthEditor> {
  late bool _enable;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enable = widget.auth?.enable ?? false;
    _userCtrl = TextEditingController(text: widget.auth?.username ?? '');
    _passCtrl = TextEditingController(text: widget.auth?.password ?? '');
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await WebsiteApi.updateAuth({
        'websiteID': widget.websiteId,
        'enable': _enable,
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('密码访问已保存')));
        widget.onSaved();
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
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.55,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '全局访问密码',
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
                  SwitchListTile(
                    title: const Text('启用密码访问'),
                    value: _enable,
                    onChanged: (v) => setState(() => _enable = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _userCtrl,
                    enabled: _enable,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    enabled: _enable,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
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

class _PathAuthEditor extends StatefulWidget {
  final int websiteId;
  final WebsitePathAuth? pathAuth;
  final VoidCallback onSaved;

  const _PathAuthEditor({
    required this.websiteId,
    this.pathAuth,
    required this.onSaved,
  });

  @override
  State<_PathAuthEditor> createState() => _PathAuthEditorState();
}

class _PathAuthEditorState extends State<_PathAuthEditor> {
  late final TextEditingController _pathCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: widget.pathAuth?.name ?? '');
    _userCtrl = TextEditingController(text: widget.pathAuth?.username ?? '');
    _passCtrl = TextEditingController(text: widget.pathAuth?.password ?? '');
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await WebsiteApi.updatePathAuth({
        'websiteID': widget.websiteId,
        'operate': widget.pathAuth == null ? 'add' : 'update',
        'path': _pathCtrl.text.trim(),
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('路径密码已保存')));
        widget.onSaved();
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
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.pathAuth == null ? '新增路径密码' : '编辑路径密码',
                      style: const TextStyle(
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
                    controller: _pathCtrl,
                    decoration: const InputDecoration(
                      labelText: '路径 *',
                      hintText: '/admin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户名 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码 *',
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
