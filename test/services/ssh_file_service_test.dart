import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/services/ssh_command_service.dart';
import 'package:tianxuan/services/ssh_file_service.dart';

class MockSsh extends Mock implements SshCommandService {}

void main() {
  late MockSsh ssh;
  late SshFileService svc;

  setUp(() {
    ssh = MockSsh();
    svc = SshFileService(ssh);
  });

  void stubCmd(String cmd, {String out = '', String err = '', int code = 0}) {
    when(() => ssh.execute(cmd)).thenAnswer(
      (_) async => SshResult(exitCode: code, stdout: out, stderr: err),
    );
  }

  group('list', () {
    test('解析 ls -la 输出', () async {
      stubCmd(
        'ls -la "/var/www"',
        out:
            'total 8\n'
            '-rw-r--r-- 1 root root 1234 Jan  1 12:00 index.html\n'
            'drwxr-xr-x 2 root root 4096 Feb  2 09:30 logs\n'
            'lrwxrwxrwx 1 root root    7 Jan  1 12:00 link -> /tmp\n'
            '.hidden 2 root root 10 Jan  1 12:00 .env\n',
      );
      final result = await svc.list(path: '/var/www');
      expect(result.items.length, 4); // index.html, logs, link, .env（排除 . 和 ..）
      final names = result.items.map((f) => f.name).toList();
      expect(
        names,
        containsAll(['index.html', 'logs', 'link -> /tmp', '.env']),
      );
      final index = result.items.firstWhere((f) => f.name == 'index.html');
      expect(index.isDir, isFalse);
      expect(index.size, 1234);
      expect(index.mode, '-rw-r--r--');
      expect(index.user, 'root');
      final logs = result.items.firstWhere((f) => f.name == 'logs');
      expect(logs.isDir, isTrue);
      final link = result.items.firstWhere((f) => f.name == 'link -> /tmp');
      expect(link.isSymlink, isTrue);
      final hidden = result.items.firstWhere((f) => f.name == '.env');
      expect(hidden.isHidden, isTrue);
    });

    test('支持搜索过滤', () async {
      stubCmd(
        'ls -la "/var/www"',
        out:
            'total 8\n'
            '-rw-r--r-- 1 root root 10 Jan 1 12:00 a.txt\n'
            '-rw-r--r-- 1 root root 10 Jan 1 12:00 b.log\n',
      );
      final result = await svc.list(path: '/var/www', search: 'log');
      expect(result.items.length, 1);
      expect(result.items.first.name, 'b.log');
    });
  });

  group('读写', () {
    test('readFile 返回 stdout', () async {
      stubCmd('cat "/a.txt"', out: 'hello');
      expect(await svc.readFile('/a.txt'), 'hello');
    });

    test('save 使用备份 + heredoc 写入', () async {
      when(
        () => ssh.execute(any()),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      await svc.save('/a.txt', 'new content');
      verify(
        () => ssh.execute('cp "/a.txt" "/a.txt.bak.\$(date +%s)"'),
      ).called(1);
      final captured = verify(() => ssh.execute(captureAny())).captured;
      final writeCmd = captured.last as String;
      expect(writeCmd, contains("cat > \"/a.txt\" <<'LANXI_EOF'"));
      expect(writeCmd, contains('new content'));
    });

    test('getContent 解析', () async {
      stubCmd('cat "/a.txt"', out: 'content');
      final item = await svc.getContent('/a.txt');
      expect(item.content, 'content');
      expect(item.path, '/a.txt');
    });

    test('readByLine 分页', () async {
      stubCmd('cat "/a.txt"', out: 'l1\nl2\n');
      final r = await svc.readByLine('/a.txt');
      expect(r.lines, ['l1', 'l2']);
      expect(r.end, isTrue);
    });

    test('checkExists', () async {
      stubCmd('test -e "/a" && echo yes', out: 'yes');
      expect(await svc.checkExists('/a'), isTrue);
      stubCmd('test -e "/b" && echo yes', out: '');
      expect(await svc.checkExists('/b'), isFalse);
    });
  });

  group('操作', () {
    test('rename/delete/changeMode 调用对应命令', () async {
      when(
        () => ssh.execute(any()),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      await svc.rename('/a', '/b');
      await svc.delete('/d');
      await svc.changeMode('/m', 755);
      verify(() => ssh.execute('mv "/a" "/b"')).called(1);
      verify(() => ssh.execute('rm -f "/d"')).called(1);
      verify(() => ssh.execute('chmod 755 "/m"')).called(1);
    });

    test('create 目录/文件', () async {
      when(
        () => ssh.execute(any()),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      await svc.create('/dir', isDir: true);
      verify(() => ssh.execute('mkdir -p "/dir"')).called(1);
      await svc.create('/f.txt', content: 'x');
      final captured = verify(() => ssh.execute(captureAny())).captured;
      final writeCmd = captured.last as String;
      expect(writeCmd, contains("cat > \"/f.txt\" <<'LANXI_EOF'"));
    });

    test('命令失败时抛异常', () async {
      stubCmd('cat "/missing"', err: 'No such file', code: 1);
      expect(() => svc.readFile('/missing'), throwsException);
    });
  });
}
