/// AI 供应商模板
class AiProviderTemplate {
  final String id;
  final String name;
  final String endpoint; // base URL，不含 /chat/completions
  final List<String> models;
  final String? notes;

  const AiProviderTemplate({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.models,
    this.notes,
  });
}

/// 主流 AI 供应商模板列表
const aiProviderTemplates = <AiProviderTemplate>[
  AiProviderTemplate(
    id: 'openai',
    name: 'OpenAI',
    endpoint: 'https://api.openai.com/v1',
    models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
    notes: 'ChatGPT 官方接口，需要海外网络访问',
  ),
  AiProviderTemplate(
    id: 'deepseek',
    name: 'DeepSeek',
    endpoint: 'https://api.deepseek.com/v1',
    models: ['deepseek-chat', 'deepseek-reasoner'],
    notes: '国内直连，性价比高',
  ),
  AiProviderTemplate(
    id: 'anthropic',
    name: 'Anthropic Claude',
    endpoint: 'https://api.anthropic.com/v1',
    models: ['claude-3-5-sonnet', 'claude-3-5-haiku', 'claude-3-opus'],
    notes: 'Claude 官方接口，需要海外网络访问',
  ),
  AiProviderTemplate(
    id: 'gemini',
    name: 'Google Gemini',
    endpoint: 'https://generativelanguage.googleapis.com/v1beta',
    models: ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro'],
    notes: 'Google 官方接口',
  ),
  AiProviderTemplate(
    id: 'qwen',
    name: '通义千问 (阿里)',
    endpoint: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-max', 'qwen-plus', 'qwen-turbo'],
    notes: '阿里云百炼，国内直连',
  ),
  AiProviderTemplate(
    id: 'kimi',
    name: 'Kimi (月之暗面)',
    endpoint: 'https://api.moonshot.cn/v1',
    models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
    notes: '月之暗面 Kimi，国内直连',
  ),
  AiProviderTemplate(
    id: 'baidu',
    name: '百度千帆',
    endpoint: 'https://qianfan.baidubce.com/v2',
    models: ['ernie-4.0-turbo-8k', 'ernie-3.5-8k'],
    notes: '百度千帆大模型平台',
  ),
  AiProviderTemplate(
    id: 'zhipu',
    name: '智谱 GLM',
    endpoint: 'https://open.bigmodel.cn/api/paas/v4',
    models: ['glm-4', 'glm-4-flash', 'glm-3-turbo'],
    notes: '智谱清言，国内直连',
  ),
  AiProviderTemplate(
    id: 'custom',
    name: '自定义',
    endpoint: '',
    models: [],
    notes: '兼容 OpenAI 接口的任意地址。注意：自定义地址可能将对话数据发送到不受信任的服务器，请谨慎使用！',
  ),
];

/// 自定义模板 ID
const kCustomTemplateId = 'custom';
