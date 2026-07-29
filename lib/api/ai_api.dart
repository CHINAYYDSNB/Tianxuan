import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';

/// OpenAI 兼容聊天 API
class AiApi {
  final AiConfig config;
  final http.Client _client;

  AiApi(this.config, {http.Client? client}) : _client = client ?? http.Client();

  void dispose() => _client.close();

  /// 非流式聊天补全
  Future<String> chat(List<Map<String, String>> messages) async {
    final url = Uri.parse('${config.endpoint}/chat/completions');
    final resp = await _client.post(
      url,
      headers: _headers,
      body: _body(messages),
    );
    if (resp.statusCode != 200) {
      throw Exception('AI API error ${resp.statusCode}: ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map;
    final choices = json['choices'] as List;
    if (choices.isEmpty) throw Exception('AI: empty response');
    return (choices[0] as Map)['message']['content'] as String? ?? '';
  }

  /// 流式聊天补全 — SSE 行流
  Stream<String> chatStream(List<Map<String, String>> messages) async* {
    final url = Uri.parse('${config.endpoint}/chat/completions');
    final body = _body(messages, stream: true);
    final request = http.Request('POST', url)
      ..headers.addAll(_headers)
      ..body = body;

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final err = await response.stream.bytesToString();
      throw Exception('AI API error ${response.statusCode}: $err');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map;
            final choices = json['choices'] as List? ?? [];
            if (choices.isEmpty) continue;
            final delta = (choices[0] as Map)['delta'] as Map? ?? {};
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {
            // skip malformed SSE line
          }
        }
      }
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  };

  String _body(List<Map<String, String>> messages, {bool stream = false}) {
    final m = messages
        .map((msg) => {'role': msg['role'], 'content': msg['content']})
        .toList();
    return jsonEncode({
      'model': config.model,
      'messages': m,
      'stream': stream,
      'temperature': 0.7,
    });
  }
}
