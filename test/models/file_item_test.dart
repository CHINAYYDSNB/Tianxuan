import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/file_item.dart';

void main() {
  group('FileItem.fromJson', () {
    test('基本字段与默认值', () {
      final f = FileItem.fromJson({
        'name': 'a.txt',
        'path': '/a.txt',
        'isDir': false,
        'size': 2048,
      });
      expect(f.name, 'a.txt');
      expect(f.path, '/a.txt');
      expect(f.isDir, isFalse);
      expect(f.isHidden, isFalse);
      expect(f.isSymlink, isFalse);
      expect(f.size, 2048);
    });

    test('isDir / isHidden / isSymlink 为 true', () {
      final f = FileItem.fromJson({
        'name': 'sub',
        'path': '/sub',
        'isDir': true,
        'isHidden': true,
        'isSymlink': true,
      });
      expect(f.isDir, isTrue);
      expect(f.isHidden, isTrue);
      expect(f.isSymlink, isTrue);
    });

    test('size 兼容字符串和数字', () {
      expect(
        FileItem.fromJson({'name': 'a', 'path': '/a', 'size': '123'}).size,
        123,
      );
      expect(
        FileItem.fromJson({'name': 'a', 'path': '/a', 'size': 5.0}).size,
        5,
      );
      expect(
        FileItem.fromJson({'name': 'a', 'path': '/a', 'size': 'bad'}).size,
        0,
      );
    });

    test('解析嵌套 items', () {
      final f = FileItem.fromJson({
        'name': 'root',
        'path': '/',
        'isDir': true,
        'items': [
          {'name': 'child', 'path': '/child', 'isDir': false},
        ],
      });
      expect(f.items, isNotNull);
      expect(f.items!.first.name, 'child');
    });

    test('favoriteID / itemTotal 解析', () {
      final f = FileItem.fromJson({
        'name': 'a',
        'path': '/a',
        'favoriteID': 7,
        'itemTotal': 3,
      });
      expect(f.favoriteID, 7);
      expect(f.itemTotal, 3);
    });
  });

  group('formattedSize', () {
    test('目录返回空字符串', () {
      expect(FileItem(name: 'd', path: '/d', isDir: true).formattedSize, '');
    });
    test('字节', () {
      expect(
        FileItem(name: 'a', path: '/a', isDir: false, size: 512).formattedSize,
        '512 B',
      );
    });
    test('KB', () {
      expect(
        FileItem(name: 'a', path: '/a', isDir: false, size: 2048).formattedSize,
        '2.0 KB',
      );
    });
    test('GB', () {
      expect(
        FileItem(
          name: 'a',
          path: '/a',
          isDir: false,
          size: 1024 * 1024 * 1024 * 3,
        ).formattedSize,
        '3.0 GB',
      );
    });
  });

  group('formattedMode', () {
    test('空 mode 返回空', () {
      expect(FileItem(name: 'a', path: '/a', isDir: false).formattedMode, '');
    });
    test('八进制 0755 -> rwxr-xr-x', () {
      expect(
        FileItem(
          name: 'a',
          path: '/a',
          isDir: false,
          mode: '0755',
        ).formattedMode,
        'rwxr-xr-x',
      );
    });
    test('八进制 0644 -> rw-r--r--', () {
      expect(
        FileItem(
          name: 'a',
          path: '/a',
          isDir: false,
          mode: '0644',
        ).formattedMode,
        'rw-r--r--',
      );
    });
    test('非标准字符串原样返回', () {
      expect(
        FileItem(
          name: 'a',
          path: '/a',
          isDir: false,
          mode: 'custom',
        ).formattedMode,
        'custom',
      );
    });
  });

  group('toJson', () {
    test('导出核心字段', () {
      final j = FileItem(name: 'a', path: '/a', isDir: false, size: 1).toJson();
      expect(j['name'], 'a');
      expect(j['path'], '/a');
      expect(j['isDir'], isFalse);
    });
  });
}
