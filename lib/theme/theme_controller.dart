import 'package:flutter/material.dart';

import '../data/local/prefs_store.dart';

/// 可选主题色。
class ThemePalette {
  const ThemePalette(this.name, this.seed);

  final String name;
  final Color seed;

  static const List<ThemePalette> all = <ThemePalette>[
    ThemePalette('南航蓝', Color(0xFF2F6FD0)),
    ThemePalette('青碧', Color(0xFF0E8C8C)),
    ThemePalette('黛紫', Color(0xFF7B61C9)),
    ThemePalette('松绿', Color(0xFF2E8B57)),
    ThemePalette('赭橙', Color(0xFFC96A2B)),
    ThemePalette('玫红', Color(0xFFC24D74)),
  ];

  static Color seedOf(int? argb) => argb == null ? all.first.seed : Color(argb);

  static String nameOf(Color seed) => all
      .firstWhere(
        (p) => p.seed.toARGB32() == seed.toARGB32(),
        orElse: () => all.first,
      )
      .name;
}

/// 主题控制器：外观模式（浅色 / 深色 / 跟随系统）+ 主题色，均持久化。
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _mode = _parse(_prefs.getString(PrefsKeys.themeMode));
    _seed = ThemePalette.seedOf(_prefs.getInt(PrefsKeys.themeSeed));
  }

  final PrefsStore _prefs;
  ThemeMode _mode = ThemeMode.system;
  Color _seed = ThemePalette.all.first.seed;

  ThemeMode get mode => _mode;

  Color get seed => _seed;

  String get seedName => ThemePalette.nameOf(_seed);

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(PrefsKeys.themeMode, _serialize(mode));
  }

  Future<void> setSeed(Color seed) async {
    if (_seed.toARGB32() == seed.toARGB32()) return;
    _seed = seed;
    notifyListeners();
    await _prefs.setInt(PrefsKeys.themeSeed, seed.toARGB32());
  }

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  static String description(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '随系统的深浅色设置自动切换',
        ThemeMode.light => '始终使用浅色配色',
        ThemeMode.dark => '始终使用深色配色',
      };

  static String _serialize(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  static ThemeMode _parse(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
