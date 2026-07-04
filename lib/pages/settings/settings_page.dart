import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/health_provider.dart';
import '../../api/client.dart';
import '../../services/storage_service.dart';
import '../../services/logto_service.dart';
import '../../services/update_service.dart';
import '../../utils/url_launcher.dart';
import 'cloud_backup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart), text: '健康检测'),
            Tab(icon: Icon(Icons.wifi_find), text: '连接检测'),
            Tab(icon: Icon(Icons.cloud), text: '云备份'),
            Tab(icon: Icon(Icons.info_outline), text: '关于'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _HealthTab(),
          _ConnectionTab(),
          CloudBackupPage(),
          _AboutTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 健康检测 Tab
// ═══════════════════════════════════════════

class _HealthTab extends ConsumerWidget {
  const _HealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final thresholds = ref.watch(healthThresholdsProvider);

    return health.when(
      data: (status) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _overallIcon(status.overallLevel),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('服务器健康状态',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(status.checkedAt.toString().substring(0, 19),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const Spacer(),
                  if (status.criticalCount > 0)
                    Chip(label: Text('${status.criticalCount} 严重',
                        style: const TextStyle(color: Colors.red, fontSize: 12))),
                  if (status.warningCount > 0)
                    Chip(label: Text('${status.warningCount} 警告',
                        style: const TextStyle(color: Colors.orange, fontSize: 12))),
                  if (status.criticalCount == 0 && status.warningCount == 0)
                    const Chip(label: Text('正常', style: TextStyle(color: Colors.green, fontSize: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 指标卡片
          ...status.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HealthCard(item: item),
          )),
          const SizedBox(height: 24),

          // 阈值设置
          Text('告警阈值设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ThresholdSlider(
                    label: 'CPU 警告',
                    value: thresholds.cpuWarning.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, cpuWarning: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, cpuWarning: v.toInt()),
                  ),
                  _ThresholdSlider(
                    label: 'CPU 严重',
                    value: thresholds.cpuCritical.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, cpuCritical: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, cpuCritical: v.toInt()),
                  ),
                  const Divider(height: 24),
                  _ThresholdSlider(
                    label: '内存 警告',
                    value: thresholds.memWarning.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, memWarning: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, memWarning: v.toInt()),
                  ),
                  _ThresholdSlider(
                    label: '内存 严重',
                    value: thresholds.memCritical.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, memCritical: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, memCritical: v.toInt()),
                  ),
                  const Divider(height: 24),
                  _ThresholdSlider(
                    label: '磁盘 警告',
                    value: thresholds.diskWarning.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, diskWarning: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, diskWarning: v.toInt()),
                  ),
                  _ThresholdSlider(
                    label: '磁盘 严重',
                    value: thresholds.diskCritical.toDouble(),
                    onChanged: (v) => _updateThresholdLive(ref, thresholds, diskCritical: v.toInt()),
                    onChangeEnd: (v) => _updateThresholdFinal(ref, thresholds, diskCritical: v.toInt()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          Text('加载失败: $e'),
          FilledButton(onPressed: () => ref.read(healthProvider.notifier).refresh(), child: const Text('重试')),
        ],
      )),
    );
  }

  Widget _overallIcon(HealthLevel level) {
    return Icon(
      switch (level) {
        HealthLevel.ok => Icons.check_circle,
        HealthLevel.warning => Icons.warning_amber,
        HealthLevel.critical => Icons.error,
      },
      size: 40,
      color: switch (level) {
        HealthLevel.ok => Colors.green,
        HealthLevel.warning => Colors.orange,
        HealthLevel.critical => Colors.red,
      },
    );
  }

  void _updateThresholdLive(WidgetRef ref, HealthThresholds t,
      {int? cpuWarning, int? cpuCritical, int? memWarning, int? memCritical,
       int? diskWarning, int? diskCritical}) {
    ref.read(healthThresholdsProvider.notifier).state = t.copyWith(
      cpuWarning: cpuWarning, cpuCritical: cpuCritical,
      memWarning: memWarning, memCritical: memCritical,
      diskWarning: diskWarning, diskCritical: diskCritical,
    );
  }

  void _updateThresholdFinal(WidgetRef ref, HealthThresholds t,
      {int? cpuWarning, int? cpuCritical, int? memWarning, int? memCritical,
       int? diskWarning, int? diskCritical}) {
    _updateThresholdLive(ref, t,
      cpuWarning: cpuWarning, cpuCritical: cpuCritical,
      memWarning: memWarning, memCritical: memCritical,
      diskWarning: diskWarning, diskCritical: diskCritical,
    );
    // 拖完才触发重检
    ref.read(healthProvider.notifier).refresh();
  }
}

