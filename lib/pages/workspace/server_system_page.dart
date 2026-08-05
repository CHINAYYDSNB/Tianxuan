import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/host_api.dart';

/// 服务器系统设置页（1Panel API：DNS / Hosts / 主机名 / 密码 / NTP / 时区 / Swap）
class ServerSystemPage extends ConsumerStatefulWidget {
  const ServerSystemPage({super.key});

  @override
  ConsumerState<ServerSystemPage> createState() => _ServerSystemPageState();
}

class _ServerSystemPageState extends ConsumerState<ServerSystemPage> {
  DeviceConf? _conf;
  Map<String, dynamic> _settings = {};
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
      final conf = await HostApi.getDeviceConf();
      final settings = await HostApi.getSettings();
      if (!mounted) return;
      setState(() {
        _conf = conf;
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _editHostname() async {
    final current = _conf?.hostname ?? '';
    final ctrl = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改主机名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '主机名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == current) return;
    try {
      await HostApi.updateHostname(newName);
      if (mounted) {
        _showOk('主机名已更新');
        _load();
      }
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _editNtp() async {
    final current = _conf?.ntp ?? '';
    final ctrl = TextEditingController(text: current);
    final newNtp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改 NTP 服务器'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'NTP 地址'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newNtp == null || newNtp.isEmpty || newNtp == current) return;
    try {
      await HostApi.updateDeviceConf(ntp: newNtp);
      if (mounted) {
        _showOk('NTP 已更新');
        _load();
      }
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _editPasswd() async {
    final ctrl = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改系统密码'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newPass == null || newPass.isEmpty) return;
    try {
      await HostApi.updatePasswd(newPass);
      if (mounted) _showOk('系统密码已更新');
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _pickTimeZone() async {
    try {
      final zones = await HostApi.getTimeZones();
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => ListView.builder(
          itemCount: zones.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(zones[i]),
            onTap: () => Navigator.pop(ctx, zones[i]),
          ),
        ),
      );
      if (selected == null || selected == _conf?.timeZone) return;
      await HostApi.updateDeviceConf(timeZone: selected);
      if (mounted) {
        _showOk('时区已更新');
        _load();
      }
    } catch (e) {
      _showErr(e);
    }
  }

  void _showOk(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final conf = _conf;

    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Column(
                      children: [
                        _row(
                          Icons.computer,
                          '主机名',
                          conf?.hostname ?? '-',
                          onTap: _editHostname,
                        ),
                        _row(
                          Icons.watch_later_outlined,
                          '服务器时间',
                          _settings['serverTime']?.toString() ??
                              conf?.systemTime ??
                              '-',
                        ),
                        _row(
                          Icons.public,
                          '时区',
                          conf?.timeZone ?? '-',
                          onTap: _pickTimeZone,
                        ),
                        _row(
                          Icons.schedule,
                          'NTP 服务器',
                          conf?.ntp ?? '-',
                          onTap: _editNtp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _row(
                          Icons.dns_outlined,
                          'DNS',
                          conf?.dns.isEmpty ?? true
                              ? '-'
                              : conf!.dns.join(', '),
                        ),
                        _row(
                          Icons.memory,
                          'Swap',
                          (conf?.hasSwap ?? false)
                              ? '${((conf!.swapMemoryTotal / 1024 / 1024 / 1024).toStringAsFixed(1))} GB'
                              : '未设置',
                        ),
                        _row(
                          Icons.lock_outline,
                          '系统密码',
                          '••••••',
                          onTap: _editPasswd,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hosts / 防火墙等更多系统配置可进入 SSH 终端操作',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9AA1A9)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF))
          : null,
      onTap: onTap,
    );
  }
}
