import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/app_theme.dart';

void main() {
  group('AppColorScheme', () {
    test('包含 6 套预设配色且 ID 唯一', () {
      expect(appColorSchemes.length, 6);
      final ids = appColorSchemes.map((s) => s.id).toSet();
      expect(ids.length, appColorSchemes.length);
      for (final s in appColorSchemes) {
        expect(s.name, isNotEmpty);
        expect(s.id, isNotEmpty);
      }
    });

    test('包含简约黑默认主题', () {
      final tianxuan = appColorSchemes.firstWhere((s) => s.id == 'tianxuan');
      expect(tianxuan.name, '简约黑');
    });
  });

  group('AppTheme', () {
    test('默认主题是简约黑 + 纯色背景', () {
      const theme = AppTheme();
      expect(theme.schemeId, 'tianxuan');
      expect(theme.backgroundType, AppBackgroundType.solid);
      expect(theme.scheme.name, '简约黑');
    });

    test('copyWith 更新字段', () {
      const theme = AppTheme();
      final updated = theme.copyWith(schemeId: 'aurora', backgroundBlur: 0.5);
      expect(updated.schemeId, 'aurora');
      expect(updated.backgroundBlur, 0.5);
      expect(updated.scheme.name, '极光绿');
    });

    test('toJson / fromJson 往返', () {
      const theme = AppTheme(
        schemeId: 'rose',
        backgroundType: AppBackgroundType.asset,
        backgroundAsset: 'assets/x.png',
        backgroundBlur: 0.3,
      );
      final json = theme.toJson();
      final restored = AppTheme.fromJson(json);
      expect(restored.schemeId, 'rose');
      expect(restored.backgroundType, AppBackgroundType.asset);
      expect(restored.backgroundAsset, 'assets/x.png');
      expect(restored.backgroundBlur, 0.3);
    });

    test('未知 schemeId 回退到简约黑', () {
      final theme = AppTheme.fromJson({'schemeId': 'unknown'});
      expect(theme.scheme.name, '简约黑');
    });

    test('未知 backgroundType 回退到 solid', () {
      final theme = AppTheme.fromJson({'backgroundType': 'nope'});
      expect(theme.backgroundType, AppBackgroundType.solid);
    });
  });
}
