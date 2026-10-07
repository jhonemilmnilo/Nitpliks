import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palettes.dart';

class PaletteNotifier extends StateNotifier<AppPalette> {
  static const _prefKey = 'nitpliks_selected_palette_id';

  PaletteNotifier() : super(AppPalettes.cyberIndigo) {
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null) {
        state = AppPalettes.getById(savedId);
      }
    } catch (_) {}
  }

  Future<void> setPalette(AppPalette palette) async {
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, palette.id);
    } catch (_) {}
  }
}

final paletteProvider = StateNotifierProvider<PaletteNotifier, AppPalette>((ref) {
  return PaletteNotifier();
});
