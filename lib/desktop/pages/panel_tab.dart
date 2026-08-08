import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/desktop_server.dart';

/// 面板网页标签页：打开 1Panel/宝塔面板网站。
class PanelTab extends StatefulWidget {
  final DesktopServer server;
  const PanelTab({super.key, required this.server});

  @override
  State<PanelTab> createState() => _PanelTabState();
}

class _PanelTabState extends State<PanelTab> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (e) => setState(() => _error = e.description),
        ),
      );
    final url = widget.server.panelUrl;
    if (url != null && url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.server.panelUrl;
    if (url == null || url.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('未配置面板网址'),
            const SizedBox(height: 8),
            Text(
              '在服务器编辑中填写 1Panel/宝塔 面板地址后即可在此打开',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(Icons.error, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '页面加载异常: $_error',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
