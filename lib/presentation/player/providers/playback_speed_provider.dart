import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackSpeedNotifier extends StateNotifier<double> {
  static const _prefKey = 'nitpliks_playback_speed';

  PlaybackSpeedNotifier() : super(1.0) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSpeed = prefs.getDouble(_prefKey);
      if (savedSpeed != null && savedSpeed > 0) {
        state = savedSpeed;
      }
    } catch (_) {}
  }

  Future<void> setSpeed(double speed) async {
    state = speed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, speed);
    } catch (_) {}
  }
}

final playbackSpeedProvider = StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier();
});
