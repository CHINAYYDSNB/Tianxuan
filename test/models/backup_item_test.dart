import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/backup_item.dart';

void main() {
  test('包含 5 个备份项目', () {
    expect(BackupItem.values.length, 5);
  });

  test('每个项目有 label 和 description', () {
    for (final item in BackupItem.values) {
      expect(item.label, isNotEmpty);
      expect(item.description, isNotEmpty);
    }
  });

  test('服务器配置是第一个（默认重要项）', () {
    expect(BackupItem.values.first, BackupItem.servers);
    expect(BackupItem.servers.label, '服务器配置');
  });

  test('itemNames 返回名称列表', () {
    const payload = BackupPayload(
      items: [BackupItem.servers, BackupItem.theme],
    );
    expect(payload.itemNames, ['servers', 'theme']);
    expect(payload.version, 2);
  });
}
