import 'package:flutter_test/flutter_test.dart';
import 'package:tianxuan/models/file_item.dart';
import 'package:tianxuan/utils/file_utils.dart';

FileItem item({
  required String name,
  bool isDir = false,
  int size = 0,
  String? extension,
}) => FileItem(
  name: name,
  path: '/x/$name',
  isDir: isDir,
  size: size,
  extension: extension ?? _ext(name),
);

String? _ext(String name) {
  final i = name.lastIndexOf('.');
  return i > 0 ? name.substring(i + 1) : null;
}

void main() {
  group('isTextFile', () {
    test('文本扩展名识别', () {
      expect(isTextFile(item(name: 'a.dart')), isTrue);
      expect(isTextFile(item(name: 'a.json')), isTrue);
      expect(isTextFile(item(name: 'a.yaml')), isTrue);
      expect(isTextFile(item(name: 'Dockerfile')), isTrue);
      expect(isTextFile(item(name: 'Makefile')), isTrue);
    });

    test('非文本扩展名排除', () {
      expect(isTextFile(item(name: 'a.png')), isFalse);
      expect(isTextFile(item(name: 'a.zip')), isFalse);
      expect(isTextFile(item(name: 'a')), isFalse);
    });

    test('目录不是文本', () {
      expect(isTextFile(item(name: 'dir', isDir: true)), isFalse);
    });

    test('超过 10MB 不是文本', () {
      expect(
        isTextFile(item(name: 'big.log', size: 11 * 1024 * 1024)),
        isFalse,
      );
    });
  });

  group('isImageFile', () {
    test('图片扩展名识别', () {
      expect(isImageFile(item(name: 'a.png')), isTrue);
      expect(isImageFile(item(name: 'a.jpg')), isTrue);
      expect(isImageFile(item(name: 'a.jpeg')), isTrue);
      expect(isImageFile(item(name: 'a.gif')), isTrue);
      expect(isImageFile(item(name: 'a.webp')), isTrue);
      expect(isImageFile(item(name: 'a.bmp')), isTrue);
    });

    test('非图片排除', () {
      expect(isImageFile(item(name: 'a.dart')), isFalse);
      expect(isImageFile(item(name: 'Dockerfile')), isFalse);
      expect(isImageFile(item(name: 'dir', isDir: true)), isFalse);
    });
  });
}
