import 'dart:convert';
import '../models/container.dart';
import '../models/image.dart';
import '../models/compose.dart';

/// Parses docker CLI `--format '{{json .}}'` JSONL output.
class DockerParser {
  // ─── Container ───

  static List<Container> parsePs(String jsonl) {
    if (jsonl.trim().isEmpty) return [];
    final out = <Container>[];
    for (final line in jsonl.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        out.add(_parsePsLine(trimmed));
      } catch (_) {}
    }
    return out;
  }

  static Container _parsePsLine(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    String s(dynamic v) => v?.toString() ?? '';
    final names = s(j['Names']);
    final status = s(j['Status']);
    String state;
    if (status.startsWith('Up')) {
      state = 'running';
    } else if (status.startsWith('Exited')) {
      state = 'exited';
    } else if (status.startsWith('Paused')) {
      state = 'paused';
    } else if (status.startsWith('Created')) {
      state = 'created';
    } else if (status.startsWith('Restarting')) {
      state = 'restarting';
    } else if (status.contains('Removing')) {
      state = 'removing';
    } else if (status.contains('Dead')) {
      state = 'dead';
    } else {
      state = status;
    }
    List<String>? ports;
    final portsRaw = s(j['Ports']);
    if (portsRaw.isNotEmpty) {
      ports = portsRaw
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    final networks = <String>[];
    final nets = s(j['Networks']);
    if (nets.isNotEmpty) {
      networks.addAll(
          nets.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty));
    }
    return Container(
      containerID: s(j['ID']),
      name: names.split(',').first.trim(),
      imageName: s(j['Image']),
      createTime: s(j['CreatedAt']),
      state: state,
      runTime: status.startsWith('Up') ? status.substring(3).trim() : status,
      network: networks,
      ports: ports,
      isFromCompose: (s(j['Labels'])).contains('com.docker.compose'),
    );
  }

  static ContainerStats parseDockerStats(String jsonl) {
    final trimmed = jsonl.trim();
    if (trimmed.isEmpty) return ContainerStats();
    try {
      final j =
          jsonDecode(trimmed.split('\n').first) as Map<String, dynamic>;
      String s(dynamic v) => v?.toString() ?? '';
      final cpuRaw = s(j['CPUPerc']).replaceAll('%', '');
      final cpu = double.tryParse(cpuRaw) ?? 0;
      final memRaw = s(j['MemUsage']);
      final mem = _parseMemUsage(memRaw);
      final netRaw = s(j['NetIO']);
      final netParts = netRaw.split(' / ');
      final netRx = _parseByteSize(netParts.isNotEmpty ? netParts[0] : '0B');
      final netTx =
          _parseByteSize(netParts.length > 1 ? netParts[1] : '0B');
      final ioRaw = s(j['BlockIO']);
      final ioParts = ioRaw.split(' / ');
      final ioR = _parseByteSize(ioParts.isNotEmpty ? ioParts[0] : '0B');
      final ioW = _parseByteSize(ioParts.length > 1 ? ioParts[1] : '0B');
      return ContainerStats(
        cpuPercent: cpu,
        memory: mem,
        networkRX: netRx,
        networkTX: netTx,
        ioRead: ioR,
        ioWrite: ioW,
        shotTime: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return ContainerStats();
    }
  }

  // ─── Image ───

  static List<DockerImage> parseImages(String jsonl) {
    if (jsonl.trim().isEmpty) return [];
    final out = <DockerImage>[];
    for (final line in jsonl.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        out.add(_parseImageLine(trimmed));
      } catch (_) {}
    }
    return _mergeImages(out);
  }

  static DockerImage _parseImageLine(String line) {
    final j = jsonDecode(line) as Map<String, dynamic>;
    String s(dynamic v) => v?.toString() ?? '';
    final tag = s(j['Tag']);
    final repo = s(j['Repository']);
    final tagStr = repo.isEmpty ? tag : '$repo:$tag';
    final size = _parseImageSize(s(j['Size']));
    final containers = int.tryParse(s(j['Containers']));
    return DockerImage(
      id: s(j['ID']),
      tags: tagStr == ':' ? [] : [tagStr],
      size: size,
      createdAt: s(j['CreatedAt']),
      isUsed: containers != null && containers > 0,
    );
  }

  static List<DockerImage> _mergeImages(List<DockerImage> images) {
    final map = <String, Set<String>>{};
    final info = <String, DockerImage>{};
    for (final img in images) {
      map.putIfAbsent(img.id, () => {});
      map[img.id]!.addAll(img.tags);
      info.putIfAbsent(img.id, () => img);
    }
    return map.entries.map((e) {
      final base = info[e.key]!;
      return DockerImage(
        id: base.id,
        tags: e.value.toList(),
        size: base.size,
        createdAt: base.createdAt,
        isUsed: base.isUsed,
      );
    }).toList();
  }

  // ─── Compose ───

  static List<ComposeItem> parseComposeLs(String jsonStr) {
    if (jsonStr.trim().isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) {
        final j = e as Map<String, dynamic>;
        String s(dynamic v) => v?.toString() ?? '';
        final status = s(j['Status']);
        return ComposeItem(
          name: s(j['Name']),
          path: s(j['ConfigFiles']).split('\n').first,
          configFile: s(j['ConfigFiles']),
          runningCount: _extractRunningCount(status),
          containerCount: _extractTotalCount(status),
          composeFileExists: true,
        );
      }).toList();
    } catch (_) {
      return _parseComposeLsFallback(jsonStr);
    }
  }

  static List<ComposeItem> _parseComposeLsFallback(String jsonl) {
    final out = <ComposeItem>[];
    for (final line in jsonl.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final j = jsonDecode(line.trim()) as Map<String, dynamic>;
        String s(dynamic v) => v?.toString() ?? '';
        out.add(ComposeItem(
          name: s(j['Name']),
          path: s(j['ConfigFiles']),
          composeFileExists: true,
        ));
      } catch (_) {}
    }
    return out;
  }

  static List<ComposeItem> parseFindCompose(String text) {
    if (text.trim().isEmpty) return [];
    return text.split('\n').where((l) => l.trim().isNotEmpty).map((path) {
      final parts = path.trim().split('/');
      final dir = parts.length > 2 ? parts[parts.length - 2] : path.trim();
      return ComposeItem(
        name: dir,
        path: path.trim(),
        composeFileExists: true,
      );
    }).toList();
  }

  // ─── Registry Mirrors ───

  static List<String> parseRegistryMirrors(String jsonText) {
    if (jsonText.trim().isEmpty || jsonText.trim() == '{}') return [];
    try {
      final j = jsonDecode(jsonText) as Map<String, dynamic>;
      final mirrors = j['registry-mirrors'];
      if (mirrors is List) {
        return mirrors.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  static String buildDaemonJson(List<String> mirrors) {
    final j = {'registry-mirrors': mirrors};
    return const JsonEncoder.withIndent('  ').convert(j);
  }

  // ─── Docker Info ───

  static Map<String, dynamic> parseDockerInfo(String jsonStr) {
    if (jsonStr.trim().isEmpty) return {};
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ─── Helpers ───

  static double _parseMemUsage(String raw) {
    final used = raw.split(' / ').first.trim();
    return _parseToGB(used);
  }

  static double _parseToGB(String s) {
    s = s.trim();
    double val = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (s.endsWith('GiB') || s.endsWith('GB')) return val;
    if (s.endsWith('MiB') || s.endsWith('MB')) return val / 1024;
    if (s.endsWith('KiB') || s.endsWith('KB')) return val / (1024 * 1024);
    if (s.endsWith('TiB') || s.endsWith('TB')) return val * 1024;
    return val / (1024 * 1024 * 1024);
  }

  static double _parseByteSize(String s) {
    s = s.trim().toLowerCase();
    double val = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (s.contains('gb')) return val * 1024 * 1024 * 1024;
    if (s.contains('mb')) return val * 1024 * 1024;
    if (s.contains('kb')) return val * 1024;
    if (s.contains('tb')) return val * 1024 * 1024 * 1024 * 1024;
    return val;
  }

  static int _parseImageSize(String s) {
    s = s.trim();
    double val = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (s.contains('GB')) return (val * 1024 * 1024 * 1024).round();
    if (s.contains('MB')) return (val * 1024 * 1024).round();
    if (s.contains('KB')) return (val * 1024).round();
    return val.round();
  }

  static int _extractRunningCount(String status) {
    if (status.isEmpty) return 0;
    final match = RegExp(r'(\d+)\s*running').firstMatch(status.toLowerCase());
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  static int _extractTotalCount(String status) {
    if (status.isEmpty) return 0;
    final match = RegExp(r'(\d+)\s*exited').firstMatch(status.toLowerCase());
    final count = match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
    return _extractRunningCount(status) + count;
  }
}
