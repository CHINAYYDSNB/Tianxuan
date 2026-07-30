import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:tianxuan/models/script_store.dart';
import 'package:tianxuan/services/script_store_service.dart';

class MockHttpClient extends Mock implements http.Client {}

const _indexJson = '''
[
  {"id":"clamav","name":"安装 ClamAV","desc":"杀毒","category":"安全","downloadUrl":"https://x/sh/clamav.sh"},
  {"id":"nginx","name":"安装 Nginx","desc":"Web 服务器","category":"Web","downloadUrl":"https://x/sh/nginx.sh"}
]
''';

const _detailJson = '''
{
  "id":"clamav",
  "name":"安装 ClamAV",
  "desc":"杀毒",
  "category":"安全",
  "downloadUrl":"https://x/sh/clamav.sh",
  "author":"lingqi",
  "source":"#!/bin/bash\\necho hi",
  "rawUrl":"https://x/raw/clamav.sh"
}
''';

void main() {
  late MockHttpClient client;
  late ScriptStoreService service;

  setUp(() {
    client = MockHttpClient();
    service = ScriptStoreService(client: client);
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  test('getIndex 解析 JSON 数组', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(_indexJson),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final list = await service.getIndex();
    expect(list.length, 2);
    expect(list.first.id, 'clamav');
    expect(list.first.name, '安装 ClamAV');
    expect(list.first.downloadUrl, 'https://x/sh/clamav.sh');
  });

  test('getDetail 解析 JSON 对象', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(_detailJson),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final d = await service.getDetail('clamav');
    expect(d.id, 'clamav');
    expect(d.author, 'lingqi');
    expect(d.source, '#!/bin/bash\necho hi');
    expect(d.rawUrl, 'https://x/raw/clamav.sh');
    expect(d, isA<ScriptDetail>());
  });

  test('响应为 HTML 时抛出 ScriptStoreException', () {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response.bytes(utf8.encode('<html>oops</html>'), 200),
    );
    expect(() => service.getIndex(), throwsA(isA<ScriptStoreException>()));
    expect(() => service.getDetail('x'), throwsA(isA<ScriptStoreException>()));
    expect(
      () => service.fetchText('https://x'),
      throwsA(isA<ScriptStoreException>()),
    );
  });

  test('fetchText 返回纯文本', () async {
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response.bytes(utf8.encode('#!/bin/bash'), 200),
    );
    expect(await service.fetchText('https://x'), '#!/bin/bash');
  });

  test('模型容忍 snake_case 字段名', () {
    final s = ScriptSummary.fromJson({
      'id': 'a',
      'name': 'N',
      'description': 'D',
      'category': 'C',
      'download_url': 'u',
    });
    expect(s.desc, 'D');
    expect(s.downloadUrl, 'u');

    final d = ScriptDetail.fromJson({
      'id': 'a',
      'name': 'N',
      'description': 'D',
      'category': 'C',
      'download_url': 'u',
      'author': 'A',
      'source': 'S',
      'raw_url': 'R',
    });
    expect(d.author, 'A');
    expect(d.source, 'S');
    expect(d.rawUrl, 'R');
  });
}
