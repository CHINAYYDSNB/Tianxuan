/// 脚本商店数据模型。
///
/// 字段命名以接口约定（camelCase）为准，同时容忍 snake_case 变体，
/// 以兼容静态仓库 JSON 可能的不同写法。

class ScriptSummary {
  final String id;
  final String name;
  final String desc;
  final String category;
  final String downloadUrl;
  final String language;

  const ScriptSummary({
    required this.id,
    required this.name,
    required this.desc,
    required this.category,
    required this.downloadUrl,
    this.language = '',
  });

  factory ScriptSummary.fromJson(Map<String, dynamic> json) {
    return ScriptSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      desc: json['desc'] as String? ?? (json['description'] as String? ?? ''),
      category: json['category'] as String? ?? '',
      downloadUrl:
          json['downloadUrl'] as String? ??
          (json['download_url'] as String? ?? ''),
      language: json['language'] as String? ?? '',
    );
  }
}

class ScriptDetail extends ScriptSummary {
  final String author;
  final String source;
  final String rawUrl;

  const ScriptDetail({
    required super.id,
    required super.name,
    required super.desc,
    required super.category,
    required super.downloadUrl,
    this.author = '',
    this.source = '',
    this.rawUrl = '',
  });

  factory ScriptDetail.fromJson(Map<String, dynamic> json) {
    final downloadUrl =
        json['downloadUrl'] as String? ??
        (json['download_url'] as String? ?? '');
    // author 可能为字符串，也可能为 { "name": ... } 对象。
    final authorRaw = json['author'];
    final author = authorRaw is Map
        ? (authorRaw['name'] as String? ?? '')
        : (authorRaw as String? ?? '');
    // rawUrl 缺失时回退到 downloadUrl（仓库中二者通常指向同一份源码）。
    final rawUrl =
        json['rawUrl'] as String? ??
        (json['raw_url'] as String? ?? downloadUrl);
    return ScriptDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      desc: json['desc'] as String? ?? (json['description'] as String? ?? ''),
      category: json['category'] as String? ?? '',
      downloadUrl: downloadUrl,
      author: author,
      source: json['source'] as String? ?? '',
      rawUrl: rawUrl,
    );
  }
}
