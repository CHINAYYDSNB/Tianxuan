import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/update_service.dart';
import '../../utils/url_launcher.dart';
import 'contributors_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      const Icon(Icons.tag, size: 16, color: Color(0xFFAAB4BF)),
                      const SizedBox(width: 4),
                      Text(UpdateService.currentVersion, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              subtitle: const Text('CHINAYYDSNB/Tianxuan'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(UpdateService.repoUrl),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people, color: Colors.blue),
              title: const Text('贡献者'),
              subtitle: const Text('感谢为项目做出贡献的开发者'),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributorsPage())),
            ),
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) => openUrl(url);
}
