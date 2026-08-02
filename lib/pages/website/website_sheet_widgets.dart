import 'package:flutter/material.dart';

/// 网站模块通用弹层组件

/// 弹出一个带标题栏和滚动内容的底部弹层
Future<T?> showWebsiteSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  double initialSize = 0.7,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: initialSize,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

/// 弹层内的加载状态
class SheetLoading extends StatelessWidget {
  const SheetLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 弹层内的错误状态
class SheetError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const SheetError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// 弹层内的设置项分组标题
class SheetSectionTitle extends StatelessWidget {
  final String title;
  const SheetSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// 弹层内的保存按钮行
class SheetSaveBar extends StatelessWidget {
  final bool loading;
  final VoidCallback onSave;
  final String label;

  const SheetSaveBar({
    super.key,
    required this.loading,
    required this.onSave,
    this.label = '保存',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: loading ? null : onSave,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

/// 弹层内可滚动内容容器
class SheetScroll extends StatelessWidget {
  final List<Widget> children;
  const SheetScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: children,
    );
  }
}
