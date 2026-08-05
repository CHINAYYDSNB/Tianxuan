import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/database.dart';

void main() {
  group('DbTypeMeta', () {
    test('fromString 识别各类型', () {
      expect(DbTypeMeta.fromString('mysql'), DbType.mysql);
      expect(DbTypeMeta.fromString('MariaDB'), DbType.mysql);
      expect(DbTypeMeta.fromString('postgresql'), DbType.postgresql);
      expect(DbTypeMeta.fromString('mongo'), DbType.mongodb);
      expect(DbTypeMeta.fromString('redis'), DbType.redis);
      expect(DbTypeMeta.fromString(''), isNull);
    });

    test('默认端口', () {
      expect(DbType.mysql.defaultPort, 3306);
      expect(DbType.postgresql.defaultPort, 5432);
      expect(DbType.redis.defaultPort, 6379);
      expect(DbType.mongodb.defaultPort, 27017);
    });

    test('默认用户', () {
      expect(DbType.mysql.defaultUser, 'root');
      expect(DbType.postgresql.defaultUser, 'postgres');
    });

    test('apiListTypes 含全部类型', () {
      expect(DbTypeMeta.apiListTypes, contains('mysql'));
      expect(DbTypeMeta.apiListTypes, contains('postgresql'));
      expect(DbTypeMeta.apiListTypes, contains('redis'));
    });
  });

  group('DatabaseInstance', () {
    test('toJson/fromJson 往返', () {
      const inst = DatabaseInstance(
        id: '1',
        type: DbType.mysql,
        name: 'test',
        address: 'localhost',
        port: 3306,
        username: 'root',
        version: '8.0',
        source: 'api',
      );
      final restored = DatabaseInstance.fromJson(inst.toJson());
      expect(restored.id, '1');
      expect(restored.type, DbType.mysql);
      expect(restored.name, 'test');
      expect(restored.address, 'localhost');
      expect(restored.port, 3306);
      expect(restored.username, 'root');
      expect(restored.source, 'api');
      expect(restored.fromApi, isTrue);
    });

    test('默认值', () {
      final inst = DatabaseInstance.fromJson({
        'id': 'x',
        'type': 'redis',
        'name': 'r',
      });
      expect(inst.port, 6379);
      expect(inst.address, 'localhost');
      expect(inst.source, 'manual');
      expect(inst.fromApi, isFalse);
    });

    test('copyWith 保留字段', () {
      const inst = DatabaseInstance(id: '1', type: DbType.mysql, name: 'n');
      final updated = inst.copyWith(password: 'p', version: '9.0');
      expect(updated.password, 'p');
      expect(updated.version, '9.0');
      expect(updated.name, 'n');
    });
  });

  group('DatabaseItem', () {
    test('fromJson 解析', () {
      final item = DatabaseItem.fromJson({
        'name': 'mydb',
        'format': 'utf8mb4',
        'collation': 'utf8mb4_unicode_ci',
        'username': 'root',
        'permission': 'ALL',
      });
      expect(item.name, 'mydb');
      expect(item.format, 'utf8mb4');
      expect(item.collation, 'utf8mb4_unicode_ci');
      expect(item.username, 'root');
    });

    test('mysqlName 回退', () {
      final item = DatabaseItem.fromJson({'mysqlName': 'db1'});
      expect(item.name, 'db1');
    });
  });
}
