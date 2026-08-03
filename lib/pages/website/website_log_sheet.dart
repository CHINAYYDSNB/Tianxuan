import 'package:flutter/material.dart';
import '../../api/file_api.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 日志查看弹层
void showLogSheet(
  BuildContext context,
  int websiteId, {
  String? accessLogPath,
  String? errorLogPath,
  String? sitePath,
}) {
  showWebsiteSheet(
    context: context,
    title: '日志查看',
    initialSize: 0.85,
    child: LogSheet(
      websiteId: websiteId,
      accessLogPath: accessLogPath,
      errorLogPath: errorLogPath,
      sitePath: sitePath,
    ),
  );
}

class LogSheet extends StatefulWidget {
  final int websiteId;
  final String? accessLogPath;
  final String? errorLogPath;
  final String? sitePath;

  const LogSheet({
    super.key,
    required this.websiteId,
    this.accessLogPath,
    this.errorLogPath,
    this.sitePath,
  });

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  String _logType = 'access';
  bool _loading = false;
  bool _loadingMore = false;
  List<String> _lines = [];
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLog(reset: true);
  }

  String get _filePath {
    if (_logType == 'access') {
      if (widget.accessLogPath != null && widget.accessLogPath!.isNotEmpty) {
        return widget.accessLogPath!;
      }
      if (widget.sitePath != null && widget.sitePath!.isNotEmpty) {
        return '${widget.sitePath}/log/access.log';
      }
    } else {
      if (widget.errorLogPath != null && widget.errorLogPath!.isNotEmpty) {
        return widget.errorLogPath!;
      }
      if (widget.sitePath != null && widget.sitePath!.isNotEmpty) {
        return '${widget.sitePath}/log/error.log';
      }
    }
    return '';
  }

  Future<void> _loadLog({bool reset = true}) async {
    if (reset) {
      _page = 1;
      _lines = [];
      _error = null;
      _hasMore = true;
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    // 1) 优先 /websites/log API
    if (reset) {
      try {
        final data = await WebsiteApi.getLog(widget.websiteId, _logType);
        final c = data['content']?.toString() ?? '';
        if (c.isNotEmpty && mounted) {
          setState(() {
            _lines = c.split('\n');
            _hasMore = false;
            _loading = false;
          });
          return;
        }
      } catch (_) {}
    }

    // 2) /files/read 分页
    final fp = _filePath;
    if (fp.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error ??= '日志路径未配置';
        });
      }
      return;
    }

    try {
      final r = await FileApi.readByLine(fp, page: _page, pageSize: 500);
      if (mounted) {
        setState(() {
          if (reset)
            _lines = [...r.lines];
          else
            _lines.addAll(r.lines);
          _hasMore = !r.end;
          _page++;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          if (_lines.isEmpty) _error = '读取失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'access', label: Text('访问日志')),
                  ButtonSegment(value: 'error', label: Text('错误日志')),
                ],
                selected: {_logType},
                onSelectionChanged: (v) {
                  setState(() => _logType = v.first);
                  _loadLog(reset: true);
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadLog(reset: true),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading && _lines.isEmpty
              ? const SheetLoading()
              : _error != null && _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Color(0xFFAAB4BF),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _loadLog(reset: true),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _lines.isEmpty
              ? const Center(child: Text('日志为空'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _lines.length + (_hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _lines.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: _loadingMore
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: () => _loadLog(reset: false),
                                  icon: const Icon(Icons.expand_more, size: 18),
                                  label: const Text('加载更多'),
                                ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
                        _lines[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
