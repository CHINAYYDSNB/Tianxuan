import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/file_api.dart';
import 'package:tianxuan/providers/file_provider.dart';
import 'package:tianxuan/services/file_service.dart';

/// 启动一个本地 mock server，按路径返回 stub 响应。
/// stub[path] 可为:
///   - Map  -> 以 JSON 返回
///   - String -> 以纯文本返回 (用于测试非 JSON 响应)
///   - List<int> -> 以二进制返回 (用于测试文件下载)
Future<HttpServer> _startServer(
  Map<String, Object?> stub,
  List<String> seen,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    seen.add(req.uri.path);
    // 读取并丢弃请求体（含 multipart 上传），避免连接挂起
    await req.drain();
    final v = stub[req.uri.path];
    if (v is List<int>) {
      req.response.headers.contentType = ContentType.binary;
      req.response.add(v);
    } else if (v is String) {
      req.response.headers.contentType = ContentType.text;
      req.response.write(v);
    } else {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(v ?? {'code': 200, 'data': {}}));
    }
    await req.response.close();
  });
  return s;
}

void main() {
  late HttpServer server;
  late int port;
  late Map<String, Object?> stub;
  late List<String> seen;

  setUp(() async {
    stub = {};
    seen = [];
    server = await _startServer(stub, seen);
    port = server.port;
    ApiClient.instance.testConfigure('http://127.0.0.1:$port', 'testkey');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('FileApi 解析', () {
    test('getList 解析 items 与 total', () async {
      stub['/api/v2/files/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'name': 'a.txt', 'path': '/a.txt', 'isDir': false, 'size': 10},
            {'name': 'sub', 'path': '/sub', 'isDir': true},
          ],
          'itemTotal': 2,
        },
      };
      final r = await FileApi.getList(path: '/');
      expect(r.total, 2);
      expect(r.items.length, 2);
      expect(r.items[0].name, 'a.txt');
      expect(r.items[1].isDir, isTrue);
    });

    test('getContent / preview 解析为 FileItem', () async {
      stub['/api/v2/files/content'] = {
        'code': 200,
        'data': {'name': 'c.txt', 'path': '/c.txt', 'content': 'hello'},
      };
      final c = await FileApi.getContent('/c.txt');
      expect(c.content, 'hello');
      stub['/api/v2/files/preview'] = {
        'code': 200,
        'data': {'name': 'p.txt', 'path': '/p.txt', 'content': 'x'},
      };
      final p = await FileApi.preview('/p.txt');
      expect(p.name, 'p.txt');
    });

    test('readByLine 解析行 / totalLines / end', () async {
      stub['/api/v2/files/read'] = {
        'code': 200,
        'data': {
          'lines': ['l1', 'l2'],
          'total': 2,
          'totalLines': 5,
          'end': false,
          'path': '/f',
        },
      };
      final r = await FileApi.readByLine('/f');
      expect(r.lines, ['l1', 'l2']);
      expect(r.totalLines, 5);
      expect(r.end, isFalse);
    });

    test('getSize 解析 size/total/path', () async {
      stub['/api/v2/files/size'] = {
        'code': 200,
        'data': {'size': 1024, 'total': 2048, 'path': '/x'},
      };
      final r = await FileApi.getSize('/x');
      expect(r.size, 1024);
      expect(r.total, 2048);
      expect(r.path, '/x');
    });

    test('getMount 解析挂载列表', () async {
      stub['/api/v2/files/mount'] = {
        'code': 200,
        'data': [
          {
            'path': '/',
            'device': '/dev/sda1',
            'fsType': 'ext4',
            'mountPoint': '/',
          },
        ],
      };
      final r = await FileApi.getMount();
      expect(r.length, 1);
      expect(r.first.device, '/dev/sda1');
      expect(r.first.fsType, 'ext4');
    });

    test('getUserGroup 解析 users/groups', () async {
      stub['/api/v2/files/user/group'] = {
        'code': 200,
        'data': {
          'users': [
            {'username': 'alice', 'group': 'sudo'},
            'bob',
          ],
          'groups': ['sudo', 'root'],
        },
      };
      final r = await FileApi.getUserGroup();
      expect(r.users, ['alice (sudo)', 'bob']);
      expect(r.groups, ['sudo', 'root']);
    });

    test('checkExists 返回 true/false', () async {
      stub['/api/v2/files/check'] = {'code': 200, 'data': true};
      expect(await FileApi.checkExists('/e'), isTrue);
      stub['/api/v2/files/check'] = {'code': 200, 'data': false};
      expect(await FileApi.checkExists('/e'), isFalse);
    });

    test('download 返回二进制', () async {
      stub['/api/v2/files/download'] = [9, 8, 7];
      final bytes = await FileApi.download('/d.bin');
      expect(bytes, [9, 8, 7]);
    });

    test('各写操作不抛异常', () async {
      stub['/api/v2/files/save'] = {'code': 200};
      stub['/api/v2/files'] = {'code': 200};
      stub['/api/v2/files/rename'] = {'code': 200};
      stub['/api/v2/files/del'] = {'code': 200};
      stub['/api/v2/files/batch/del'] = {'code': 200};
      stub['/api/v2/files/mode'] = {'code': 200};
      stub['/api/v2/files/owner'] = {'code': 200};
      stub['/api/v2/files/move'] = {'code': 200};
      stub['/api/v2/files/compress'] = {'code': 200};
      stub['/api/v2/files/decompress'] = {'code': 200};
      stub['/api/v2/files/upload'] = {'code': 200};

      await FileApi.save('/s', 'c');
      await FileApi.create('/c', isDir: true);
      await FileApi.rename('/o', '/n');
      await FileApi.delete('/d');
      await FileApi.batchDelete(['/a', '/b']);
      await FileApi.changeMode('/m', 420);
      await FileApi.changeOwner('/o', 'u', 'g');
      await FileApi.move(['/a'], '/dst');
      await FileApi.compress(['/a'], '/dst', 'arc');
      await FileApi.decompress('/a.zip', '/dst');

      final tmp = File('${Directory.systemTemp.path}/tx_up_test.bin');
      await tmp.writeAsBytes([1, 2, 3]);
      await FileApi.upload('/up', tmp.path);
      await FileApi.uploadBytes('/up', 'name.bin', [4, 5, 6]);
      await tmp.delete();
    });

    test('code != 200 抛异常', () async {
      stub['/api/v2/files/search'] = {'code': 500, 'message': 'boom'};
      expect(() => FileApi.getList(path: '/'), throwsA(isA<Exception>()));
    });

    test('非 map 响应抛异常', () async {
      stub['/api/v2/files/content'] = 'not a json object';
      expect(() => FileApi.getContent('/x'), throwsA(isA<Exception>()));
    });
  });

  group('ApiFileService 委托', () {
    test('list 委托到 FileApi 并命中服务端', () async {
      stub['/api/v2/files/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'name': 'a.txt', 'path': '/a.txt'},
          ],
          'itemTotal': 1,
        },
      };
      final r = await ApiFileService().list(path: '/root');
      expect(r.items.first.name, 'a.txt');
      expect(seen, contains('/api/v2/files/search'));
    });

    test('download 委托到 FileApi', () async {
      stub['/api/v2/files/download'] = [1, 2];
      final bytes = await ApiFileService().download('/d');
      expect(bytes, [1, 2]);
    });
  });

  group('fileTreeProvider', () {
    test('解析目录树', () async {
      stub['/api/v2/files/tree'] = {
        'code': 200,
        'data': [
          {'name': 'a', 'path': '/a'},
          {'name': 'b', 'path': '/b'},
        ],
      };
      final container = ProviderContainer();
      final tree = await container.read(fileTreeProvider('/').future);
      expect(tree.length, 2);
      expect(tree.first.name, 'a');
      container.dispose();
    });
  });
}
