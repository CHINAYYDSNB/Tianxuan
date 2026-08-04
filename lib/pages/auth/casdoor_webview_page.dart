import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/logto_auth_provider.dart';

/// Casdoor 内嵌登录页（webview）
///
/// 加载 Casdoor 授权 URL（自带 GEETEST / 快捷登录 / 注册入口），
/// 授权完成后跳转到 `com.tianxuan.app://callback?code=...&state=...`，
/// 通过 onNavigationRequest / onUrlChange 拦截并交给 provider 换 token。
class CasdoorWebviewPage extends ConsumerStatefulWidget {
  /// 若指定，则加载对应第三方快捷登录授权页
  final String? providerName;

  const CasdoorWebviewPage({super.key, this.providerName});

  @override
  ConsumerState<CasdoorWebviewPage> createState() => _CasdoorWebviewPageState();
}

class _CasdoorWebviewPageState extends ConsumerState<CasdoorWebviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          _handleUrl(request.url);
          return NavigationDecision.navigate;
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) _handleUrl(url);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
    _load();
  }

  void _handleUrl(String url) {
    if (_done) return;
    if (!url.startsWith('com.tianxuan.app://')) return;
    final uri = Uri.parse(url);
    // 交给 provider 交换 token
    ref.read(logtoAuthProvider.notifier).handleWebviewCallback(uri).then((ok) {
      if (!mounted || _done) return;
      _done = true;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录失败，请重试')));
      }
    });
  }

  Future<void> _load() async {
    try {
      final url = await ref
          .read(logtoAuthProvider.notifier)
          .buildWebviewLoginUrl(provider: widget.providerName);
      await _controller.loadRequest(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开登录页失败: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号登录')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
