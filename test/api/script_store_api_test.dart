import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:tianxuan/api/script_store_api.dart';
import 'package:tianxuan/models/script_store_item.dart';

const validIndex =
    '{"version":1,"scripts":[{"id":"a","name":"A","language":"sh","author":"x"}]}';
const validDetail =
    '{"id":"a","name":"A","description":"d","author":{"name":"x"},"language":"sh","downloadUrl":"http://x/a.sh","version":"1.0","updatedAt":"2026-01-01"}';
const htmlError = '<!DOCTYPE html><html lang="zh"><body>error</body></html>';

void main() {
  group('isHtmlBody', () {
    test('识别 HTML 错误页', () {
      expect(ScriptStoreApi.isHtmlBody(htmlError), isTrue);
      expect(ScriptStoreApi.isHtmlBody('<html>bad</html>'), isTrue);
      expect(ScriptStoreApi.isHtmlBody('<div>x</div>'), isTrue);
    });

    test('正常 JSON 不是 HTML', () {
      expect(ScriptStoreApi.isHtmlBody(validIndex), isFalse);
      expect(ScriptStoreApi.isHtmlBody('  {"a":1}'), isFalse);
    });
  });

  group('fetchIndex 网络逻辑', () {
    test('源返回合法 JSON 时解析成功', () async {
      final client = MockClient((req) async => http.Response(validIndex, 200));
      final index = await ScriptStoreApi.fetchIndex(
        sources: [const ScriptSource(name: 't', rawBase: 'http://x')],
        client: client,
      );
      expect(index.scripts.length, 1);
      expect(index.scripts.first.name, 'A');
    });

    test('源返回非 200 时抛友好错误', () async {
      final client = MockClient((req) async => http.Response(htmlError, 400));
      expect(
        () => ScriptStoreApi.fetchIndex(
          sources: [const ScriptSource(name: 't', rawBase: 'http://x')],
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('源返回 200 但 HTML 内容时也判失败', () async {
      final client = MockClient((req) async => http.Response(htmlError, 200));
      expect(
        () => ScriptStoreApi.fetchIndex(
          sources: [const ScriptSource(name: 't', rawBase: 'http://x')],
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('无可用源时抛异常', () async {
      expect(
        () => ScriptStoreApi.fetchIndex(
          sources: const [],
          client: MockClient((req) async => http.Response('', 500)),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fetchDetail 网络逻辑', () {
    test('源返回合法 JSON 时解析成功', () async {
      final client = MockClient(
        (req) async => req.url.path.contains('/details/')
            ? http.Response(validDetail, 200)
            : http.Response(validIndex, 200),
      );
      final detail = await ScriptStoreApi.fetchDetail(
        'a',
        sources: [const ScriptSource(name: 't', rawBase: 'http://x')],
        client: client,
      );
      expect(detail.name, 'A');
      expect(detail.downloadUrl, isNotEmpty);
    });

    test('源返回 HTML 时抛友好错误', () async {
      final client = MockClient(
        (req) async => req.url.path.contains('/details/')
            ? http.Response(htmlError, 404)
            : http.Response(validIndex, 200),
      );
      expect(
        () => ScriptStoreApi.fetchDetail(
          'a',
          sources: [const ScriptSource(name: 't', rawBase: 'http://x')],
          client: client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('模型解析容错', () {
    test('ScriptIndex 空 scripts', () {
      final index = ScriptIndex.fromJson({'version': 1});
      expect(index.scripts, isEmpty);
    });
  });
}
