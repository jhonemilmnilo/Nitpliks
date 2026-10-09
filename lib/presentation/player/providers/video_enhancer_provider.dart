import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoEnhanceMode {
  off,
  cinema,
  vivid,
  superCrisp;

  String get label {
    switch (this) {
      case VideoEnhanceMode.off:
        return 'Off';
      case VideoEnhanceMode.cinema:
        return 'Cinema';
      case VideoEnhanceMode.vivid:
        return 'Vivid';
      case VideoEnhanceMode.superCrisp:
        return 'Crisp';
    }
  }

  String get description {
    switch (this) {
      case VideoEnhanceMode.off:
        return 'Original untouched video colors';
      case VideoEnhanceMode.cinema:
        return 'Deep blacks, warm tones & rich contrast';
      case VideoEnhanceMode.vivid:
        return 'Punchy anime colors & vibrant pop';
      case VideoEnhanceMode.superCrisp:
        return 'Sharpened edges & maximum detail';
    }
  }
}

class VideoEnhanceNotifier extends StateNotifier<VideoEnhanceMode> {
  static const _prefKey = 'nitpliks_video_enhance_mode';

  VideoEnhanceNotifier() : super(VideoEnhanceMode.off) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_prefKey);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < VideoEnhanceMode.values.length) {
        state = VideoEnhanceMode.values[savedIndex];
      }
    } catch (_) {}
  }

  Future<void> setMode(VideoEnhanceMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, mode.index);
    } catch (_) {}
  }
}

final videoEnhanceProvider = StateNotifierProvider<VideoEnhanceNotifier, VideoEnhanceMode>((ref) {
  return VideoEnhanceNotifier();
});
