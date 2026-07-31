import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/server_service.dart';
import '../services/panel_ws_ssh_service.dart';
import '../models/image.dart';

class ImageListNotifier extends AsyncNotifier<List<DockerImage>> {
  Timer? _timer;

  @override
  Future<List<DockerImage>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<List<DockerImage>> _fetch() async {
    final svc = ref.read(serverServiceProvider);
    return svc.listImages();
  }

  Future<void> _autoRefresh() async {
    try {
      final data = await _fetch();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  /// 拉取镜像并以流式进度返回。
  ///
  /// Web 端通过 1Panel 终端 WebSocket（`/panel-terminal`）在主机上执行
  /// `docker pull`，把真实行级日志回显给用户，并在命令结束时读取退出码，
  /// 因此「完成」是真实可验证的，失败也会显示具体错误。
  /// 非 Web 端（移动）1Panel 未暴露拉取日志流，退化为「提交任务 + 轮询镜像列表
  /// 直到 tag 出现」的方式。
  Stream<String> pullStream(String imageName) async* {
    final svc = ref.read(serverServiceProvider);
    final normalized = _normalizeImageName(imageName);
    yield '正在拉取 $normalized …';

    if (kIsWeb) {
      await for (final line in _pullViaPanelTerminal(normalized)) {
        yield line;
      }
      return;
    }

    // 非 Web 退化方案：提交任务 + 轮询列表。
    try {
      await svc.pullImage(normalized);
    } catch (e) {
      yield '提交拉取任务失败: $e';
      return;
    }
    yield '已提交拉取任务，等待镜像就绪…';
    const timeout = Duration(minutes: 5);
    final deadline = DateTime.now().add(timeout);
    var waited = 0;
    const interval = Duration(seconds: 2);
    var found = false;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      waited += interval.inSeconds;
      try {
        final list = await svc.listImages();
        if (_listHasImage(list, normalized)) {
          found = true;
          break;
        }
      } catch (_) {}
      if (waited % 10 == 0) yield '拉取中（已等待 ${waited}s）…';
    }
    if (found) {
      yield '镜像拉取完成: $normalized';
    } else {
      yield '拉取超时：镜像未在列表中出现的，可能拉取失败，请到镜像列表确认。';
    }
  }

  /// 通过 1Panel 终端 PTY 执行 `docker pull` 并回显真实日志。
  Stream<String> _pullViaPanelTerminal(String name) async* {
    final term = PanelWsSshService();
    final controller = StreamController<String>();
    final sentinel = '__PULL_DONE__';
    final fullCmd = 'docker pull $name; echo $sentinel\$?';
    final sentinelRe = RegExp('${RegExp.escape(sentinel)}(\\d+)');
    Timer? watchdog;

    term.onData = (data) => controller.add(data);
    term.onStateChange = (connected) {
      if (!connected && !controller.isClosed) controller.close();
    };

    try {
      await term.connect(cols: 240, rows: 24);
    } catch (e) {
      yield '终端连接失败: $e';
      return;
    }

    try {
      // 等 shell 就绪。
      await Future.delayed(const Duration(milliseconds: 800));
      term.write('$fullCmd\n');

      // 兜底：长时间无结束标记则结束流。
      watchdog = Timer(const Duration(minutes: 10), () {
        if (!controller.isClosed) controller.close();
      });

      final sb = StringBuffer();
      String? exitCode;
      var finished = false;
      await for (final chunk in controller.stream) {
        sb.write(chunk);
        while (sb.toString().contains('\n')) {
          final acc = sb.toString();
          final idx = acc.indexOf('\n');
          final line = _stripAnsi(acc.substring(0, idx).trim());
          sb.clear();
          sb.write(acc.substring(idx + 1));
          if (line.contains(sentinel)) {
            final m = sentinelRe.firstMatch(line);
            if (m != null) {
              // 真实结束标记（带退出码）。
              exitCode = m.group(1);
              finished = true;
              break;
            }
            // 仅仅回显的命令行（含 $? 字面量），忽略。
            continue;
          }
          if (line.isEmpty) continue;
          if (line.contains(fullCmd)) continue; // 跳过回显的命令行
          if (_isTerminalNoise(line)) continue; // 跳过登录欢迎信息等噪声
          yield line;
        }
        if (finished) break;
      }
      final rest = _stripAnsi(sb.toString()).trim();
      if (rest.isNotEmpty &&
          !rest.contains(sentinel) &&
          !_isTerminalNoise(rest)) {
        yield rest;
      }

      if (exitCode == null) {
        yield '拉取结束（未捕获到退出码，请到镜像列表确认）';
      } else if (exitCode != '0') {
        yield '拉取失败（退出码 $exitCode）';
      } else {
        yield '镜像拉取完成: $name';
      }
    } finally {
      watchdog?.cancel();
      term.disconnect();
    }
  }

  /// 过滤 1Panel 终端登录横幅等噪声。
  static bool _isTerminalNoise(String line) {
    return line.contains('Last login:') ||
        line.contains('Debian GNU/Linux') ||
        line.contains('NO WARRANTY') ||
        line.contains('programs included') ||
        line.contains('individual files in') ||
        line.startsWith('Linux ');
  }

  /// 判断镜像列表里是否已包含目标 tag（兼容 docker.io/library 前缀）。
  bool _listHasImage(List<DockerImage> list, String ref) {
    String key(String s) {
      if (s.startsWith('docker.io/library/')) {
        s = s.substring('docker.io/library/'.length);
      } else if (s.startsWith('docker.io/')) {
        s = s.substring('docker.io/'.length);
      }
      return s;
    }

    final target = key(ref);
    for (final img in list) {
      for (final t in img.tags) {
        if (key(t) == target) return true;
      }
    }
    return false;
  }

  /// 规范化镜像名（与 OnePanelAdapter 保持一致）：去空白、全角冒号转半角、
  /// 仓库名转小写。
  static String _normalizeImageName(String name) {
    return name
        .trim()
        .replaceAll('：', ':')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  /// 去除 ANSI 转义序列与回车。
  static String _stripAnsi(String s) {
    return s
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '');
  }

  Future<void> pull(String imageName) async {
    final svc = ref.read(serverServiceProvider);
    await svc.pullImage(imageName);
    await refresh();
  }

  Future<void> remove(List<String> ids) async {
    final svc = ref.read(serverServiceProvider);
    for (final id in ids) {
      await svc.removeImage(id, force: true);
    }
    await refresh();
  }

  Future<String> prune({bool all = false}) async {
    final svc = ref.read(serverServiceProvider);
    await svc.pruneImages(all: all);
    await refresh();
    return '清理完成';
  }

  /// Check if newer version of image exists.
  Future<bool> hasUpdate(String imageName) async {
    final svc = ref.read(serverServiceProvider);
    return svc.hasImageUpdate(imageName);
  }
}

final imageListProvider =
    AsyncNotifierProvider<ImageListNotifier, List<DockerImage>>(
      ImageListNotifier.new,
    );
