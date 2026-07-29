import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/file_editor_provider.dart';
import '../../utils/code_language.dart';

class FileEditorPage extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;

  const FileEditorPage({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  ConsumerState<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends ConsumerState<FileEditorPage> {
  late final CodeController _codeCtrl;
  bool _initialized = false;

  FileEditorController get _editor =>
      ref.read(fileEditorProvider((widget.filePath, widget.fileName)).notifier);

  @override
  void initState() {
    super.initState();
    _codeCtrl = CodeController();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _syncInitialText(String text) {
    if (!_initialized && text.isNotEmpty) {
      _codeCtrl.text = text;
      _initialized = true;
    }
  }

  Future<void> _save() async {
    await _editor.save(_codeCtrl.text);
  }

  Future<bool> _onWillPop() async {
    final modified = _editor.isModified;
    if (!modified) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('内容已修改，是否保存？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return true;
    }
    return result == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      fileEditorProvider((widget.filePath, widget.fileName)),
    );
    _syncInitialText(state.text);

    return PopScope(
      canPop: !state.modified,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
          actions: [
            if (state.modified)
              TextButton.icon(
                onPressed: state.saving ? null : _save,
                icon: state.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(state.saving ? '保存中...' : '保存'),
              ),
          ],
        ),
        body: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(FileEditorState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                state.error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _editor.load(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final lang = codeLanguageForExtension(widget.fileName.split('.').last);
    _codeCtrl.language = lang;
    return Column(
      children: [
        if (!state.fullyLoaded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              '文件较大，仅加载了前 ${state.totalLines} 行，保存将覆盖已加载部分',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: CodeField(
            controller: _codeCtrl,
            onChanged: (_) => _editor.onChanged(),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
