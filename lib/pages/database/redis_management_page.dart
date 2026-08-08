import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';

/// Redis 实例管理：状态 / 配置 / 持久化（对齐 Mono-Dash Redis 管理页）。
class RedisManagementPage extends ConsumerStatefulWidget {
  final DatabaseInstance instance;
  const RedisManagementPage({super.key, required this.instance});

  @override
  ConsumerState<RedisManagementPage> createState() =>
      _RedisManagementPageState();
}

class _RedisManagementPageState extends ConsumerState<RedisManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  DatabaseInstance get _inst => widget.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_inst.name} 路 Redis'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '状态'),
            Tab(text: '配置'),
            Tab(text: '持久化'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RedisStatusTab(inst: _inst),
          _RedisConfTab(inst: _inst),
          _RedisPersistenceTab(inst: _inst),
        ],
      ),
    );
  }
}

class _RedisStatusTab extends ConsumerWidget {
  final DatabaseInstance inst;
  const _RedisStatusTab({required this.inst});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(redisStatusProvider(inst.id));
    final keys = <String>[
      'redis_version',
      'redis_mode',
      'uptime_in_seconds',
      'connected_clients',
      'used_memory_human',
      'used_memory_peak_human',
      'total_connections_received',
      'total_commands_processed',
      'keyspace_hits',
      'keyspace_misses',
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '运行状态',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '刷新',
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () =>
                          ref.invalidate(redisStatusProvider(inst.id)),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                statusAsync.when(
                  data: (status) {
                    if (status.isEmpty) {
                      return Text(
                        '暂无状态数据',
                        style: TextStyle(color: AppColors.textMuted),
                      );
                    }
                    return Column(
                      children: keys
                          .where(status.containsKey)
                          .map(
                            (k) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      status[k]!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Text(
                    '获取失败: $e',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RedisConfTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const _RedisConfTab({required this.inst});

  @override
  ConsumerState<_RedisConfTab> createState() => _RedisConfTabState();
}

class _RedisConfTabState extends ConsumerState<_RedisConfTab> {
  final _timeoutCtrl = TextEditingController();
  final _maxclientsCtrl = TextEditingController();
  final _maxmemoryCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _timeoutCtrl.dispose();
    _maxclientsCtrl.dispose();
    _maxmemoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseServiceProvider)
          .updateRedisConf(
            widget.inst,
            timeout: _timeoutCtrl.text.trim(),
            maxclients: _maxclientsCtrl.text.trim(),
            maxmemory: _maxmemoryCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存'), backgroundColor: Colors.green),
      );
      ref.invalidate(redisConfProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confAsync = ref.watch(redisConfProvider(widget.inst.id));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: confAsync.when(
              data: (conf) {
                if (_timeoutCtrl.text.isEmpty) {
                  _timeoutCtrl.text = conf.timeout;
                  _maxclientsCtrl.text = conf.maxclients;
                  _maxmemoryCtrl.text = conf.maxmemory;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基础配置',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timeoutCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'timeout（秒，0 表示关闭）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxclientsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'maxclients（最大连接数）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxmemoryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'maxmemory（字节，0 表示不限）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('保存配置'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                '读取失败: $e',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RedisPersistenceTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const _RedisPersistenceTab({required this.inst});

  @override
  ConsumerState<_RedisPersistenceTab> createState() =>
      _RedisPersistenceTabState();
}

class _RedisPersistenceTabState extends ConsumerState<_RedisPersistenceTab> {
  bool _aof = false;
  String _appendfsync = 'everysec';
  String _save = '';
  final _saveCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _saveCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAof() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseServiceProvider)
          .updateRedisAofPersistence(
            widget.inst,
            appendonly: _aof ? 'yes' : 'no',
            appendfsync: _appendfsync,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AOF 配置已保存'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(redisPersistenceProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRdb() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseServiceProvider)
          .updateRedisRdbPersistence(widget.inst, save: _save);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RDB 配置已保存'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(redisPersistenceProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final persAsync = ref.watch(redisPersistenceProvider(widget.inst.id));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: persAsync.when(
              data: (p) {
                if (!_loaded) {
                  _aof = p.aofEnabled == 'yes';
                  _appendfsync = p.appendfsync;
                  _save = p.save;
                  _saveCtrl.text = p.save;
                  _loaded = true;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AOF 持久化',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用 AOF'),
                      value: _aof,
                      onChanged: (v) => setState(() => _aof = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _appendfsync,
                      decoration: const InputDecoration(
                        labelText: 'appendfsync',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'always',
                          child: Text('always'),
                        ),
                        DropdownMenuItem(
                          value: 'everysec',
                          child: Text('everysec'),
                        ),
                        DropdownMenuItem(value: 'no', child: Text('no')),
                      ],
                      onChanged: (v) =>
                          setState(() => _appendfsync = v ?? 'everysec'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveAof,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('保存 AOF 配置'),
                      ),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'RDB 持久化',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _saveCtrl,
                      onChanged: (v) => _save = v,
                      decoration: const InputDecoration(
                        labelText: 'save 规则（逗号分隔，如 3600 1,300 100）',
                        border: OutlineInputBorder(),
                        hintText: '3600 1,300 100,60 10000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveRdb,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('保存 RDB 配置'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                '读取失败: $e',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
