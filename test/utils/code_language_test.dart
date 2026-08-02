import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:tianxuan/utils/code_language.dart';

void main() {
  test('常见文本扩展名映射到对应高亮语言', () {
    expect(codeLanguageForExtension('dart'), isNotNull);
    expect(codeLanguageForExtension('json'), isNotNull);
    expect(codeLanguageForExtension('yaml'), isNotNull);
    expect(codeLanguageForExtension('yml'), isNotNull);
    expect(codeLanguageForExtension('xml'), isNotNull);
    expect(codeLanguageForExtension('html'), isNotNull);
    expect(codeLanguageForExtension('sh'), isNotNull);
    expect(codeLanguageForExtension('bash'), isNotNull);
    expect(codeLanguageForExtension('sql'), isNotNull);
    expect(codeLanguageForExtension('py'), isNotNull);
    expect(codeLanguageForExtension('js'), isNotNull);
    expect(codeLanguageForExtension('ts'), isNotNull);
    expect(codeLanguageForExtension('go'), isNotNull);
    expect(codeLanguageForExtension('cpp'), isNotNull);
    expect(codeLanguageForExtension('c'), isNotNull);
    expect(codeLanguageForExtension('java'), isNotNull);
    expect(codeLanguageForExtension('css'), isNotNull);
    expect(codeLanguageForExtension('md'), isNotNull);
  });

  test('新增语言扩展名映射到对应高亮语言', () {
    expect(codeLanguageForExtension('rb'), isNotNull);
    expect(codeLanguageForExtension('php'), isNotNull);
    expect(codeLanguageForExtension('rs'), isNotNull);
    expect(codeLanguageForExtension('swift'), isNotNull);
    expect(codeLanguageForExtension('toml'), isNotNull);
    expect(codeLanguageForExtension('ini'), isNotNull);
    expect(codeLanguageForExtension('cfg'), isNotNull);
    expect(codeLanguageForExtension('conf'), isNotNull);
    expect(codeLanguageForExtension('env'), isNotNull);
    expect(codeLanguageForExtension('gradle'), isNotNull);
    expect(codeLanguageForExtension('lock'), isNotNull);
  });

  test('未知扩展名返回 null（纯文本）', () {
    expect(codeLanguageForExtension('png'), isNull);
    expect(codeLanguageForExtension('zip'), isNull);
    expect(codeLanguageForExtension(null), isNull);
    expect(codeLanguageForExtension(''), isNull);
    expect(codeLanguageForExtension('Makefile'), isNull);
  });

  test('返回的是 Mode 类型', () {
    final mode = codeLanguageForExtension('dart');
    expect(mode, isA<Mode>());
  });
}
