import 'package:flutter_test/flutter_test.dart';
import 'package:smartumc/core/design_system/app_colors.dart';
import 'package:smartumc/core/design_system/app_theme.dart';

void main() {
  test('light theme uses the approved SmartUMC palette and Inter', () {
    final theme = AppTheme.light;

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.colorScheme.secondary, AppColors.brandCyan);
    expect(theme.colorScheme.primary, AppColors.actionBlue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.inputDecorationTheme.fillColor, AppColors.paleBlue);
  });
}