class _ThresholdSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _ThresholdSlider({
    required this.label, required this.value, required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Slider(
              value: value,
              min: 50,
              max: 99,
              divisions: 49,
              label: '${value.toInt()}%',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd ?? onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text('${value.toInt()}%', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final HealthItem item;
  const _HealthCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      HealthLevel.ok => Colors.green,
      HealthLevel.warning => Colors.orange,
      HealthLevel.critical => Colors.red,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 60, height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: item.level == HealthLevel.ok ? item.value / 100 : item.value / 100,
                    strokeWidth: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                  ),
                  Text('${item.value.toStringAsFixed(0)}${item.unit}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (item.detail.isNotEmpty)
                    Text(item.detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              switch (item.level) {
                HealthLevel.ok => Icons.check_circle,
                HealthLevel.warning => Icons.warning_amber,
                HealthLevel.critical => Icons.error,
              },
              color: color, size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 关于 Tab — 版本 + GitHub 更新
// ═══════════════════════════════════════════

class _AboutTab extends StatefulWidget {
  const _AboutTab();

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  bool _checking = false;
  ({String tag, String url, bool newer})? _result;
  String? _error;

  Future<void> _checkUpdate() async {
    setState(() { _checking = true; _error = null; _result = null; });
    try {
      final r = await UpdateService.check();
      if (!mounted) return;
      setState(() { _result = r; _checking = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // App icon + name
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/Tianxuan.svg',
                  width: 72,
                  height: 72,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Tianxuan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('1Panel 第三方管理器', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.tag, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(UpdateService.currentVersion, style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Update check
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('版本更新', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),

                if (_result != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _result!.newer ? Icons.system_update : Icons.check_circle,
                        color: _result!.newer ? Colors.orange : Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _result!.newer ? '新版本可用: ${_result!.tag}' : '已是最新版本',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_result!.newer)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(_result!.url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('前往下载'),
                      ),
                    ),
                ],

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onErrorContainer)),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checking ? null : _checkUpdate,
                    icon: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_checking ? '检查中...' : '检查更新'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // GitHub link
        Card(
          child: ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text('CHINAYYDSNB/Tianxuan'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(UpdateService.repoUrl),
          ),
        ),
        const SizedBox(height: 24),
        _LogtoStatusCard(),
      ],
    );
  }

  void _openUrl(String url) => openUrl(url);
}

class _LogtoStatusCard extends StatefulWidget {
  @override
  State<_LogtoStatusCard> createState() => _LogtoStatusCardState();
}

class _LogtoStatusCardState extends State<_LogtoStatusCard> {
  bool _loggedIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await LogtoService.isLoggedIn;
    if (mounted) setState(() { _loggedIn = ok; _loading = false; });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登出'),
        content: const Text('确定要登出 Logto 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('登出')),
        ],
      ),
    );
    if (ok != true) return;

    await LogtoService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: Icon(
          _loggedIn ? Icons.lock : Icons.lock_open,
          color: _loggedIn ? Colors.green : Colors.grey,
        ),
        title: Text(_loggedIn ? 'Logto 已登录' : 'Logto 未登录'),
        subtitle: Text(_loggedIn ? '点击登出' : '返回首页可登录'),
        trailing: _loggedIn
            ? IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: _logout,
              )
            : null,
        onTap: _loggedIn ? _logout : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 连接检测 Tab
// ═══════════════════════════════════════════

class _ConnectionTab extends ConsumerStatefulWidget {
  const _ConnectionTab();

  @override
  ConsumerState<_ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends ConsumerState<_ConnectionTab> {
  bool _testing = false;
  String? _apiUrl;
  int? _latencyMs;
  bool? _apiOk;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await StorageService.instance.getServerUrl();
    if (mounted) setState(() => _apiUrl = url);
  }

  Future<void> _runTest() async {
    setState(() { _testing = true; _error = null; _apiOk = null; _latencyMs = null; });

    try {
      final start = DateTime.now();
      final res = await ApiClient.instance.get('/dashboard/base/0/0');
      final ms = DateTime.now().difference(start).inMilliseconds;

      setState(() {
        _latencyMs = ms;
        _apiOk = res.data['code'] == 200;
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _apiOk = false;
        _error = e.toString();
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.wifi_find, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('API 连接检测', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_apiUrl != null)
                  Text(_apiUrl!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 24),

                // 结果
                if (_latencyMs != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_apiOk == true ? Icons.check_circle : Icons.error,
                          color: _apiOk == true ? Colors.green : Colors.red, size: 32),
                      const SizedBox(width: 12),
                      Text(_apiOk == true ? '连接正常' : '连接失败',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('响应时间: $_latencyMs ms',
                      style: theme.textTheme.bodyMedium),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onErrorContainer)),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _testing ? null : _runTest,
                    icon: _testing
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_testing ? '测试中...' : '运行检测'),
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
