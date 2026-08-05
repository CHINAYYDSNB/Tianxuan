import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// PHP 版本切换弹层
void showPhpSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: 'PHP 版本',
    initialSize: 0.5,
    child: PhpSheet(websiteId: websiteId),
  );
}

class PhpSheet extends StatefulWidget {
  final int websiteId;
  const PhpSheet({super.key, required this.websiteId});

  @override
  State<PhpSheet> createState() => _PhpSheetState();
}

class _PhpSheetState extends State<PhpSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _future = WebsiteApi.getPhpRuntimes();
  }

  Future<void> _switch(int runtimeId) async {
    setState(() => _switching = true);
    try {
      await WebsiteApi.switchPhpVersion(widget.websiteId, runtimeId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PHP 版本切换成功')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('切换失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '选择要切换的 PHP 运行环境',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '加载 PHP 环境失败: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    '未找到已安装的 PHP 运行环境\n可在服务器 1Panel 中安装',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = list[i];
                  final id = (item['id'] as num?)?.toInt() ?? 0;
                  final name = item['name']?.toString() ?? '';
                  return ListTile(
                    leading: const Icon(Icons.code, color: Colors.deepPurple),
                    title: Text(name),
                    subtitle: Text(id.toString()),
                    trailing: _switching
                        ? null
                        : const Icon(Icons.chevron_right, size: 18),
                    onTap: _switching ? null : () => _switch(id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
