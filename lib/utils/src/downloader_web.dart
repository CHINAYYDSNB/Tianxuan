import 'dart:html' as html;
import 'dart:typed_data';

/// 浏览器 Blob 下载 (Web)
Future<String> saveFile(String name, List<int> bytes) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  return _downloadBlob(name, blob);
}

Future<String> saveTextFile(String name, String text) async {
  final blob = html.Blob([text]);
  return _downloadBlob(name, blob);
}

Future<String> _downloadBlob(String name, html.Blob blob) async {
  final url = html.Url.createObjectUrl(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = 'download'
      ..download = name
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    return name;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
