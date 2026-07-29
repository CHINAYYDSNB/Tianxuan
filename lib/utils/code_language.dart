import 'package:highlight/highlight.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

/// 根据扩展名返回高亮语言（[Mode]），未知返回 null（纯文本）
Mode? codeLanguageForExtension(String? ext) {
  switch ((ext ?? '').toLowerCase()) {
    case 'dart':
      return dart;
    case 'json':
      return json;
    case 'yaml':
    case 'yml':
      return yaml;
    case 'xml':
    case 'html':
    case 'svg':
      return xml;
    case 'sh':
    case 'bash':
    case 'bat':
      return bash;
    case 'sql':
      return sql;
    case 'py':
      return python;
    case 'js':
      return javascript;
    case 'ts':
      return typescript;
    case 'go':
      return go;
    case 'c':
    case 'cpp':
    case 'h':
      return cpp;
    case 'java':
    case 'kt':
      return java;
    case 'css':
      return css;
    case 'md':
      return markdown;
    default:
      return null;
  }
}
