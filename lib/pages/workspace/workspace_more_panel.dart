import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../script_store/script_store_page.dart';
import '../ssh/ssh_home_page.dart';

/// 更多功能入口定义
class MoreEntry {
  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const MoreEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

/// 全部可选「更多」入口
final List<MoreEntry> kMoreEntries = [
  MoreEntry(
    id: 'ssh',
    title: 'SSH 终端',
    icon: Icons.terminal,
    builder: (_) => const SshHomePage(),
  ),
  MoreEntry(
    id: 'scripts',
    title: '脚本商店',
    icon: Icons.article_outlined,
    builder: (_) => const ScriptStorePage(),
  ),
];

/// 持久化 key
const _prefsKey = 'workspace_more_entries_v1';

/// 读取用户自定义的入口启用状态（默认全开）
Future<Set<String>> loadEnabledMoreIds() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_prefsKey);
  if (raw == null) return kMoreEntries.map((e) => e.id).toSet();
  try {
    final list = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    if (list.isEmpty) return kMoreEntries.map((e) => e.id).toSet();
    return list.toSet();
  } catch (_) {
    return kMoreEntries.map((e) => e.id).toSet();
  }
}

/// 保存用户自定义的入口启用状态
Future<void> saveEnabledMoreIds(Set<String> ids) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_prefsKey, jsonEncode(ids.toList()));
}

/// 弹出「更多」功能入口面板（支持编辑模式）
Future<void> showWorkspaceMorePanel(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _MorePanel(),
  );
}

class _MorePanel extends StatefulWidget {
  const _MorePanel();

  @override
  State<_MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends State<_MorePanel> {
  bool _editing = false;
  Set<String> _enabled = kMoreEntries.map((e) => e.id).toSet();

  @override
  void initState() {
    super.initState();
    loadEnabledMoreIds().then((ids) {
      if (mounted) setState(() => _enabled = ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _editing
        ? kMoreEntries
        : kMoreEntries.where((e) => _enabled.contains(e.id)).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '功能',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (!_editing)
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('编辑'),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      saveEnabledMoreIds(_enabled);
                      setState(() => _editing = false);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('完成'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '暂无功能，点击右上角「编辑」添加',
                    style: TextStyle(color: Color(0xFF9AA1A9)),
                  ),
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: visible.map((e) {
                  final on = _enabled.contains(e.id);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (_editing) {
                        setState(() {
                          if (on) {
                            _enabled.remove(e.id);
                          } else {
                            _enabled.add(e.id);
                          }
                        });
                      } else {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: e.builder),
                        );
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6F7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                e.icon,
                                size: 24,
                                color: _editing && !on
                                    ? const Color(0xFFC0C5CC)
                                    : const Color(0xFF0C1014),
                              ),
                            ),
                            if (_editing)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: on
                                        ? const Color(0xFF0C1014)
                                        : const Color(0xFFE0E3E8),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: on
                                      ? const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: _editing && !on
                                ? const Color(0xFFC0C5CC)
                                : const Color(0xFF4A5057),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE8E9EB)),
            const SizedBox(height: 8),
            Text(
              _editing ? '勾选需要展示的功能' : '点击功能即可打开',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9AA1A9)),
            ),
          ],
        ),
      ),
    );
  }
}
