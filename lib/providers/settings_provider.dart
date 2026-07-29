import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/client.dart';
import '../api/dashboard_api.dart';

class SettingsState {
  final bool isConnected;
  final String? serverUrl;
  final String? error;
  final bool loading;

  SettingsState({
    this.isConnected = false,
    this.serverUrl,
    this.error,
    this.loading = false,
  });

  SettingsState copyWith({
    bool? isConnected,
    String? serverUrl,
    String? error,
    bool? loading,
  }) {
    return SettingsState(
      isConnected: isConnected ?? this.isConnected,
      serverUrl: serverUrl ?? this.serverUrl,
      error: error,
      loading: loading ?? this.loading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  Future<void> init() async {
    final hasConfig = await ApiClient.instance.hasConfig();
    if (!hasConfig) return;

    await ApiClient.instance.init();
    // 检查 URL 是否真正加载（避免 SharedPreferences 空值）
    if (ApiClient.instance.serverUrl.isEmpty) {
      debugPrint('Settings init: serverUrl 为空, 跳转登录');
      return;
    }
    // 测试连接是否有效
    try {
      await DashboardApi.getStatus();
      state = SettingsState(isConnected: true);
    } catch (e) {
      debugPrint('Settings init: 连接测试失败 - $e');
      // 配置过期了，让用户重新输入
      state = SettingsState();
    }
  }

  Future<bool> connect(String serverUrl, String apiKey) async {
    state = state.copyWith(loading: true, error: null);

    try {
      // 保存配置并初始化客户端
      await ApiClient.instance.saveConfig(serverUrl, apiKey);

      // 发请求测试连接
      await DashboardApi.getStatus();

      state = SettingsState(isConnected: true, serverUrl: serverUrl);
      return true;
    } catch (e) {
      state = SettingsState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void disconnect() {
    ApiClient.instance.clearConfig();
    state = SettingsState();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
