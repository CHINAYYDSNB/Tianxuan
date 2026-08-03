import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/providers/file_editor_provider.dart';
import 'package:tianxuan/providers/ssh_connection_provider.dart';

/// Stateful mock server simulating 1Panel file read/write.
Future<HttpServer> _startServer(
  Map<String, String> files,
  List<String> seen,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    seen.add(req.uri.path);
    final body = <String, dynamic>{};
    if (req.method == 'POST') {
      final raw = await utf8.decoder.bind(req).join();
      if (raw.isNotEmpty) {
        try {
          body.addAll(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    }
    final path =
        (body['path'] ?? req.uri.queryParameters['path'])?.toString() ?? '';
    final ct = ContentType.json;
    if (req.uri.path.endsWith('/files/save')) {
      files[path] = body['content']?.toString() ?? '';
      req.response.headers.contentType = ct;
      req.response.write(jsonEncode({'code': 200, 'data': {}}));
    } else if (req.uri.path.endsWith('/files/content')) {
      req.response.headers.contentType = ct;
      req.response.write(
        jsonEncode({
          'code': 200,
          'data': {
            'name': path.split('/').last,
            'path': path,
            'content': files[path] ?? '',
          },
        }),
      );
    } else if (req.uri.path.endsWith('/files/search')) {
      req.response.headers.contentType = ct;
      final name = path.split('/').last;
      req.response.write(
        jsonEncode({
          'code': 200,
          'data': {
            'items': [
              {
                'name': name,
                'path': path,
                'modTime': '2026-01-01 00:00:00',
                'size': (files[path] ?? '').length,
              },
            ],
            'itemTotal': 1,
          },
        }),
      );
    } else {
      req.response.statusCode = 404;
      req.response.write(jsonEncode({'code': 404, 'message': 'no route'}));
    }
    await req.response.close();
  });
  return s;
}

void main() {
  late HttpServer server;
  late Map<String, String> files;
  late List<String> seen;

  setUp(() async {
    files = {'/var/www/test.txt': 'ORIGINAL_CONTENT'};
    seen = [];
    server = await _startServer(files, seen);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'key');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  test('save then reload returns fresh content', () async {
    final container = ProviderContainer(
      overrides: [
        // 强制走 API（无 SSH），避免 SSH provider 干扰
        sshServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final provider = fileEditorProvider(('/var/www/test.txt', 'test.txt'));
    container.read(provider.notifier);
    for (var i = 0; i < 100 && container.read(provider).loading; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    expect(container.read(provider).text, 'ORIGINAL_CONTENT');

    await container.read(provider.notifier).save('EDITED_NEW_CONTENT');
    expect(seen, contains('/api/v2/files/save'));
    expect(files['/var/www/test.txt'], 'EDITED_NEW_CONTENT');

    container.invalidate(provider);
    final listener = container.listen(provider, (_, __) {});
    for (var i = 0; i < 100 && container.read(provider).loading; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    listener.close();

    expect(container.read(provider).text, 'EDITED_NEW_CONTENT');
  });
}
