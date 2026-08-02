import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 默认文档（index）配置弹层
void showIndexSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '默认文档',
    initialSize: 0.6,
    child: IndexSheet(websiteId: websiteId),
  );
}

class IndexSheet extends StatefulWidget {
  final int websiteId;
  const IndexSheet({super.key, required this.websiteId});

  @override
  State<IndexSheet> createState() => _IndexSheetState();
}

class _IndexSheetState extends State<IndexSheet> {
  late Future<List<String>> _future;
  late List<String> _items;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<String>> _load() async {
    final cfg = await WebsiteApi.getIndexConfig(widget.websiteId);
    return cfg.indexFiles;
  }

  void _reload() {
    setState(() {
      _future = _load();
      _loaded = false;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await WebsiteApi.updateIndexConfig(widget.websiteId, _items);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('默认文档已保存')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<String>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return SheetError(error: snap.error!, onRetry: _reload);
              }
              if (!_loaded) {
                _items = List.of(
                  snap.data ?? const ['index.html', 'index.htm'],
                );
                _loaded = true;
              }
              return SheetScroll(
                children: [
                  const Text(
                    '每行一个默认文档，按优先级从上到下匹配',
                    style: TextStyle(fontSize: 12, color: Color(0xFF686F78)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _items.join('\n')),
                    maxLines: 8,
                    onChanged: (v) {
                      _items = v
                          .split('\n')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'index.html\nindex.htm',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SheetSaveBar(loading: _loading, onSave: _save),
      ],
    );
  }
}
