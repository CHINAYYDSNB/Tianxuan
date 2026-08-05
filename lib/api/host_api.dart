import 'package:dio/dio.dart';
import 'client.dart';

/// 系统设备配置（/toolbox/device/conf）
class DeviceConf {
  final List<String> dns;
  final List<Map<String, String>> hosts;
  final String hostname;
  final String timeZone;
  final String ntp;
  final String systemTime;
  final int swapMemoryTotal;
  final int swapMemoryUsed;

  const DeviceConf({
    this.dns = const [],
    this.hosts = const [],
    this.hostname = '',
    this.timeZone = '',
    this.ntp = '',
    this.systemTime = '',
    this.swapMemoryTotal = 0,
    this.swapMemoryUsed = 0,
  });

  bool get hasSwap => swapMemoryTotal > 0;

  factory DeviceConf.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) => json[key] is List
        ? (json[key] as List).map((e) => e.toString()).toList()
        : [];
    List<Map<String, String>> hosts = [];
    if (json['hosts'] is List) {
      hosts = (json['hosts'] as List)
          .whereType<Map>()
          .map(
            (e) => Map<String, String>.from(
              e.map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
          )
          .toList();
    }
    return DeviceConf(
      dns: list('dns'),
      hosts: hosts,
      hostname: json['hostname']?.toString() ?? '',
      timeZone: json['timeZone']?.toString() ?? '',
      ntp: json['ntp']?.toString() ?? '',
      systemTime: json['systemTime']?.toString() ?? '',
      swapMemoryTotal: (json['swapMemoryTotal'] as num?)?.toInt() ?? 0,
      swapMemoryUsed: (json['swapMemoryUsed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 1Panel host 系统配置 API（API 优先，SSH fallback 由调用方处理）
class HostApi {
  /// POST /toolbox/device/conf — 读取设备配置（DNS/Hosts/主机名/时区/NTP/Swap）
  static Future<DeviceConf> getDeviceConf() async {
    final res = await ApiClient.instance.post('/toolbox/device/conf');
    final data = _dataOf(res);
    if (data is Map) {
      return DeviceConf.fromJson(Map<String, dynamic>.from(data));
    }
    return const DeviceConf();
  }

  /// POST /toolbox/device/update/host — 修改主机名
  static Future<void> updateHostname(String hostname) async {
    final res = await ApiClient.instance.post(
      '/toolbox/device/update/host',
      data: {'hostname': hostname},
    );
    _checkCode(res);
  }

  /// POST /toolbox/device/update/conf — 更新 DNS / 时区 / NTP
  static Future<void> updateDeviceConf({
    List<String>? dns,
    String? timeZone,
    String? ntp,
  }) async {
    final res = await ApiClient.instance.post(
      '/toolbox/device/update/conf',
      data: {
        if (dns != null) 'dns': dns,
        if (timeZone != null) 'timeZone': timeZone,
        if (ntp != null) 'ntp': ntp,
      },
    );
    _checkCode(res);
  }

  /// POST /toolbox/device/update/passwd — 修改系统密码
  static Future<void> updatePasswd(String passwd) async {
    final res = await ApiClient.instance.post(
      '/toolbox/device/update/passwd',
      data: {'passwd': passwd},
    );
    _checkCode(res);
  }

  /// POST /toolbox/device/update/swap — 修改 Swap
  static Future<void> updateSwap(int sizeMB) async {
    final res = await ApiClient.instance.post(
      '/toolbox/device/update/swap',
      data: {'size': sizeMB},
    );
    _checkCode(res);
  }

  /// GET /toolbox/device/zone/options — 时区选项
  static Future<List<String>> getTimeZones() async {
    final res = await ApiClient.instance.get('/toolbox/device/zone/options');
    final data = _dataOf(res);
    if (data is Map && data['zones'] is List) {
      return (data['zones'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// POST /toolbox/device/check/dns — 检测 DNS
  static Future<Map<String, dynamic>> checkDns(String domain) async {
    final res = await ApiClient.instance.post(
      '/toolbox/device/check/dns',
      data: {'domain': domain},
    );
    final data = _dataOf(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// POST /settings/search — 服务器时间等
  static Future<Map<String, dynamic>> getSettings() async {
    final res = await ApiClient.instance.post('/settings/search');
    final data = _dataOf(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static dynamic _dataOf(Response res) {
    final data = res.data;
    if (data is Map) {
      if (data.containsKey('code') && data['code'] != 200) {
        throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
      }
      return data['data'];
    }
    return null;
  }

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
    }
  }
}
