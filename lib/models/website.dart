class Domain {
  final int id;
  final int websiteId;
  final String domain;
  final int port;
  final bool ssl;

  Domain({
    required this.id,
    required this.websiteId,
    required this.domain,
    required this.port,
    required this.ssl,
  });

  factory Domain.fromJson(Map<String, dynamic> json) => Domain(
        id: _toInt(json['id']),
        websiteId: _toInt(json['websiteId']),
        domain: json['domain']?.toString() ?? '',
        port: _toInt(json['port']),
        ssl: json['ssl'] == true,
      );
}

class AcmeAccount {
  final int id;
  final String email;
  final String url;
  final String type;

  const AcmeAccount({this.id = 0, this.email = '', this.url = '', this.type = ''});

  factory AcmeAccount.fromJson(Map<String, dynamic> json) => AcmeAccount(
        id: _toInt(json['id']),
        email: json['email']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
      );
}

class DnsAccount {
  final int id;
  final String name;
  final String type;

  const DnsAccount({this.id = 0, this.name = '', this.type = ''});

  factory DnsAccount.fromJson(Map<String, dynamic> json) => DnsAccount(
        id: _toInt(json['id']),
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
      );
}

class WebSiteSSL {
  final int id;
  final String primaryDomain;
  final String type;
  final String provider;
  final String organization;
  final String status;
  final String expireDate;
  final String startDate;
  final bool autoRenew;
  final String certURL;
  final String domains;
  final AcmeAccount acmeAccount;
  final DnsAccount dnsAccount;

  WebSiteSSL({
    this.id = 0,
    this.primaryDomain = '',
    this.type = '',
    this.provider = '',
    this.organization = '',
    this.status = '',
    this.expireDate = '',
    this.startDate = '',
    this.autoRenew = false,
    this.certURL = '',
    this.domains = '',
    this.acmeAccount = const AcmeAccount(),
    this.dnsAccount = const DnsAccount(),
  });

  factory WebSiteSSL.fromJson(Map<String, dynamic> json) => WebSiteSSL(
        id: _toInt(json['id']),
        primaryDomain: json['primaryDomain']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        organization: json['organization']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        expireDate: json['expireDate']?.toString() ?? '',
        startDate: json['startDate']?.toString() ?? '',
        autoRenew: json['autoRenew'] == true,
        certURL: json['certURL']?.toString() ?? '',
        domains: json['domains']?.toString() ?? '',
        acmeAccount: json['acmeAccount'] != null
            ? AcmeAccount.fromJson(json['acmeAccount'])
            : const AcmeAccount(),
        dnsAccount: json['dnsAccount'] != null
            ? DnsAccount.fromJson(json['dnsAccount'])
            : const DnsAccount(),
      );
}

class Website {
  final int id;
  final String primaryDomain;
  final String type;
  final String alias;
  final String status;
  final String remark;
  final String? proxy;
  final String? redirectURL;
  final String? sitePath;
  final String? errorLogPath;
  final String? accessLogPath;
  final int port;
  final bool errorLog;
  final bool accessLog;
  final bool favorite;
  final bool defaultServer;
  final bool iPV6;
  final bool openBaseDir;
  final String webSiteGroupId;
  final String createdAt;
  final String? updatedAt;
  final String? protocol;
  final String? httpConfig;
  final String? proxyType;
  final String? expireDate;
  final String? rewrite;
  final String? appName;
  final String? runtimeName;
  final String? webRuntimeType;
  final String? sslStatus;
  final String? sslExpireDate;
  final String? siteDir;
  final String? user;
  final String? group;
  final String? dbType;
  final String? algorithm;
  final int webSiteSSLId;
  final int runtimeID;
  final int appInstallId;
  final int ftpId;
  final int parentWebsiteID;
  final int dbID;

  // nested
  final List<Domain> domains;
  final WebSiteSSL? ssl;

  Website({
    required this.id,
    required this.primaryDomain,
    required this.type,
    required this.alias,
    required this.status,
    this.remark = '',
    this.proxy,
    this.redirectURL,
    this.sitePath,
    this.errorLogPath,
    this.accessLogPath,
    this.port = 0,
    this.errorLog = false,
    this.accessLog = false,
    this.favorite = false,
    this.defaultServer = false,
    this.iPV6 = false,
    this.openBaseDir = false,
    this.webSiteGroupId = '1',
    required this.createdAt,
    this.updatedAt,
    this.protocol,
    this.httpConfig,
    this.proxyType,
    this.expireDate,
    this.rewrite,
    this.appName,
    this.runtimeName,
    this.webRuntimeType,
    this.sslStatus,
    this.sslExpireDate,
    this.siteDir,
    this.user,
    this.group,
    this.dbType,
    this.algorithm,
    this.webSiteSSLId = 0,
    this.runtimeID = 0,
    this.appInstallId = 0,
    this.ftpId = 0,
    this.parentWebsiteID = 0,
    this.dbID = 0,
    this.domains = const [],
    this.ssl,
  });

  factory Website.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';

    // Parse type field - handle both detail and search response formats
    final domainsRaw = json['domains'];
    final List<Domain> domains = domainsRaw is List
        ? domainsRaw.map((e) => Domain.fromJson(e as Map<String, dynamic>)).toList()
        : [];

    final sslRaw = json['webSiteSSL'];
    final WebSiteSSL? ssl = sslRaw is Map<String, dynamic>
        ? WebSiteSSL.fromJson(sslRaw)
        : null;

