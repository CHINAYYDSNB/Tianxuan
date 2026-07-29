import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ai_api.dart';
import '../api/dashboard_api.dart';
import '../models/ai_config.dart';
import '../models/server_status.dart';

/// AI 聊天消息
class AiMessage {
  final String role; // user / assistant / system
  final String content;
  final DateTime timestamp;

  AiMessage({required this.role, required this.content, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, String> toApiMap() => {'role': role, 'content': content};
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// AI 配置持久化
class AiConfigNotifier extends StateNotifier<AiConfig> {
  AiConfigNotifier() : super(const AiConfig()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('ai_config');
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = AiConfig.fromJson(json);
      }
    } catch (_) {}
  }

  Future<void> save(AiConfig config) async {
    state = config;
    final p = await SharedPreferences.getInstance();
    await p.setString('ai_config', jsonEncode(config.toJson()));
  }

  Future<void> updateEndpoint(String v) async =>
      save(state.copyWith(endpoint: v));
  Future<void> updateApiKey(String v) async => save(state.copyWith(apiKey: v));
  Future<void> updateModel(String v) async => save(state.copyWith(model: v));
}

final aiConfigProvider = StateNotifierProvider<AiConfigNotifier, AiConfig>(
  (ref) => AiConfigNotifier(),
);

/// 聊天状态
class AiChatNotifier extends StateNotifier<List<AiMessage>> {
  AiChatNotifier() : super([]) {
    _loadHistory();
  }

  static const _maxHistory = 50;

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('ai_chat_history');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        state = list.map(AiMessage.fromJson).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final trimmed = state.length > _maxHistory
          ? state.sublist(state.length - _maxHistory)
          : state;
      await p.setString(
        'ai_chat_history',
        jsonEncode(trimmed.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  void addMessage(AiMessage msg) {
    state = [...state, msg];
    _saveHistory();
  }

  /// 追加到最后一条消息（用于流式拼接）
  void appendToLast(String chunk) {
    if (state.isEmpty) return;
    final last = state.last;
    final updated = AiMessage(role: last.role, content: last.content + chunk);
    state = [...state.sublist(0, state.length - 1), updated];
  }

  void clear() {
    state = [];
    _saveHistory();
  }

  /// 获取 AI 系统提示词（含服务器上下文）
  Future<String> buildSystemPrompt() async {
    try {
      final status = await DashboardApi.getStatus();
      return _systemPromptWithStatus(status);
    } catch (_) {
      return _systemPromptWithStatus(null);
    }
  }

  String _systemPromptWithStatus(ServerStatus? status) {
    final buf = StringBuffer('你是 Tianxuan AI 助手，帮助用户管理 1Panel 服务器。');
    buf.write('\n回答简洁准确，用中文。');

    if (status != null) {
      buf.write('\n\n当前服务器状态：');
      buf.write('\n- 运行时间: ${status.uptime}');
      buf.write('\n- CPU: ${status.cpuUsage.toStringAsFixed(1)}%');
      buf.write(
        '\n- 内存: ${status.memoryUsage.toStringAsFixed(1)}%（${status.memoryUsed}/${status.memoryTotal}）',
      );
      buf.write(
        '\n- 磁盘: ${status.diskUsage.toStringAsFixed(1)}%（${status.diskUsed}/${status.diskTotal}）',
      );
      buf.write('\n- 操作系统: ${status.platform}');
      buf.write('\n- 主机名: ${status.hostname}');
    }

    buf.write('\n\n你可以问：服务器状态、文件管理、容器、网站、Docker 相关问题。');
    return buf.toString();
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, List<AiMessage>>(
  (ref) => AiChatNotifier(),
);

/// 发送消息 → 流式响应
final aiSendProvider = Provider<AiSend>((ref) => AiSend(ref));

class AiSend {
  final Ref _ref;
  AiSend(this._ref);

  Future<void> call(String text) async {
    final chat = _ref.read(aiChatProvider.notifier);
    final config = _ref.read(aiConfigProvider);

    if (!config.isValid) throw Exception('请先配置 AI 接口');

    chat.addMessage(AiMessage(role: 'user', content: text));
    chat.addMessage(AiMessage(role: 'assistant', content: ''));

    final api = AiApi(config);
    try {
      final system = await chat.buildSystemPrompt();
      final msgs = [
        {'role': 'system', 'content': system},
        ..._ref
            .read(aiChatProvider)
            .where((m) => m.role != 'system')
            .map((m) => m.toApiMap()),
      ];

      await for (final chunk in api.chatStream(msgs)) {
        chat.appendToLast(chunk);
      }
    } catch (e) {
      chat.appendToLast('\n\n[错误: $e]');
    } finally {
      api.dispose();
    }
  }
}
