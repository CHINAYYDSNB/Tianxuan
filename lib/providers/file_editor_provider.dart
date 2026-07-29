import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/file_service.dart';

/// 编辑器状态
class FileEditorState {
  final String fileName;
  final String path;
  final String text;
  final int totalLines;
  final int pageSize;
  final int currentPage;
  final bool fullyLoaded;
  final bool loading;
  final bool saving;
  final bool modified;
  final String? error;

  const FileEditorState({
    required this.fileName,
    required this.path,
    this.text = '',
    this.totalLines = 0,
    this.pageSize = 200,
    this.currentPage = 1,
    this.fullyLoaded = false,
    this.loading = false,
    this.saving = false,
    this.modified = false,
    this.error,
  });

  FileEditorState copyWith({
    String? text,
    int? totalLines,
    int? pageSize,
    int? currentPage,
    bool? fullyLoaded,
    bool? loading,
    bool? saving,
    bool? modified,
    String? error,
  }) => FileEditorState(
    fileName: fileName,
    path: path,
    text: text ?? this.text,
    totalLines: totalLines ?? this.totalLines,
    pageSize: pageSize ?? this.pageSize,
    currentPage: currentPage ?? this.currentPage,
    fullyLoaded: fullyLoaded ?? this.fullyLoaded,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    modified: modified ?? this.modified,
    error: error ?? this.error,
  );
}

/// 编辑器控制器：通过 [FileService.readByLine] 分块加载（大文件不全量 GET），
/// 聚合为可编辑文本；保存时整体写回。
class FileEditorController extends StateNotifier<FileEditorState> {
  FileEditorController(this._ref, this._path, String fileName)
    : super(FileEditorState(fileName: fileName, path: _path)) {
    load();
  }

  final Ref _ref;
  final String _path;

  FileService get _svc => _ref.watch(fileServiceProvider);

  /// 对外暴露的修改标记（避免直接访问受保护的 state）
  bool get isModified => state.modified;

  /// 安全加载页数上限，避免超大文件无限拉取
  static const _maxPages = 200;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final buffer = StringBuffer();
      var page = 1;
      var totalLines = 0;
      var fullyLoaded = false;
      while (page <= _maxPages) {
        final res = await _svc.readByLine(
          _path,
          page: page,
          pageSize: state.pageSize,
        );
        totalLines = res.totalLines;
        buffer.writeln(res.lines.join('\n'));
        if (res.end) {
          fullyLoaded = true;
          break;
        }
        page++;
      }
      // 去除末尾多余换行
      var text = buffer.toString();
      if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
      state = state.copyWith(
        text: text,
        totalLines: totalLines,
        currentPage: 1,
        fullyLoaded: fullyLoaded,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void onChanged() {
    if (!state.modified) state = state.copyWith(modified: true);
  }

  Future<void> save(String content) async {
    if (state.saving) return;
    state = state.copyWith(saving: true, error: null);
    try {
      await _svc.save(_path, content);
      state = state.copyWith(saving: false, modified: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }
}

final fileEditorProvider =
    StateNotifierProvider.family<
      FileEditorController,
      FileEditorState,
      (String, String)
    >((ref, args) => FileEditorController(ref, args.$1, args.$2));
