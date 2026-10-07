import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoSortOption {
  dateDesc('Latest Added'),
  dateAsc('Oldest Added'),
  sizeDesc('Largest Size'),
  sizeAsc('Smallest Size'),
  durationDesc('Longest Duration'),
  durationAsc('Shortest Duration'),
  titleAsc('Title (A → Z)'),
  titleDesc('Title (Z → A)');

  final String label;
  const VideoSortOption(this.label);
}

class VideoSortNotifier extends StateNotifier<VideoSortOption> {
  static const _prefKey = 'nitpliks_video_sort_option';

  VideoSortNotifier() : super(VideoSortOption.dateDesc) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_prefKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < VideoSortOption.values.length) {
        state = VideoSortOption.values[savedIndex];
      }
    } catch (_) {}
  }

  Future<void> setSortOption(VideoSortOption option) async {
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, option.index);
    } catch (_) {}
  }
}

final videoSortProvider = StateNotifierProvider<VideoSortNotifier, VideoSortOption>((ref) {
  return VideoSortNotifier();
});
