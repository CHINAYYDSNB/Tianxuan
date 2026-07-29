/// AI 助手配置
class AiConfig {
  final String endpoint; // e.g. https://api.openai.com/v1
  final String apiKey;
  final String model; // e.g. gpt-4o-mini

  const AiConfig({
    this.endpoint = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
  });

  AiConfig copyWith({String? endpoint, String? apiKey, String? model}) {
    return AiConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  bool get isValid =>
      endpoint.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'apiKey': apiKey,
    'model': model,
  };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
    endpoint: json['endpoint'] as String? ?? 'https://api.openai.com/v1',
    apiKey: json['apiKey'] as String? ?? '',
    model: json['model'] as String? ?? 'gpt-4o-mini',
  );
}
