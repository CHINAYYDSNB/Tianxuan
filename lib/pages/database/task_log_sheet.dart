import 'package:flutter/material.dart';
import '../../models/task_log.dart';
import '../../providers/backup_provider.dart';

Future<void> showTaskLogSheet(BuildContext context, {required String taskID}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskLogSheet(taskID: taskID),
  );
}

class TaskLogSheet extends StatefulWidget {
  final String taskID;

  const TaskLogSheet({super.key, required this.taskID});

  @override
  State<TaskLogSheet> createState() => _TaskLogSheetState();
}

class _TaskLogSheetState extends State<TaskLogSheet> {
  TaskLogPoller? _poller;
  TaskLog? _log;
  String? _error;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _poller = TaskLogPoller.forTask(widget.taskID);
    _poller!.onUpdate = (log) {
      if (!mounted) return;
      setState(() => _log = log);
      _scrollToBottom();
    };
    _poller!.onError = (e) {
      if (!mounted) return;
      setState(() => _error = e);
    };
    _poller!.start();
  }

  @override
  void dispose() {
    _poller?.stop();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final executing = log?.isExecuting ?? true;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                executing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '任务日志',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (log != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (executing ? Colors.blue : Colors.green)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.taskStatus.isEmpty
                          ? (executing ? '执行中' : '已完成')
                          : log.taskStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: executing ? Colors.blue : Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : log == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      log.lines.join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(executing ? '后台继续' : '完成'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
