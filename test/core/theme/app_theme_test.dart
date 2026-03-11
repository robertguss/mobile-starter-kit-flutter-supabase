import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/core/theme/app_colors.dart';
import 'package:flutter_supabase_starter/core/theme/app_theme.dart';
import 'package:flutter_supabase_starter/core/theme/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme uses Material 3 and shared light surface', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.lightSurface);
    expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
  });

  test('dark theme uses Material 3 and shared dark surface', () {
    final theme = AppTheme.dark;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.darkSurface);
    expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
  });

  test('typography applies on-surface colors to body and display text', () {
    const colorScheme = ColorScheme.light(onSurface: Colors.red);

    final textTheme = AppTypography.textTheme(colorScheme);

    expect(textTheme.bodyMedium?.color, Colors.red);
    expect(textTheme.headlineSmall?.color, Colors.red);
  });
}
