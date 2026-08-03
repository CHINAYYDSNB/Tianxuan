import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/providers/server_list_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedServer', () {
    test('toJson 不含 apiKey（密钥单独存储）', () {
      final s = SavedServer(
        id: '1',
        name: 'a',
        url: 'http://x:80',
        apiKey: 'sk',
      );
      final json = s.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'a');
      expect(json['url'], 'http://x:80');
      expect(json.containsKey('apiKey'), isFalse);
    });

    test('displayUrl 保留协议', () {
      final s = SavedServer(
        id: '1',
        name: 'a',
        url: 'https://x:9999',
        apiKey: '',
      );
      expect(s.displayUrl, 'https://x:9999');
    });
  });

  group('SavedServersNotifier', () {
    test('add 追加服务器', () async {
      final notifier = SavedServersNotifier();
      final s1 = SavedServer(id: '1', name: 'a', url: 'http://a', apiKey: 'k1');
      final s2 = SavedServer(id: '2', name: 'b', url: 'http://b', apiKey: 'k2');
      await notifier.add(s1);
      await notifier.add(s2);
      expect(notifier.state.length, 2);
      expect(notifier.state.first.id, '1');
      expect(notifier.state.last.name, 'b');
    });

    test('remove 删除指定 id', () async {
      final notifier = SavedServersNotifier();
      final s1 = SavedServer(id: '1', name: 'a', url: 'http://a', apiKey: '');
      final s2 = SavedServer(id: '2', name: 'b', url: 'http://b', apiKey: '');
      await notifier.add(s1);
      await notifier.add(s2);
      await notifier.remove('1');
      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, '2');
    });

    test('update 替换同 id 服务器', () async {
      final notifier = SavedServersNotifier();
      final s1 = SavedServer(id: '1', name: 'a', url: 'http://a', apiKey: '');
      await notifier.add(s1);
      final updated = SavedServer(
        id: '1',
        name: 'a2',
        url: 'http://a2',
        apiKey: '',
      );
      await notifier.update(updated);
      expect(notifier.state.first.name, 'a2');
      expect(notifier.state.first.url, 'http://a2');
    });
  });
}
