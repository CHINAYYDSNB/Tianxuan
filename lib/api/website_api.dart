import '../models/website.dart';
import '../models/website_config.dart';
import 'client.dart';

class WebsiteApi {
  // ─── 列表 / 详情 / 基础操作 ───

  /// List all websites (brief)
  static Future<List<Website>> getList() async {
    final res = await ApiClient.instance.get('/websites/list');
    final list = res.data['data'] as List? ?? [];
    return list
        .map((e) => Website.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final items =
        (data['items'] as List?)
            ?.map((e) => Website.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <Website>[];
    return {'total': data['total'] ?? 0, 'items': items};
  }

  /// Get website detail by id
  static Future<Website> getDetail(int id) async {
    final res = await ApiClient.instance.get('/websites/$id');
    final raw = res.data['data'];
    final data = (raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{});
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
    await ApiClient.instance.post(
      '/websites/operate',
      data: {'id': id, 'operate': action},
    );
  }

  /// Update website basic info
  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.post(
      '/websites/update',
      data: {'id': id, ...data},
    );
  }

  /// Check domain before create
  static Future<bool> check(String primaryDomain, String type) async {
    final res = await ApiClient.instance.post(
      '/websites/check',
      data: {'primaryDomain': primaryDomain, 'type': type},
    );
    return res.data['code'] == 200;
  }

  /// List website names (for dropdowns)
  static Future<List<Map<String, dynamic>>> getOptions() async {
    final res = await ApiClient.instance.post('/websites/options', data: {});
    final data = res.data['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── 域名管理 ───

  /// List domains of a website
  static Future<List<WebsiteDomain>> listDomains(int websiteId) async {
    final res = await ApiClient.instance.get('/websites/domains/$websiteId');
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WebsiteDomain.fromJson)
        .toList();
  }

  /// Add domains to a website
  static Future<void> addDomains(
    int websiteId,
    List<WebsiteDomainReq> domains,
  ) async {
    await ApiClient.instance.post(
      '/websites/domains',
      data: {
        'websiteID': websiteId,
        'domains': domains.map((d) => d.toJson()).toList(),
        'domainStr': '',
      },
    );
  }

  /// Update domain SSL status
  static Future<void> updateDomainSsl(int domainId, bool ssl) async {
    await ApiClient.instance.post(
      '/websites/domains/update',
      data: {'id': domainId, 'ssl': ssl},
    );
  }

  /// Delete a domain
  static Future<void> deleteDomain(int domainId) async {
    await ApiClient.instance.post(
      '/websites/domains/del',
      data: {'id': domainId},
    );
  }

  // ─── 网站目录 ───

  /// Get website directory config
  static Future<Map<String, dynamic>> getDir(int id) async {
    final res = await ApiClient.instance.post(
      '/websites/dir',
      data: {'id': id},
    );
    final raw = res.data['data'];
    return (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  /// Update running directory and reload
  static Future<void> updateSiteDir(int websiteId, String siteDir) async {
    await ApiClient.instance.post(
      '/websites/dir/update',
      data: {'id': websiteId, 'siteDir': siteDir},
    );
  }

  /// Update website run user/group permission
  static Future<void> updateDirPermission(
    int websiteId, {
    required String user,
    required String group,
  }) async {
    await ApiClient.instance.post(
      '/websites/dir/permission',
      data: {'id': websiteId, 'user': user, 'group': group},
    );
  }

  // ─── 默认文档 index ───

  /// Load default document (index) config
  static Future<WebsiteIndexConfig> getIndexConfig(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/config',
      data: {
        'operate': 'update',
        'scope': 'index',
        'websiteId': websiteId,
        'params': <String, dynamic>{},
      },
    );
    final raw = res.data['data'];
    return WebsiteIndexConfig.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Save default document list
  static Future<void> updateIndexConfig(
    int websiteId,
    List<String> indexFiles,
  ) async {
    final body = indexFiles.join('\n');
    final indexParam = body.isEmpty ? '' : '$body\n';
    await ApiClient.instance.post(
      '/websites/config/update',
      data: {
        'operate': 'update',
        'scope': 'index',
        'websiteId': websiteId,
        'params': {'index': indexParam},
      },
    );
  }

  // ─── 流量限制 ───

  /// Load traffic limit (limit-conn) config
  static Future<WebsiteLimitConfig> getLimitConfig(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/config',
      data: {'scope': 'limit-conn', 'websiteId': websiteId},
    );
    final raw = res.data['data'];
    return WebsiteLimitConfig.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Save traffic limit config
  static Future<void> updateLimitConfig(
    int websiteId, {
    required bool enable,
    required int perServerLimit,
    required int perIpLimit,
    required int rateKb,
  }) async {
    await ApiClient.instance.post(
      '/websites/config/update',
      data: {
        'operate': enable ? 'add' : 'delete',
        'scope': 'limit-conn',
        'websiteId': websiteId,
        'params': [
          {'limit_conn': 'perserver $perServerLimit'},
          {'limit_conn': 'perip $perIpLimit'},
          {'limit_rate': '${rateKb}k'},
        ],
      },
    );
  }

  // ─── 反向代理 ───

  /// List reverse proxies
  static Future<List<WebsiteProxy>> listProxies(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/proxies',
      data: {'id': websiteId},
    );
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WebsiteProxy.fromJson)
        .toList();
  }

  /// Create/update reverse proxy
  static Future<void> updateProxy(Map<String, dynamic> payload) async {
    await ApiClient.instance.post('/websites/proxies/update', data: payload);
  }

  /// Delete reverse proxy
  static Future<void> deleteProxy(int websiteId, String name) async {
    await ApiClient.instance.post(
      '/websites/proxies/delete',
      data: {'id': websiteId, 'name': name},
    );
  }

  /// Enable/disable reverse proxy
  static Future<void> updateProxyStatus(
    int websiteId,
    String name,
    String status,
  ) async {
    await ApiClient.instance.post(
      '/websites/proxies/status',
      data: {'id': websiteId, 'name': name, 'status': status},
    );
  }

  /// Save reverse proxy raw file content
  static Future<void> updateProxyFile(
    int websiteId,
    String name,
    String content,
  ) async {
    await ApiClient.instance.post(
      '/websites/proxies/file',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
  }

  // ─── 密码访问 Auth ───

  /// Get website password access config (global)
  static Future<WebsiteAuth> getAuth(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/auths',
      data: {'websiteID': websiteId},
    );
    final raw = res.data['data'];
    return WebsiteAuth.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// List website path password access
  static Future<List<WebsitePathAuth>> listPathAuths(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/auths/path',
      data: {'websiteID': websiteId},
    );
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WebsitePathAuth.fromJson)
        .toList();
  }

  /// Update website password access config (global)
  static Future<void> updateAuth(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/auths/update', data: req);
  }

  /// Update website path password access config
  static Future<void> updatePathAuth(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/auths/path/update', data: req);
  }

  // ─── 防盗链 ───

  /// Get website anti-leech config
  static Future<WebsiteLeech> getLeech(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/leech',
      data: {'websiteID': websiteId},
    );
    final raw = res.data['data'];
    return WebsiteLeech.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Update website anti-leech config
  static Future<void> updateLeech(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/leech/update', data: req);
  }

  // ─── 真实 IP ───

  /// Get website real IP config
  static Future<WebsiteRealIp> getRealIp(int websiteId) async {
    final res = await ApiClient.instance.get(
      '/websites/realip/config/$websiteId',
    );
    final raw = res.data['data'];
    return WebsiteRealIp.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Update website real IP config
  static Future<void> updateRealIp(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/realip/config', data: req);
  }

  // ─── 跨域 CORS ───

  /// Get website CORS config
  static Future<WebsiteCors> getCors(int websiteId) async {
    final res = await ApiClient.instance.get('/websites/cors/$websiteId');
    final raw = res.data['data'];
    return WebsiteCors.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Update website CORS config
  static Future<void> updateCors(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/cors/update', data: req);
  }

  // ─── 伪静态 Rewrite ───

  /// Get rewrite content
  static Future<String> getRewriteContent(int websiteId, String name) async {
    final res = await ApiClient.instance.post(
      '/websites/rewrite',
      data: {'websiteID': websiteId, 'name': name},
    );
    final raw = res.data['data'];
    if (raw is Map) return raw['content']?.toString() ?? '';
    return '';
  }

  /// Get custom rewrite template list
  static Future<List<String>> getCustomRewriteTemplates() async {
    final res = await ApiClient.instance.get('/websites/rewrite/custom');
    final data = res.data['data'];
    if (data is! List) return [];
    return data.map((e) => e.toString()).toList();
  }

  /// Update rewrite config
  static Future<void> updateRewrite(
    int websiteId,
    String name,
    String content,
  ) async {
    await ApiClient.instance.post(
      '/websites/rewrite/update',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
  }

  /// Manage custom rewrite template (create/delete)
  static Future<void> manageCustomRewrite({
    required String name,
    required String operate,
    String? content,
  }) async {
    await ApiClient.instance.post(
      '/websites/rewrite/custom',
      data: {'name': name, 'operate': operate, 'content': content},
    );
  }

  // ─── 重定向 ───

  /// Get website redirect rules
  static Future<List<WebsiteRedirect>> getRedirects(int websiteId) async {
    final res = await ApiClient.instance.post(
      '/websites/redirect',
      data: {'websiteID': websiteId},
    );
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WebsiteRedirect.fromJson)
        .toList();
  }

  /// Update website redirect rules (create/edit/enable/delete)
  static Future<void> updateRedirect(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/redirect/update', data: req);
  }

  /// Save redirect rule raw file
  static Future<void> saveRedirectFile(
    int websiteId,
    String name,
    String content,
  ) async {
    await ApiClient.instance.post(
      '/websites/redirect/file',
      data: {'websiteID': websiteId, 'name': name, 'content': content},
    );
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

  // ─── PHP 版本 ───

  /// Get installed PHP runtimes
  static Future<List<Map<String, dynamic>>> getPhpRuntimes() async {
    try {
      final res = await ApiClient.instance.post(
        '/runtimes/search',
        data: {'page': 1, 'pageSize': 200, 'type': 'php'},
      );
      final data = res.data['data'];
      if (data is Map && data['items'] is List) {
        return (data['items'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Switch PHP version (runtimeID 0 = static)
  static Future<void> switchPhpVersion(int websiteId, int runtimeId) async {
    await ApiClient.instance.post(
      '/websites/php/version',
      data: {'websiteID': websiteId, 'runtimeID': runtimeId},
    );
  }

  // ─── 资源 ───

  /// Get website associated resources
  static Future<List<Map<String, dynamic>>> getResources(int websiteId) async {
    final res = await ApiClient.instance.get('/websites/resource/$websiteId');
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Get associate-able databases
  static Future<List<Map<String, dynamic>>> getDatabases() async {
    final res = await ApiClient.instance.get('/websites/databases');
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Change website associated database
  static Future<void> changeDatabase(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/databases', data: req);
  }

  // ─── OpenResty ───

  /// Get OpenResty running status (nginx stub_status)
  static Future<OpenRestyStatus> getOpenRestyStatus() async {
    final res = await ApiClient.instance.get('/openresty/status');
    final raw = res.data['data'];
    return OpenRestyStatus.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  /// Check if OpenResty is installed
  static Future<bool> isOpenRestyInstalled() async {
    try {
      final res = await ApiClient.instance.get('/openresty/status');
      return res.data['code'] == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get OpenResty main config file content
  static Future<String?> getOpenRestyConfig() async {
    try {
      final res = await ApiClient.instance.get('/openresty');
      final raw = res.data['data'];
      if (raw is Map && raw['content'] != null)
        return raw['content'].toString();
    } catch (_) {}
    return null;
  }

  /// Update OpenResty main config and reload
  static Future<void> updateOpenRestyConfig(String content) async {
    await ApiClient.instance.post(
      '/openresty/file',
      data: {'content': content, 'backup': false},
    );
  }

  // ─── Nginx 配置 ───

  /// Get nginx config
  static Future<String?> getConfig(
    int websiteId, {
    String scope = 'all',
  }) async {
    final res = await ApiClient.instance.post(
      '/websites/config',
      data: {'websiteID': websiteId, 'scope': scope},
    );
    final data = res.data['data'];
    if (data is Map && data['content'] != null) {
      return data['content'].toString();
    }
    return null;
  }

  /// Get website OpenResty config file content
  static Future<String?> getWebsiteConfig(int websiteId) async {
    try {
      final res = await ApiClient.instance.get(
        '/websites/$websiteId/config/openresty',
      );
      final raw = res.data['data'];
      if (raw is Map && raw['content'] != null)
        return raw['content'].toString();
    } catch (_) {}
    return null;
  }

  /// Update website nginx config
  static Future<void> updateNginx(
    int id,
    String content, {
    String scope = 'nginx',
  }) async {
    await ApiClient.instance.post(
      '/websites/nginx/update',
      data: {'id': id, 'content': content, 'scope': scope},
    );
  }

  // ─── 日志 ───

  /// Read website log
  /// [logType]: 'access' or 'error'
  static Future<Map<String, dynamic>> getLog(
    int id,
    String logType, {
    String operate = 'read',
  }) async {
    final res = await ApiClient.instance.post(
      '/websites/log',
      data: {'id': id, 'logType': logType, 'operate': operate},
    );
    final raw = res.data['data'];
    return (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
  }

  /// Enable/disable/clear website log
  static Future<void> operateLog(int id, String logType, String operate) async {
    await ApiClient.instance.post(
      '/websites/log/operate',
      data: {'id': id, 'operate': operate, 'logType': logType},
    );
  }

  // ─── SSL 证书管理 ───

  /// Search SSL certificates
  static Future<Map<String, dynamic>> searchSsl({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await ApiClient.instance.post(
      '/websites/ssl/search',
      data: params,
    );
    final data = res.data['data'] as Map? ?? {};
    final items =
        (data['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SslCertificate.fromJson)
            .toList() ??
        <SslCertificate>[];
    return {'total': data['total'] ?? 0, 'items': items};
  }

  /// Create SSL certificate
  static Future<void> createSsl(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/ssl', data: req);
  }

  /// Update SSL certificate
  static Future<void> updateSsl(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/ssl/update', data: req);
  }

  /// Delete SSL certificates
  static Future<void> deleteSsl(List<int> ids) async {
    await ApiClient.instance.post('/websites/ssl/del', data: {'ids': ids});
  }

  /// Obtain/renew SSL certificate
  static Future<void> obtainSsl(int id) async {
    await ApiClient.instance.post('/websites/ssl/obtain', data: {'sslId': id});
  }

  /// Resolve SSL DNS records
  static Future<List<Map<String, dynamic>>> resolveSsl(
    int acmeId,
    int sslId,
  ) async {
    final res = await ApiClient.instance.post(
      '/websites/ssl/resolve',
      data: {'acmeAccountId': acmeId, 'sslId': sslId},
    );
    final raw = res.data['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Upload SSL certificate (paste)
  static Future<void> uploadSsl(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/ssl/upload', data: req);
  }

  /// Download SSL certificate bytes
  static Future<List<int>> downloadSsl(int id) async {
    final res = await ApiClient.instance.post(
      '/websites/ssl/download',
      data: {'sslId': id},
    );
    final raw = res.data;
    if (raw is List) return raw.cast<int>();
    return const [];
  }

  // ─── ACME 账号 ───

  /// Search ACME accounts
  static Future<List<AcmeAccountDto>> searchAcmeAccounts() async {
    final res = await ApiClient.instance.post(
      '/websites/acme/search',
      data: {'page': 1, 'pageSize': 200},
    );
    final data = res.data['data'];
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AcmeAccountDto.fromJson)
          .toList();
    }
    return [];
  }

  /// Create ACME account
  static Future<void> createAcmeAccount(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/acme', data: req);
  }

  /// Delete ACME account
  static Future<void> deleteAcmeAccount(int id) async {
    await ApiClient.instance.post('/websites/acme/del', data: {'id': id});
  }

  // ─── DNS 账号 ───

  /// Search DNS accounts
  static Future<List<DnsAccountDto>> searchDnsAccounts() async {
    final res = await ApiClient.instance.post(
      '/websites/dns/search',
      data: {'page': 1, 'pageSize': 200},
    );
    final data = res.data['data'];
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(DnsAccountDto.fromJson)
          .toList();
    }
    return [];
  }

  /// Create DNS account
  static Future<void> createDnsAccount(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/dns', data: req);
  }

  /// Delete DNS account
  static Future<void> deleteDnsAccount(int id) async {
    await ApiClient.instance.post('/websites/dns/del', data: {'id': id});
  }

  // ─── 自签 CA ───

  /// Search self-signed CA accounts
  static Future<List<CaAccountDto>> searchCaAccounts() async {
    final res = await ApiClient.instance.post(
      '/websites/ca/search',
      data: {'page': 1, 'pageSize': 200},
    );
    final data = res.data['data'];
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map(CaAccountDto.fromJson)
          .toList();
    }
    return [];
  }

  /// Create self-signed CA
  static Future<void> createCa(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/ca', data: req);
  }

  /// Obtain CA-signed certificate
  static Future<void> obtainCa(Map<String, dynamic> req) async {
    await ApiClient.instance.post('/websites/ca/obtain', data: req);
  }

  /// Renew CA certificate
  static Future<void> renewCa(int sslId) async {
    await ApiClient.instance.post('/websites/ca/renew', data: {'sslId': sslId});
  }

  /// Delete self-signed CA
  static Future<void> deleteCa(int id) async {
    await ApiClient.instance.post('/websites/ca/del', data: {'id': id});
  }
}
