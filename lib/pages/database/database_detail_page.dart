import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// 数据库实例详情（移植自 Lanxi）：数据库 / 用户 / 连接 三个 tab
class DatabaseDetailPage extends ConsumerStatefulWidget {
  final DbInstance instance;
  final VoidCallback onAuthChanged;
  const DatabaseDetailPage({
    super.key,
    required this.instance,
    required this.onAuthChanged,
  });

  @override
  ConsumerState<DatabaseDetailPage> createState() => _DatabaseDetailPageState();
}

class _DatabaseDetailPageState extends ConsumerState<DatabaseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<DbDatabase> _dbs = [];
  List<DbUser> _users = [];
  String? _connInfo;
  bool _loading = true;
  bool _authPrompted = false;

  DbInstance get inst => widget.instance;

  DatabaseService? get _svc => ref.read(databaseServiceProvider);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _initAuth();
  }

  Future<void> _initAuth() async {
    if (inst.authUser != null && inst.authPass != null) {
      _load();
      return;
    }
    // Try auto-detect from Docker env
    final svc = _svc;
    if (svc != null && inst.inDocker) {
      final creds = await svc.tryDetectCredentials(inst);
      if (creds != null) {
        inst.authUser = creds.user;
        inst.authPass = creds.pass;
        inst.authFailed = false;
        widget.onAuthChanged();
        _load();
        return;
      }
    }
    // Prompt for credentials
    if (mounted && !_authPrompted) {
      _authPrompted = true;
      _showAuthDialog();
    }
  }

  Future<void> _showAuthDialog() async {
    final userCtrl = TextEditingController(text: inst.type.defaultUser);
    final passCtrl = TextEditingController();
    final result = await showDialog<({String user, String pass})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('${inst.type.label} 认证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inst.inDocker) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '容器: ${inst.containerName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(
                labelText: '用户名',
                hintText: inst.type.defaultUser,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, (
                user: userCtrl.text.trim(),
                pass: passCtrl.text,
              )),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              user: userCtrl.text.trim(),
              pass: passCtrl.text,
            )),
            child: const Text('连接'),
          ),
        ],
      ),
    );

    if (result != null) {
      inst.authUser = result.user;
      inst.authPass = result.pass;

      if (mounted) setState(() => _loading = true);
      final svc = _svc;
      if (svc == null) return;
      final err = await svc.testCredentials(inst);
      if (err != null) {
        inst.authFailed = true;
        widget.onAuthChanged();
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('认证失败: $err')));
          _showAuthDialog();
          return;
        }
      }
      inst.authFailed = false;
      widget.onAuthChanged();
      _load();
    } else {
      inst.authFailed = true;
      widget.onAuthChanged();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final svc = _svc;
    if (svc == null || inst.authUser == null || inst.authFailed) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        svc.listDatabases(inst),
        svc.listUsers(inst),
        svc.getConnectionInfo(inst),
      ]);
      if (mounted) {
        setState(() {
          _dbs = results[0] as List<DbDatabase>;
          _users = results[1] as List<DbUser>;
          _connInfo = results[2] as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addDatabase() async {
    final ctrl = TextEditingController();
    final ok = await _inputDialog('添加数据库', '数据库名', ctrl);
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final err = await _svc?.createDatabase(inst, ctrl.text.trim());
      _snack(err == null || err.isEmpty ? '创建成功' : '创建失败: $err');
      _load();
    }
  }

  Future<void> _deleteDatabase(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除数据库'),
        content: Text('确定要删除 "$name" 吗？\n此操作不可逆！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await _svc?.deleteDatabase(inst, name);
      _snack(err == null || err.isEmpty ? '已删除' : '失败: $err');
      _load();
    }
  }

  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '用户名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
      final err = await _svc?.createUser(
        inst,
        nameCtrl.text.trim(),
        passCtrl.text,
      );
      _snack(err == null || err.isEmpty ? '用户已创建' : '失败: $err');
      _load();
    }
  }

  Future<void> _deleteUser(DbUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('删除用户 "${user.name}" ？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await _svc?.deleteUser(
        inst,
        user.name,
        host: user.host ?? '%',
      );
      _snack(err == null || err.isEmpty ? '已删除' : '失败: $err');
      _load();
    }
  }

  Future<void> _changePassword(DbUser user) async {
    final ctrl = TextEditingController();
    final ok = await _inputDialog(
      '修改密码: ${user.name}',
      '新密码',
      ctrl,
      isPassword: true,
    );
    if (ok == true && ctrl.text.isNotEmpty) {
      final err = await _svc?.changePassword(
        inst,
        user.name,
        ctrl.text,
        host: user.host ?? '%',
      );
      _snack(err == null || err.isEmpty ? '密码已修改' : '失败: $err');
      _load();
    }
  }

  Future<void> _grantPrivileges(DbUser user) async {
    if (_dbs.isEmpty) {
      _snack('没有可用的数据库');
      return;
    }
    final db = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择数据库'),
        children: _dbs
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.name),
                child: Text(d.name),
              ),
            )
            .toList(),
      ),
    );
    if (db != null) {
      final err = await _svc?.grantPrivileges(
        inst,
        user.name,
        db,
        host: user.host ?? '%',
      );
      _snack(err == null || err.isEmpty ? '权限已授予 ($db)' : '失败: $err');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<bool?> _inputDialog(
    String title,
    String hint,
    TextEditingController ctrl, {
    bool isPassword = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${inst.type.label}${inst.inDocker ? ' (Docker)' : ''}'),
        actions: [
          if (inst.authUser != null)
            IconButton(
              icon: Icon(Icons.vpn_key, size: 18),
              tooltip: '切换认证',
              onPressed: _showAuthDialog,
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: '数据库'),
            Tab(text: '用户'),
            Tab(text: '连接'),
          ],
        ),
      ),
      body: inst.authUser == null || inst.authFailed
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: inst.authFailed
                          ? Colors.red
                          : theme.colorScheme.outline,
                    ),
                    SizedBox(height: 16),
                    Text(
                      inst.authFailed ? '认证失败' : '需要认证',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      inst.authFailed
                          ? '用户名或密码不正确'
                          : '输入 ${inst.type.label} 的用户名和密码',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.vpn_key, size: 18),
                      label: const Text('输入认证信息'),
                      onPressed: _showAuthDialog,
                    ),
                  ],
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildDbTab(theme),
                _buildUserTab(theme),
                _buildConnTab(theme),
              ],
            ),
    );
  }

  Widget _buildDbTab(ThemeData theme) {
    if (_dbs.isEmpty && inst.type != DbType.redis) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('无数据库', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加数据库'),
              onPressed: _addDatabase,
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (inst.type != DbType.redis)
          Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.add, size: 16),
                label: Text('添加数据库'),
                onPressed: _addDatabase,
              ),
            ),
          ),
        Expanded(
          child: _dbs.isEmpty
              ? Center(
                  child: Text(
                    '无数据库',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _dbs.length,
                  itemBuilder: (_, i) {
                    final d = _dbs[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.table_chart,
                          color: Colors.teal,
                        ),
                        title: Text(
                          d.name,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: inst.type != DbType.redis
                            ? IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteDatabase(d.name),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserTab(ThemeData theme) {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('无用户数据', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('添加用户'),
              onPressed: _addUser,
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('添加用户'),
              onPressed: _addUser,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _users.length,
            itemBuilder: (_, i) {
              final u = _users[i];
              return Card(
                child: ExpansionTile(
                  leading: Icon(Icons.person, color: Colors.blue),
                  title: Text(
                    u.name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: u.host != null
                      ? Text(
                          '@${u.host}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock, size: 18),
                      title: const Text('修改密码', style: TextStyle(fontSize: 13)),
                      onTap: () => _changePassword(u),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, size: 18),
                      title: const Text('授予权限', style: TextStyle(fontSize: 13)),
                      onTap: () => _grantPrivileges(u),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      title: const Text(
                        '删除用户',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                      onTap: () => _deleteUser(u),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('连接信息', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _connInfo?.isNotEmpty == true ? _connInfo! : '无法获取',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow('类型', inst.type.label),
                _infoRow('版本', inst.version ?? '未知'),
                _infoRow('认证用户', inst.authUser ?? '-'),
                _infoRow(
                  '部署',
                  inst.inDocker
                      ? 'Docker (${inst.containerName ?? ""})'
                      : '宿主机',
                ),
                _infoRow('端口', inst.port?.toString() ?? inst.type.defaultPort),
                _infoRow('状态', inst.status ?? '未知'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
