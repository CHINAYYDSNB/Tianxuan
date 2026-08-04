import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/services/ssh_command_service.dart';

void main() {
  group('SshConfig', () {
    test('toJson 含所有字段', () {
      final c = const SshConfig(
        host: '1.2.3.4',
        port: 2222,
        username: 'root',
        password: 'pw',
        privateKey: 'key',
      );
      expect(c.toJson()['host'], '1.2.3.4');
      expect(c.toJson()['port'], 2222);
      expect(c.toJson()['password'], 'pw');
      expect(c.toJson()['privateKey'], 'key');
    });

    test('toJson 省略空凭据', () {
      final c = const SshConfig(host: 'h', port: 22, username: 'u');
      expect(c.toJson().containsKey('password'), isFalse);
      expect(c.toJson().containsKey('privateKey'), isFalse);
    });

    test('默认端口 22', () {
      const c = SshConfig(host: 'h', username: 'u');
      expect(c.port, 22);
    });
  });

  group('SshResult', () {
    test('isSuccess 按 exitCode', () {
      expect(const SshResult(exitCode: 0).isSuccess, isTrue);
      expect(const SshResult(exitCode: 1).isSuccess, isFalse);
      expect(const SshResult(exitCode: -1).isSuccess, isFalse);
    });
  });
}
