import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ai_provider_template.dart';
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
  String _providerId = 'custom';

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

  Future<void> _selectProvider(AiProviderTemplate tpl) async {
    // 自定义模板：提示数据泄露风险
    if (tpl.id == kCustomTemplateId) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('自定义接口提醒'),
          content: const Text(
            '自定义接口可能将对话内容发送到不受信任的服务器，存在数据泄露风险。\n\n请仅在你信任的服务器上使用自定义接口。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _providerId = tpl.id;
      _endpointCtrl.text = tpl.endpoint;
      if (tpl.models.isNotEmpty) {
        _modelCtrl.text = tpl.models.first;
      }
    });
    ref.read(aiConfigProvider.notifier).updateEndpoint(tpl.endpoint);
    ref.read(aiConfigProvider.notifier).updateModel(_modelCtrl.text);
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
          // 供应商模板
          Text('选择供应商', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: aiProviderTemplates.map((tpl) {
              final selected = _providerId == tpl.id;
              return ChoiceChip(
                label: Text(tpl.name),
                selected: selected,
                onSelected: (_) => _selectProvider(tpl),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

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
                    onChanged: (v) =>
                        ref.read(aiConfigProvider.notifier).updateEndpoint(v),
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
                    onChanged: (v) =>
                        ref.read(aiConfigProvider.notifier).updateApiKey(v),
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
                    onChanged: (v) =>
                        ref.read(aiConfigProvider.notifier).updateModel(v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        config.isValid
                            ? Icons.check_circle
                            : Icons.error_outline,
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

          // 供应商说明
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('供应商说明', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final tpl in aiProviderTemplates)
                    if (tpl.notes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${tpl.name}: ${tpl.notes}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
