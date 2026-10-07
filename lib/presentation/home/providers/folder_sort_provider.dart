import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FolderSortOption {
  videoCountDesc('Most Videos'),
  videoCountAsc('Least Videos'),
  dateDesc('Latest Date'),
  dateAsc('Oldest Date'),
  nameAsc('Name (A → Z)'),
  nameDesc('Name (Z → A)');

  final String label;
  const FolderSortOption(this.label);
}

class FolderSortNotifier extends StateNotifier<FolderSortOption> {
  static const _prefKey = 'nitpliks_folder_sort_option';

  FolderSortNotifier() : super(FolderSortOption.videoCountDesc) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_prefKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < FolderSortOption.values.length) {
        state = FolderSortOption.values[savedIndex];
      }
    } catch (_) {}
  }

  Future<void> setSortOption(FolderSortOption option) async {
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, option.index);
    } catch (_) {}
  }
}

final folderSortProvider = StateNotifierProvider<FolderSortNotifier, FolderSortOption>((ref) {
  return FolderSortNotifier();
});