    return Website(
      id: _toInt(json['id']),
      primaryDomain: s(json['primaryDomain']),
      type: s(json['type']),
      alias: s(json['alias']),
      status: s(json['status']),
      remark: s(json['remark']),
      proxy: json['proxy']?.toString(),
      redirectURL: json['redirectURL']?.toString(),
      sitePath: json['sitePath']?.toString(),
      errorLogPath: json['errorLogPath']?.toString(),
      accessLogPath: json['accessLogPath']?.toString(),
      port: _toInt(json['port']),
      errorLog: json['errorLog'] == true,
      accessLog: json['accessLog'] == true,
      favorite: json['favorite'] == true,
      defaultServer: json['defaultServer'] == true,
      iPV6: json['IPV6'] == true,
      openBaseDir: json['openBaseDir'] == true,
      webSiteGroupId: s(json['webSiteGroupId']),
      createdAt: s(json['createdAt']),
      updatedAt: json['updatedAt']?.toString(),
      protocol: json['protocol']?.toString(),
      httpConfig: json['httpConfig']?.toString(),
      proxyType: json['proxyType']?.toString(),
      expireDate: json['expireDate']?.toString(),
      rewrite: json['rewrite']?.toString(),
      appName: json['appName']?.toString(),
      runtimeName: json['runtimeName']?.toString(),
      webRuntimeType: json['runtimeType']?.toString(),
      sslStatus: json['sslStatus']?.toString(),
      sslExpireDate: json['sslExpireDate']?.toString(),
      siteDir: json['siteDir']?.toString(),
      user: json['user']?.toString(),
      group: json['group']?.toString(),
      dbType: json['dbType']?.toString(),
      algorithm: json['algorithm']?.toString(),
      webSiteSSLId: _toInt(json['webSiteSSLId']),
      runtimeID: _toInt(json['runtimeID']),
      appInstallId: _toInt(json['appInstallId']),
      ftpId: _toInt(json['ftpId']),
      parentWebsiteID: _toInt(json['parentWebsiteID']),
      dbID: _toInt(json['dbID']),
      domains: domains,
      ssl: ssl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'primaryDomain': primaryDomain,
        'type': type,
        'alias': alias,
        'status': status,
        'remark': remark,
        'proxy': proxy,
        'redirectURL': redirectURL,
        'sitePath': sitePath,
        'port': port,
        'errorLogPath': errorLogPath,
        'accessLogPath': accessLogPath,
        'errorLog': errorLog,
        'accessLog': accessLog,
        'favorite': favorite,
        'defaultServer': defaultServer,
        'iPV6': iPV6,
        'openBaseDir': openBaseDir,
        'webSiteGroupId': webSiteGroupId,
        'protocol': protocol,
        'httpConfig': httpConfig,
        'proxyType': proxyType,
        'expireDate': expireDate,
        'rewrite': rewrite,
        'appName': appName,
        'runtimeName': runtimeName,
        'webRuntimeType': webRuntimeType,
        'sslStatus': sslStatus,
        'sslExpireDate': sslExpireDate,
        'siteDir': siteDir,
        'user': user,
        'group': group,
        'dbType': dbType,
        'algorithm': algorithm,
        'webSiteSSLId': webSiteSSLId,
        'runtimeID': runtimeID,
        'appInstallId': appInstallId,
        'ftpId': ftpId,
        'parentWebsiteID': parentWebsiteID,
        'dbID': dbID,
      };

  /// Display-friendly type name
  String get typeLabel {
    switch (type) {
      case 'static':
        return '静态网站';
      case 'proxy':
        return '反向代理';
      case 'redirect':
        return '重定向';
      case 'deployment':
        return '部署';
      case 'runtime':
        return '运行环境';
      case 'subsite':
        return '子站点';
      default:
        return type;
    }
  }

  /// Status label (Chinese)
  String get statusLabel {
    switch (status) {
      case 'Running':
        return '运行中';
      case 'Stopped':
        return '已停止';
      case 'Error':
        return '异常';
      default:
        return status;
    }
  }

  bool get isRunning => status == 'Running';
}

/// Request body for create website
class WebsiteCreateRequest {
  final String primaryDomain;
  final String type;
  final String alias;
  final int websiteGroupID;
  final String appType; // "installed" or "new"
  final String? remark;
  final String? proxy;
  final String? redirectURL;
  final int? port;
  final int appInstallID;
  final int runtimeID;

  WebsiteCreateRequest({
    required this.primaryDomain,
    required this.type,
    required this.alias,
    this.websiteGroupID = 1,
    this.appType = 'installed',
    this.remark,
    this.proxy,
    this.redirectURL,
    this.port,
    this.appInstallID = 0,
    this.runtimeID = 0,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'primaryDomain': primaryDomain,
      'type': type,
      'alias': alias,
      'websiteGroupID': websiteGroupID,
      'appType': appType,
    };
    if (remark != null && remark!.isNotEmpty) m['remark'] = remark;
    if (proxy != null && proxy!.isNotEmpty) m['proxy'] = proxy;
    if (redirectURL != null && redirectURL!.isNotEmpty) m['redirectURL'] = redirectURL;
    if (port != null && port! > 0) m['port'] = port;
    if (appInstallID > 0) m['appInstallID'] = appInstallID;
    if (runtimeID > 0) m['runtimeID'] = runtimeID;
    return m;
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is num) return v.toInt();
  return 0;
}
