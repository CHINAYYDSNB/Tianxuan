import '../models/website.dart';
import 'client.dart';

class WebsiteApi {
  /// List all websites (brief)
  static Future<List<Website>> getList() async {
    final res = await ApiClient.instance.get('/websites/list');
    final list = res.data['data'] as List? ?? [];
    return list.map((e) => Website.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Search websites with pagination
  static Future<Map<String, dynamic>> search({
    int page = 1,
    int pageSize = 20,
    String orderBy = 'createdAt',
    String order = 'ascending',
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      'orderBy': orderBy,
      'order': order,
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    final res = await ApiClient.instance.post('/websites/search', data: params);
    final data = res.data['data'] as Map? ?? {};
    final items = (data['items'] as List?)?.map(
          (e) => Website.fromJson(e as Map<String, dynamic>),
        ) ??
        <Website>[];
    return {'total': data['total'] ?? 0, 'items': items};
  }

  /// Get website detail by id
  static Future<Website> getDetail(int id) async {
    final res = await ApiClient.instance.get('/websites/$id');
    final raw = res.data['data'];
    final data = (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    return Website.fromJson(data);
  }

  /// Create website
  /// Returns website ID on success
  static Future<int> create(WebsiteCreateRequest req) async {
    await ApiClient.instance.post('/websites', data: req.toJson());
    // Fetch latest to get the new site ID
    final list = await getList();
    final match = list.where((w) => w.alias == req.alias).toList();
    if (match.isNotEmpty) return match.first.id;
    return 0;
  }

  /// Delete website
  static Future<void> delete(int id) async {
    await ApiClient.instance.post('/websites/del', data: {'id': id});
  }

  /// Operate website: start / stop / restart
  static Future<void> operate(int id, String action) async {
    await ApiClient.instance.post('/websites/operate', data: {
      'id': id,
      'operate': action,
    });
  }

  /// Update website basic info
  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.post('/websites/update', data: {
      'id': id,
      ...data,
    });
  }

  /// Check domain before create
  static Future<bool> check(String primaryDomain, String type) async {
    final res = await ApiClient.instance.post('/websites/check', data: {
      'primaryDomain': primaryDomain,
      'type': type,
    });
    return res.data['code'] == 200;
  }

  // ─── Nginx Config ───

  /// Get nginx config
  static Future<String?> getConfig(int websiteId, {String scope = 'all'}) async {
    final res = await ApiClient.instance.post('/websites/config', data: {
      'websiteID': websiteId,
      'scope': scope,
    });
    final data = res.data['data'];
    if (data is Map && data['content'] != null) {
      return data['content'].toString();
    }
    return null;
  }

  /// Update nginx config
  static Future<void> updateNginx(int id, String content, {String scope = 'nginx'}) async {
    await ApiClient.instance.post('/websites/nginx/update', data: {
      'id': id,
      'content': content,
      'scope': scope,
    });
  }

  // ─── HTTPS ───

  /// Get HTTPS config
  static Future<Map<String, dynamic>> getHttps(int id) async {
    final res = await ApiClient.instance.get('/websites/$id/https');
    final raw = res.data['data'];
    return (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  /// Update HTTPS config
  static Future<void> updateHttps(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.post('/websites/$id/https', data: data);
  }

  // ─── Logs ───

  /// Read website log
  /// [logType]: 'access' or 'error'
  /// [operate]: 'read' or others
  static Future<Map<String, dynamic>> getLog(int id, String logType, {String operate = 'read'}) async {
    final res = await ApiClient.instance.post('/websites/log', data: {
      'id': id,
      'logType': logType,
      'operate': operate,
    });
    final raw = res.data['data'];
    return (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  // ─── Directory ───

  /// Get available directories under website root
  static Future<Map<String, dynamic>> getDir(int id) async {
    final res = await ApiClient.instance.post('/websites/dir', data: {
      'id': id,
    });
    final raw = res.data['data'];
    return (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  // ─── Other ───

  /// Get available PHP versions
  static Future<List<String>> getPhpVersions() async {
    try {
      final res = await ApiClient.instance.post('/runtimes/installed/delete/check', data: {});
      final data = res.data['data'];
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return ['php74', 'php80', 'php81', 'php82', 'php83', 'php84'];
  }

  /// List website names (for dropdowns)
  static Future<List<Map<String, dynamic>>> getOptions() async {
    final res = await ApiClient.instance.post('/websites/options', data: {});
    final data = res.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
