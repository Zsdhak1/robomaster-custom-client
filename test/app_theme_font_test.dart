import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/theme/app_theme.dart';
import 'package:robomaster_custom_client_1/core/theme/text_theme.dart';

void main() {
  test('应用主题与响应式文本主题统一使用 MiSans', () {
    final theme = buildTeamTheme(rmBlueTeamColor);
    final responsiveTextTheme = scaledTextThemeByFactor(1.0);

    expect(theme.textTheme.bodyMedium?.fontFamily, appFontFamily);
    expect(responsiveTextTheme.titleMedium?.fontFamily, appFontFamily);
  });
}
