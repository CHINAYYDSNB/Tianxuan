import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// MySQL 性能变量调整页。
class DatabasePerformancePage extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const DatabasePerformancePage({super.key, required this.inst});

  @override
  ConsumerState<DatabasePerformancePage> createState() =>
      _PerformancePageState();
}

class _VariableDef {
  final String key;
  final String label;

  const _VariableDef(this.key, this.label);
}

const _groups = [
  _VariableGroup('连接', [
    _VariableDef('maxConnections', 'max_connections'),
    _VariableDef('threadCacheSize', 'thread_cache_size'),
    _VariableDef('threadStackSize', 'thread_stack'),
  ]),
  _VariableGroup('缓冲', [
    _VariableDef('joinBufferSize', 'join_buffer_size'),
    _VariableDef('sortBufferSize', 'sort_buffer_size'),
    _VariableDef('readBufferSize', 'read_buffer_size'),
    _VariableDef('readRndBufferSize', 'read_rnd_buffer_size'),
    _VariableDef('tmpTableSize', 'tmp_table_size'),
    _VariableDef('maxHeapTableSize', 'max_heap_table_size'),
  ]),
  _VariableGroup('InnoDB', [
    _VariableDef('innodbBufferPoolSize', 'innodb_buffer_pool_size'),
    _VariableDef('innodbLogBufferSize', 'innodb_log_buffer_size'),
  ]),
  _VariableGroup('查询', [
    _VariableDef('keyBufferSize', 'key_buffer_size'),
    _VariableDef('tableOpenCache', 'table_open_cache'),
    _VariableDef('queryCacheSize', 'query_cache_size'),
    _VariableDef('queryCacheType', 'query_cache_type'),
  ]),
  _VariableGroup('其他', [_VariableDef('binlogCacheSize', 'binlog_cache_size')]),
];

class _VariableGroup {
  final String title;
  final List<_VariableDef> vars;

  const _VariableGroup(this.title, this.vars);
}

class _PerformancePageState extends ConsumerState<DatabasePerformancePage> {
  MysqlVariables? _variables;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  final Map<String, TextEditingController> _controllers = {};

  DatabaseService get _svc => ref.read(databaseServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vars = await _svc.loadVariables(widget.inst);
      if (!mounted) return;
      _initControllers(vars);
      setState(() {
        _variables = vars;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _initControllers(MysqlVariables vars) {
    final values = _toMap(vars);
    for (final group in _groups) {
      for (final def in group.vars) {
        _controllers[def.key] = TextEditingController(
          text: values[def.key] ?? '',
        );
      }
    }
  }

  Map<String, String> _toMap(MysqlVariables v) => {
    'binlogCacheSize': v.binlogCacheSize ?? '',
    'innodbBufferPoolSize': v.innodbBufferPoolSize ?? '',
    'innodbLogBufferSize': v.innodbLogBufferSize ?? '',
    'joinBufferSize': v.joinBufferSize ?? '',
    'keyBufferSize': v.keyBufferSize ?? '',
    'longQueryTime': v.longQueryTime ?? '',
    'maxConnections': v.maxConnections ?? '',
    'maxHeapTableSize': v.maxHeapTableSize ?? '',
    'queryCacheSize': v.queryCacheSize ?? '',
    'queryCacheType': v.queryCacheType ?? '',
    'readBufferSize': v.readBufferSize ?? '',
    'readRndBufferSize': v.readRndBufferSize ?? '',
    'slowQueryLog': v.slowQueryLog ?? '',
    'sortBufferSize': v.sortBufferSize ?? '',
    'tableOpenCache': v.tableOpenCache ?? '',
    'threadCacheSize': v.threadCacheSize ?? '',
    'threadStackSize': v.threadStackSize ?? '',
    'tmpTableSize': v.tmpTableSize ?? '',
  };

  List<Map<String, dynamic>> _collectChanged() {
    final original = _toMap(_variables!);
    final changed = <Map<String, dynamic>>[];
    for (final group in _groups) {
      for (final def in group.vars) {
        final newValue = _controllers[def.key]!.text;
        if (newValue != original[def.key]) {
          changed.add({'key': def.key, 'value': newValue});
        }
      }
    }
    return changed;
  }

  Future<void> _save() async {
    final changed = _collectChanged();
    if (changed.isEmpty) {
      _snack('没有变更');
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.updateVariables(widget.inst, changed);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('参数已保存', green: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('保存失败: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('性能调优'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text('$_error', style: const TextStyle(color: Colors.red)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (context, i) => _buildGroup(_groups[i]),
            ),
    );
  }

  Widget _buildGroup(_VariableGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < group.vars.length; i++)
                  _buildTile(group.vars[i], isLast: i == group.vars.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_VariableDef def, {required bool isLast}) {
    final controller = _controllers[def.key]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              def.label,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
