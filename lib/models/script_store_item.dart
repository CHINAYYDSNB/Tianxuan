/// 脚本商店索引条目 (轻量)
class ScriptIndexItem {
  final String id;
  final String name;
  final String language; // sh | python
  final String author;

  ScriptIndexItem({
    required this.id,
    required this.name,
    required this.language,
    this.author = '',
  });

  factory ScriptIndexItem.fromJson(Map<String, dynamic> json) =>
      ScriptIndexItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        language: json['language'] as String? ?? 'sh',
        author: json['author'] as String? ?? '',
      );
}

/// 脚本商店索引
class ScriptIndex {
  final int version;
  final String updatedAt;
  final List<ScriptIndexItem> scripts;

  ScriptIndex({this.version = 1, this.updatedAt = '', this.scripts = const []});

  factory ScriptIndex.fromJson(Map<String, dynamic> json) => ScriptIndex(
    version: json['version'] as int? ?? 1,
    updatedAt: json['updatedAt'] as String? ?? '',
    scripts:
        (json['scripts'] as List?)
            ?.map((e) => ScriptIndexItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// 脚本详细内容
class ScriptDetail {
  final String id;
  final String name;
  final String description;
  final ScriptAuthor author;
  final String language;
  final List<String> dependencies;
  final String downloadUrl;
  final List<String> screenshots;
  final String version;
  final String updatedAt;

  ScriptDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.language,
    this.dependencies = const [],
    required this.downloadUrl,
    this.screenshots = const [],
    required this.version,
    required this.updatedAt,
  });

  factory ScriptDetail.fromJson(Map<String, dynamic> json) => ScriptDetail(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    author: ScriptAuthor.fromJson(
      json['author'] as Map<String, dynamic>? ?? {},
    ),
    language: json['language'] as String? ?? 'sh',
    dependencies: (json['dependencies'] as List?)?.cast<String>() ?? [],
    downloadUrl: json['downloadUrl'] as String? ?? '',
    screenshots: (json['screenshots'] as List?)?.cast<String>() ?? [],
    version: json['version'] as String? ?? '1.0.0',
    updatedAt: json['updatedAt'] as String? ?? '',
  );
}

/// 脚本作者
class ScriptAuthor {
  final String logtoId;
  final String name;
  final String avatar;
  final String email;

  ScriptAuthor({
    this.logtoId = '',
    this.name = '',
    this.avatar = '',
    this.email = '',
  });

  bool get hasInfo => name.isNotEmpty;

  factory ScriptAuthor.fromJson(Map<String, dynamic> json) => ScriptAuthor(
    logtoId: json['logtoId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );
}
