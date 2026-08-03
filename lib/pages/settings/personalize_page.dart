import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/app_theme.dart';
import '../../providers/theme_provider.dart';

/// 个性化设置页：主题配色 + 背景
class PersonalizePage extends ConsumerWidget {
  const PersonalizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('个性化')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题配色
          _sectionTitle(context, '主题配色'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: appColorSchemes.map((s) {
              final selected = theme.schemeId == s.id;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => notifier.setScheme(s.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: s.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? s.primary : const Color(0xFFE0E3EC),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: s.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: s.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 背景
          _sectionTitle(context, '背景'),
          SegmentedButton<AppBackgroundType>(
            segments: const [
              ButtonSegment(
                value: AppBackgroundType.solid,
                label: Text('纯色'),
                icon: Icon(Icons.format_color_fill, size: 16),
              ),
              ButtonSegment(
                value: AppBackgroundType.custom,
                label: Text('相册'),
                icon: Icon(Icons.photo_library, size: 16),
              ),
            ],
            selected: {theme.backgroundType},
            onSelectionChanged: (v) {
              final type = v.first;
              if (type == AppBackgroundType.solid) {
                notifier.setBackgroundType(AppBackgroundType.solid);
              } else if (type == AppBackgroundType.custom) {
                notifier.setBackgroundType(AppBackgroundType.custom);
              }
            },
          ),
          const SizedBox(height: 12),

          // 相册选图
          if (theme.backgroundType == AppBackgroundType.custom)
            _customBackground(context, theme, notifier),

          // 模糊强度
          const SizedBox(height: 24),
          _sectionTitle(context, '背景模糊'),
          Row(
            children: [
              const Icon(Icons.blur_on, size: 20),
              Expanded(
                child: Slider(
                  value: theme.backgroundBlur,
                  max: 1.0,
                  divisions: 10,
                  label: '${(theme.backgroundBlur * 100).round()}%',
                  onChanged: (v) => notifier.setBackgroundBlur(v),
                ),
              ),
              Text('${(theme.backgroundBlur * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF686F78),
        ),
      ),
    );
  }

  Widget _customBackground(
    BuildContext context,
    AppTheme theme,
    ThemeNotifier notifier,
  ) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
            );
            if (result != null && result.files.single.path != null) {
              await notifier.setBackgroundPath(result.files.single.path);
            }
          },
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('选择背景图片'),
        ),
        const SizedBox(height: 8),
        if (theme.backgroundPath != null && theme.backgroundPath!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(theme.backgroundPath!),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }
}
