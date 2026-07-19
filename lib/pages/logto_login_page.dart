import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/logto_auth_provider.dart';

/// Logto 登录页 — 纯 UI，所有逻辑由 [logtoAuthProvider] 管理
class LogtoLoginPage extends ConsumerWidget {
  final Widget child;
  const LogtoLoginPage({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(logtoAuthProvider);

    if (auth.checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isLoggedIn) return child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/Tianxuan.svg',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 24),
              Text('天璇 Tianxuan',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('1Panel 第三方管理器',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(logtoAuthProvider.notifier).login();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('使用 Logto 登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('跳过登录（开发模式）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
