// GEETEST v4 人机验证封装
// 使用官方 gt4_flutter_plugin；captchaId 从 Casdoor 应用配置获取。
// Web 平台无原生插件支持，返回未验证。
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gt4_flutter_plugin/gt4_flutter_plugin.dart';
import 'package:gt4_flutter_plugin/gt4_session_configuration.dart';

/// 极验验证结果（与 Casdoor GEETEST provider 需要的 token 字段一致）
class GeeTestResult {
  final String lotNumber;
  final String captchaOutput;
  final String passToken;
  final String genTime;

  const GeeTestResult({
    required this.lotNumber,
    required this.captchaOutput,
    required this.passToken,
    required this.genTime,
  });

  /// Casdoor 期望的 captchaToken（query-string 格式）
  String get captchaToken =>
      'lot_number=$lotNumber&captcha_output=$captchaOutput'
      '&pass_token=$passToken&gen_time=$genTime';

  static GeeTestResult? fromMap(Map<String, dynamic> result) {
    String s(String key) => result[key]?.toString() ?? '';
    if (s('lot_number').isEmpty) return null;
    return GeeTestResult(
      lotNumber: s('lot_number'),
      captchaOutput: s('captcha_output'),
      passToken: s('pass_token'),
      genTime: s('gen_time'),
    );
  }
}

/// GEETEST 验证服务
class GeeTestService {
  /// 是否支持原生极验（仅 Android/iOS）
  static bool get isSupported => !kIsWeb;

  /// 发起极验验证。
  /// [captchaId] 为极验分配的验证 ID（从 Casdoor 应用配置的 captcha provider 获取）。
  /// 返回验证结果；失败或取消返回 null。
  static Future<GeeTestResult?> verify(String captchaId) async {
    if (!isSupported || captchaId.isEmpty) return null;

    final completer = Completer<GeeTestResult?>();
    final config = GT4SessionConfiguration();
    config.language = 'zh';
    config.debugEnable = false;

    final plugin = Gt4FlutterPlugin(captchaId, config);
    plugin.addEventHandler(
      onShow: (msg) async {},
      onError: (msg) async {
        if (!completer.isCompleted) completer.complete(null);
      },
      onResult: (msg) async {
        final status = msg['status']?.toString();
        if (status == '1') {
          final result = msg['result'];
          if (result is Map) {
            if (!completer.isCompleted) {
              completer.complete(
                GeeTestResult.fromMap(Map<String, dynamic>.from(result)),
              );
            }
            return;
          }
        }
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    plugin.verify();
    // 设置超时兜底（30s），避免回调丢失导致永久挂起
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => null,
    );
  }
}
