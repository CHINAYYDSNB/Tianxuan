/// 网站各配置项的数据模型（对应 1Panel /websites 下的配置接口）

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is num) return v.toInt();
  return 0;
}

String _toStr(dynamic v) => v?.toString() ?? '';

// ─── 反向代理 ───

class WebsiteProxy {
  final String name;
  final String type;
  final String location;
  final bool enable;
  final String proxyPass;
  final int changeDirectory;
  final String directory;
  final List<Map<String, dynamic>> extraParams;

  const WebsiteProxy({
    this.name = '',
    this.type = 'location',
    this.location = '/',
    this.enable = true,
    this.proxyPass = '',
    this.changeDirectory = 0,
    this.directory = '',
    this.extraParams = const [],
  });

  factory WebsiteProxy.fromJson(Map<String, dynamic> json) {
    final type = _toStr(json['type']);
    final name = _toStr(json['name']);
    return WebsiteProxy(
      name: name,
      type: type,
      location: _toStr(json['location']),
      enable: json['enable'] != false,
      proxyPass: _toStr(json['proxyPass']),
      changeDirectory: _toInt(json['changeDirectory']),
      directory: _toStr(json['directory']),
      extraParams: json['extraParams'] is List
          ? (json['extraParams'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'location': location,
    'enable': enable,
    'proxyPass': proxyPass,
    'changeDirectory': changeDirectory,
    'directory': directory,
    'extraParams': extraParams,
  };
}

// ─── 密码访问 (Auth) ───

class WebsiteAuth {
  final bool enable;
  final String username;
  final String password;
  final String content;
  final List<WebsitePathAuth> paths;

  const WebsiteAuth({
    this.enable = false,
    this.username = '',
    this.password = '',
    this.content = '',
    this.paths = const [],
  });

  factory WebsiteAuth.fromJson(Map<String, dynamic> json) => WebsiteAuth(
    enable: json['enable'] == true,
    username: _toStr(json['username']),
    password: _toStr(json['password']),
    content: _toStr(json['content']),
    paths: json['paths'] is List
        ? (json['paths'] as List)
              .whereType<Map<String, dynamic>>()
              .map(WebsitePathAuth.fromJson)
              .toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'enable': enable,
    'username': username,
    'password': password,
    'content': content,
    'paths': paths.map((p) => p.toJson()).toList(),
  };
}

class WebsitePathAuth {
  final String name;
  final String username;
  final String password;

  const WebsitePathAuth({
    this.name = '',
    this.username = '',
    this.password = '',
  });

  factory WebsitePathAuth.fromJson(Map<String, dynamic> json) =>
      WebsitePathAuth(
        name: _toStr(json['name']),
        username: _toStr(json['username']),
        password: _toStr(json['password']),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'password': password,
  };
}

// ─── 跨域 CORS ───

class WebsiteCors {
  final bool enable;
  final String origin;
  final String method;
  final String headers;
  final bool cookie;

  const WebsiteCors({
    this.enable = false,
    this.origin = '',
    this.method = '',
    this.headers = '',
    this.cookie = false,
  });

  factory WebsiteCors.fromJson(Map<String, dynamic> json) => WebsiteCors(
    enable: json['enable'] == true,
    origin: _toStr(json['origin']),
    method: _toStr(json['method']),
    headers: _toStr(json['headers']),
    cookie: json['cookie'] == true,
  );

  Map<String, dynamic> toJson() => {
    'enable': enable,
    'origin': origin,
    'method': method,
    'headers': headers,
    'cookie': cookie,
  };
}

// ─── 真实 IP ───

class WebsiteRealIp {
  final bool enable;
  final String proxyHeader;
  final String proxyIps;

  const WebsiteRealIp({
    this.enable = false,
    this.proxyHeader = '',
    this.proxyIps = '',
  });

  factory WebsiteRealIp.fromJson(Map<String, dynamic> json) => WebsiteRealIp(
    enable: json['enable'] == true,
    proxyHeader: _toStr(json['proxyHeader']),
    proxyIps: _toStr(json['proxyIps']),
  );

  Map<String, dynamic> toJson() => {
    'enable': enable,
    'proxyHeader': proxyHeader,
    'proxyIps': proxyIps,
  };
}

// ─── 防盗链 ───

class WebsiteLeech {
  final bool enable;
  final String type;
  final String servers;
  final String returns;
  final List<String> suffixs;

  const WebsiteLeech({
    this.enable = false,
    this.type = '',
    this.servers = '',
    this.returns = '',
    this.suffixs = const [],
  });

  factory WebsiteLeech.fromJson(Map<String, dynamic> json) => WebsiteLeech(
    enable: json['enable'] == true,
    type: _toStr(json['type']),
    servers: _toStr(json['servers']),
    returns: _toStr(json['returns']),
    suffixs: json['suffixs'] is List
        ? (json['suffixs'] as List).map((e) => _toStr(e)).toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'enable': enable,
    'type': type,
    'servers': servers,
    'returns': returns,
    'suffixs': suffixs,
  };
}

// ─── 重定向 ───

class WebsiteRedirect {
  final String name;
  final String type;
  final String source;
  final String target;
  final bool enable;
  final bool keepPath;
  final int keepQuery;
  final int statusCode;

  const WebsiteRedirect({
    this.name = '',
    this.type = '',
    this.source = '',
    this.target = '',
    this.enable = true,
    this.keepPath = false,
    this.keepQuery = 0,
    this.statusCode = 301,
  });

  factory WebsiteRedirect.fromJson(Map<String, dynamic> json) =>
      WebsiteRedirect(
        name: _toStr(json['name']),
        type: _toStr(json['type']),
        source: _toStr(json['source']),
        target: _toStr(json['target']),
        enable: json['enable'] != false,
        keepPath: json['keepPath'] == true,
        keepQuery: _toInt(json['keepQuery']),
        statusCode: _toInt(json['statusCode']) == 0
            ? 301
            : _toInt(json['statusCode']),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'source': source,
    'target': target,
    'enable': enable,
    'keepPath': keepPath,
    'keepQuery': keepQuery,
    'statusCode': statusCode,
  };
}

// ─── 默认文档 index ───

class WebsiteIndexConfig {
  final List<String> indexFiles;

  const WebsiteIndexConfig({this.indexFiles = const []});

  factory WebsiteIndexConfig.fromJson(Map<String, dynamic> json) {
    final index = _toStr(json['index']);
    return WebsiteIndexConfig(
      indexFiles: index.isEmpty
          ? const []
          : index.split('\n').where((e) => e.isNotEmpty).toList(),
    );
  }
}

// ─── 流量限制 ───

class WebsiteLimitConfig {
  final bool enable;
  final int perServerLimit;
  final int perIpLimit;
  final int rateKb;

  const WebsiteLimitConfig({
    this.enable = false,
    this.perServerLimit = 0,
    this.perIpLimit = 0,
    this.rateKb = 0,
  });

  factory WebsiteLimitConfig.fromJson(Map<String, dynamic> json) {
    final params = json['params'];
    var perServer = 0;
    var perIp = 0;
    var rate = 0;
    if (params is List) {
      for (final p in params) {
        if (p is! Map) continue;
        final v = p['limit_conn']?.toString() ?? '';
        if (v.startsWith('perserver ')) {
          perServer = int.tryParse(v.substring(10)) ?? 0;
        } else if (v.startsWith('perip ')) {
          perIp = int.tryParse(v.substring(6)) ?? 0;
        }
        final r = p['limit_rate']?.toString() ?? '';
        if (r.isNotEmpty) {
          rate = int.tryParse(r.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
      }
    }
    return WebsiteLimitConfig(
      enable: json['enable'] == true,
      perServerLimit: perServer,
      perIpLimit: perIp,
      rateKb: rate,
    );
  }
}

// ─── OpenResty 状态 ───

class OpenRestyStatus {
  final int active;
  final int accepts;
  final int handled;
  final int requests;
  final int reading;
  final int writing;
  final int waiting;

  const OpenRestyStatus({
    this.active = 0,
    this.accepts = 0,
    this.handled = 0,
    this.requests = 0,
    this.reading = 0,
    this.writing = 0,
    this.waiting = 0,
  });

  factory OpenRestyStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final m = data is Map ? Map<String, dynamic>.from(data) : json;
    return OpenRestyStatus(
      active: _toInt(m['Active']),
      accepts: _toInt(m['Accepts']),
      handled: _toInt(m['Handled']),
      requests: _toInt(m['Requests']),
      reading: _toInt(m['Reading']),
      writing: _toInt(m['Writing']),
      waiting: _toInt(m['Waiting']),
    );
  }
}

// ─── 域名 DTO ───

class WebsiteDomain {
  final int id;
  final int websiteId;
  final String domain;
  final int port;
  final bool ssl;
  final String createdAt;
  final String updatedAt;

  const WebsiteDomain({
    this.id = 0,
    this.websiteId = 0,
    this.domain = '',
    this.port = 0,
    this.ssl = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory WebsiteDomain.fromJson(Map<String, dynamic> json) => WebsiteDomain(
    id: _toInt(json['id']),
    websiteId: _toInt(json['websiteId']),
    domain: _toStr(json['domain']),
    port: _toInt(json['port']),
    ssl: json['ssl'] == true,
    createdAt: _toStr(json['createdAt']),
    updatedAt: _toStr(json['updatedAt']),
  );
}

class WebsiteDomainReq {
  final String domain;
  final int port;
  final bool ssl;

  const WebsiteDomainReq({
    required this.domain,
    this.port = 80,
    this.ssl = false,
  });

  Map<String, dynamic> toJson() => {'domain': domain, 'port': port, 'ssl': ssl};
}

// ─── SSL 管理 ───

class SslCertificate {
  final int id;
  final String primaryDomain;
  final String type;
  final String provider;
  final String organization;
  final String status;
  final String expireDate;
  final String startDate;
  final bool autoRenew;
  final String domains;

  const SslCertificate({
    this.id = 0,
    this.primaryDomain = '',
    this.type = '',
    this.provider = '',
    this.organization = '',
    this.status = '',
    this.expireDate = '',
    this.startDate = '',
    this.autoRenew = false,
    this.domains = '',
  });

  factory SslCertificate.fromJson(Map<String, dynamic> json) => SslCertificate(
    id: _toInt(json['id']),
    primaryDomain: _toStr(json['primaryDomain']),
    type: _toStr(json['type']),
    provider: _toStr(json['provider']),
    organization: _toStr(json['organization']),
    status: _toStr(json['status']),
    expireDate: _toStr(json['expireDate']),
    startDate: _toStr(json['startDate']),
    autoRenew: json['autoRenew'] == true,
    domains: _toStr(json['domains']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'primaryDomain': primaryDomain,
    'type': type,
    'provider': provider,
    'organization': organization,
    'status': status,
    'expireDate': expireDate,
    'startDate': startDate,
    'autoRenew': autoRenew,
    'domains': domains,
  };
}

// ─── ACME / DNS / CA 账号 ───

class AcmeAccountDto {
  final int id;
  final String email;
  final String url;
  final String type;

  const AcmeAccountDto({
    this.id = 0,
    this.email = '',
    this.url = '',
    this.type = '',
  });

  factory AcmeAccountDto.fromJson(Map<String, dynamic> json) => AcmeAccountDto(
    id: _toInt(json['id']),
    email: _toStr(json['email']),
    url: _toStr(json['url']),
    type: _toStr(json['type']),
  );
}

class DnsAccountDto {
  final int id;
  final String name;
  final String type;

  const DnsAccountDto({this.id = 0, this.name = '', this.type = ''});

  factory DnsAccountDto.fromJson(Map<String, dynamic> json) => DnsAccountDto(
    id: _toInt(json['id']),
    name: _toStr(json['name']),
    type: _toStr(json['type']),
  );
}

class CaAccountDto {
  final int id;
  final String name;
  final String country;
  final String province;
  final String city;
  final String organization;
  final String organizationUnit;
  final String email;
  final String keyLength;
  final String validityDay;

  const CaAccountDto({
    this.id = 0,
    this.name = '',
    this.country = '',
    this.province = '',
    this.city = '',
    this.organization = '',
    this.organizationUnit = '',
    this.email = '',
    this.keyLength = '',
    this.validityDay = '',
  });

  factory CaAccountDto.fromJson(Map<String, dynamic> json) => CaAccountDto(
    id: _toInt(json['id']),
    name: _toStr(json['name']),
    country: _toStr(json['country']),
    province: _toStr(json['province']),
    city: _toStr(json['city']),
    organization: _toStr(json['organization']),
    organizationUnit: _toStr(json['organizationUnit']),
    email: _toStr(json['email']),
    keyLength: _toStr(json['keyLength']),
    validityDay: _toStr(json['validityDay']),
  );
}
