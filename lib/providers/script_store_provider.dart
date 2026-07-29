import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/script_store_api.dart';
import '../models/script_store_item.dart';

/// 商店索引
final scriptIndexProvider = FutureProvider<ScriptIndex>((ref) {
  return ScriptStoreApi.fetchIndex();
});

/// 脚本详情 (family 按 id)
final scriptDetailProvider = FutureProvider.family<ScriptDetail, String>((
  ref,
  id,
) {
  return ScriptStoreApi.fetchDetail(id);
});

/// 搜索关键词
final scriptSearchProvider = StateProvider<String>((ref) => '');

/// 下载状态
enum ScriptDownloadState {
  idle,
  downloading,
  preview,
  confirmed,
  running,
  done,
  failed,
}

final scriptDownloadStateProvider =
    StateNotifierProvider<ScriptDownloadStateNotifier, ScriptDownloadState>(
      (ref) => ScriptDownloadStateNotifier(),
    );

class ScriptDownloadStateNotifier extends StateNotifier<ScriptDownloadState> {
  ScriptDownloadStateNotifier() : super(ScriptDownloadState.idle);

  void downloading() => state = ScriptDownloadState.downloading;
  void preview() => state = ScriptDownloadState.preview;
  void confirm() => state = ScriptDownloadState.confirmed;
  void running() => state = ScriptDownloadState.running;
  void done() => state = ScriptDownloadState.done;
  void failed() => state = ScriptDownloadState.failed;
  void reset() => state = ScriptDownloadState.idle;
}

final scriptContentProvider = StateProvider<String?>((ref) => null);
