import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/ai_provider_template.dart';

void main() {
  test('包含主流 AI 供应商模板', () {
    final ids = aiProviderTemplates.map((t) => t.id).toSet();
    expect(ids.contains('openai'), isTrue);
    expect(ids.contains('deepseek'), isTrue);
    expect(ids.contains('anthropic'), isTrue);
    expect(ids.contains('gemini'), isTrue);
    expect(ids.contains('qwen'), isTrue);
    expect(ids.contains('kimi'), isTrue);
    expect(ids.contains('custom'), isTrue);
  });

  test('每个模板都有 endpoint 和模型', () {
    for (final tpl in aiProviderTemplates) {
      expect(tpl.name, isNotEmpty);
      // 自定义模板允许空 endpoint，其余必须有
      if (tpl.id != kCustomTemplateId) {
        expect(tpl.endpoint, isNotEmpty, reason: '${tpl.name} 缺少 endpoint');
        expect(tpl.models, isNotEmpty, reason: '${tpl.name} 缺少模型');
      }
    }
  });

  test('自定义模板在列表中', () {
    final custom = aiProviderTemplates.firstWhere(
      (t) => t.id == kCustomTemplateId,
    );
    expect(custom.name, '自定义');
  });

  test('模板 ID 唯一', () {
    final ids = aiProviderTemplates.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
