import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ai_provider.dart';

class AiConfigPage extends ConsumerStatefulWidget {
  const AiConfigPage({super.key});

  @override
  ConsumerState<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends ConsumerState<AiConfigPage> {
  late TextEditingController _endpointCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiConfigProvider);
    _endpointCtrl = TextEditingController(text: config.endpoint);
    _keyCtrl = TextEditingController(text: config.apiKey);
    _modelCtrl = TextEditingController(text: config.model);
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API 配置', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _endpointCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Endpoint',
                      hintText: 'https://api.openai.com/v1',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => ref.read(aiConfigProvider.notifier).updateEndpoint(v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    obscureText: true,
                    onChanged: (v) => ref.read(aiConfigProvider.notifier).updateApiKey(v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(
                      labelText: '模型',
                      hintText: 'gpt-4o-mini',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => ref.read(aiConfigProvider.notifier).updateModel(v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        config.isValid ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: config.isValid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        config.isValid ? '配置有效，可以使用 AI 助手' : '请填写完整配置',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('推荐模型', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('gpt-4o-mini — 快速便宜，适合日常使用',
                      style: theme.textTheme.bodySmall),
                  Text('gpt-4o — 更强能力，适合复杂分析',
                      style: theme.textTheme.bodySmall),
                  Text('DeepSeek / Claude 等兼容接口也可用',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
