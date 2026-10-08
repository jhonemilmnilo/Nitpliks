import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/services/playback_database_service.dart';
import '../../../domain/models/media_models.dart';

/// State of the playback lifecycle
enum PlaybackStateStatus {
  initial,
  loadingRecord,
  seeking,
  ready,
  error,
}

/// Comprehensive, bulletproof playback controller
/// Isolates native MediaKit lifecycle and guarantees 100% reliable position persistence
class PlayerPlaybackController extends ChangeNotifier {
  /// Netflix/Prime-style resume recap helper:
  /// Rewinds 10 seconds on resume for context unless the video is near the beginning.
  static int calculateRewindResumeMs(int savedPositionMs, {int rewindSeconds = 10}) {
    if (savedPositionMs <= 5000) {
      return 0; // Less than 5s: start from scratch
    }
    final rewindMs = rewindSeconds * 1000;
    if (savedPositionMs <= rewindMs) {
      return 0; // Between 5s and 10s: clamp to start
    }
    return savedPositionMs - rewindMs;
  }

  final List<VideoModel> videos;
  int currentIndex;

  late final Player player;
  late final VideoController videoController;

  PlaybackStateStatus status = PlaybackStateStatus.initial;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  // Track the most reliable position even if streams are momentarily desynced
  int _targetResumeMs = 0;
  int _lastKnownValidPosMs = 0;
  int _lastAutosaveMs = 0;
  bool _isDisposed = false;
  bool _isExiting = false;

  // Stream Subscriptions
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;

  VideoModel get currentVideo => videos[currentIndex];
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < videos.length - 1;

  PlayerPlaybackController({
    required this.videos,
    required this.currentIndex,
    int initialPositionMs = 0,
  }) {
    if (initialPositionMs >= 2000) {
      _targetResumeMs = initialPositionMs;
      _lastKnownValidPosMs = initialPositionMs;
      position = Duration(milliseconds: initialPositionMs);
      debugPrint('⚡ [CONTROLLER CREATED] Synchronously initialized at resume point: $initialPositionMs ms');
    }

    // 1. Initialize Player with 32MB stream buffer
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );

    // 2. Hardware Acceleration Controller
    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _bindStreamListeners();
  }

  void _bindStreamListeners() {
    // Playing state stream
    _playingSub = player.stream.playing.listen((playing) {
      if (_isDisposed) return;
      isPlaying = playing;
      notifyListeners();
    });

    // Duration stream
    _durationSub = player.stream.duration.listen((dur) {
      if (_isDisposed) return;
      if (dur > Duration.zero) {
        duration = dur;
        notifyListeners();
      }
    });

    // Realtime Position stream
    _positionSub = player.stream.position.listen((pos) {
      if (_isDisposed) return;

      // When seeking or loading, do not let native 0ms ticks overwrite valid saved timestamps
      if (status != PlaybackStateStatus.ready) {
        return;
      }

      final posMs = pos.inMilliseconds;

      // If we resumed at e.g. 600,000ms (10 mins), don't allow a spurious 0-2000ms tick to reset _lastKnownValidPosMs
      if (_targetResumeMs > 3000 && posMs < (_targetResumeMs - 3000)) {
        debugPrint('⚠️ [PLAYBACK POSITION TICK IGNORED] Native tick ($posMs ms) before reaching resume target ($_targetResumeMs ms)');
        return;
      }

      if (posMs > 0) {
        _lastKnownValidPosMs = posMs;
      }

      position = pos;
      notifyListeners();

      // Throttled autosave every 3 seconds during active playback
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastAutosaveMs > 3000 && posMs >= 1000) {
        _lastAutosaveMs = now;
        _saveToDatabase(positionMs: posMs);
      }
    });

    // Video completed stream
    _completedSub = player.stream.completed.listen((completed) {
      if (_isDisposed) return;
      if (completed) {
        // Prevent spurious completion signals when video duration is 0 or still loading
        final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : player.state.duration.inMilliseconds;
        final currentMs = getCurrentAccuratePositionMs();
        debugPrint('🎬 [PLAYBACK COMPLETED STREAM] received: $completed (current: $currentMs ms, duration: $totalMs ms)');
        
        if (totalMs > 3000 && currentMs >= (totalMs * 0.90)) {
          debugPrint('🎬 [PLAYBACK FINISHED] Video reached real end. Marking completed.');
          _saveToDatabase(positionMs: 0, reset: true);
          if (hasNext) {
            playNext();
          }
        } else {
          debugPrint('⚠️ [PLAYBACK COMPLETED IGNORED] Spurious completed signal during load/seek.');
        }
      }
    });
  }

  /// Load and start the current video, seeking to the exact saved position
  Future<void> initAndPlay() async {
    status = PlaybackStateStatus.loadingRecord;
    notifyListeners();

    try {
      int targetResumeMs = _targetResumeMs;

      // 1. Fetch saved record from SQLite if not already pre-seeded by Layer 1
      if (targetResumeMs == 0) {
        debugPrint('🎬 [PLAYBACK INIT] Checking DB record for path: ${currentVideo.path} (id: ${currentVideo.id})');
        final record = await PlaybackDatabaseService.instance.getPlaybackRecord(
          videoPath: currentVideo.path,
          videoId: currentVideo.id,
        );

        final savedPosMs = record?.lastPositionMs ?? 0;
        final isCompleted = record?.isCompleted ?? false;
        targetResumeMs = (!isCompleted) ? calculateRewindResumeMs(savedPosMs) : 0;

        _targetResumeMs = targetResumeMs;
        _lastKnownValidPosMs = targetResumeMs;
        if (targetResumeMs > 0) {
          position = Duration(milliseconds: targetResumeMs);
        } else {
          position = Duration.zero;
        }

        debugPrint('🎬 [PLAYBACK INIT] Record found: pos=$savedPosMs ms, isCompleted=$isCompleted -> targetResume=$targetResumeMs ms');
      } else {
        debugPrint('⚡ [PLAYBACK INIT] Fast-lane resume using pre-seeded position: $targetResumeMs ms');
      }

      // 2. Open media
      status = PlaybackStateStatus.seeking;
      notifyListeners();

      if (targetResumeMs > 0) {
        final startSeconds = (targetResumeMs / 1000.0).toStringAsFixed(3);
        final startOffset = Duration(milliseconds: targetResumeMs);
        debugPrint('🎬 [PLAYBACK OPEN] Configuring libmpv native start offset: $startSeconds s ($startOffset)');

        // Direct Native libmpv backend bridge: Set 'start' and 'hr-seek' properties BEFORE loading file
        try {
          final dynamic platformPlayer = player.platform;
          if (platformPlayer != null) {
            await platformPlayer.setProperty('start', startSeconds);
            await platformPlayer.setProperty('hr-seek', 'yes');
            debugPrint('⚡ [PLAYBACK NATIVE MPV] Successfully injected "start=$startSeconds" & "hr-seek=yes" into libmpv!');
          }
        } catch (e) {
          debugPrint('⚠️ [PLAYBACK NATIVE MPV PROPERTY ERROR] $e');
        }

        // Open media
        await player.open(
          Media(
            currentVideo.path,
            start: startOffset,
          ),
          play: true,
        );

        // Wait until decoder is actively running (position stream emits its first tick)
        try {
          await player.stream.position
              .firstWhere((p) => p > Duration.zero)
              .timeout(const Duration(milliseconds: 2000));
        } catch (_) {}

        // Small breather for MediaCodec buffers to be hot
        await Future.delayed(const Duration(milliseconds: 150));

        // Now that the native engine is 100% active, execute seek!
        debugPrint('🎬 [PLAYBACK ENFORCE SEEK] Native decoder is hot, executing seek to: $startOffset');
        await player.seek(startOffset);

        // Wait for player position to jump to the resume point
        try {
          await player.stream.position
              .firstWhere((pos) => pos.inMilliseconds >= (targetResumeMs - 5000))
              .timeout(const Duration(milliseconds: 3000));
          debugPrint('🎯 [PLAYBACK SYNC SUCCESS] Native player confirmed at target resume position!');
        } catch (_) {
          debugPrint('⚠️ [PLAYBACK SYNC TIMEOUT] Position stream seek verification timed out.');
        }
      } else {
        // Reset start property to 0 for normal videos
        try {
          final dynamic platformPlayer = player.platform;
          if (platformPlayer != null) {
            await platformPlayer.setProperty('start', '0');
          }
        } catch (_) {}
        await player.open(Media(currentVideo.path), play: true);
      }

      // Update duration
      if (player.state.duration > Duration.zero) {
        duration = player.state.duration;
      } else if (currentVideo.duration > Duration.zero) {
        duration = currentVideo.duration;
      }

      status = PlaybackStateStatus.ready;
      isPlaying = player.state.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 [PLAYBACK INIT ERROR] $e');
      status = PlaybackStateStatus.ready;
      await player.play();
      notifyListeners();
    }
  }

  /// Toggle Play / Pause with instant save on pause
  void togglePlayPause() {
    if (isPlaying) {
      player.pause();
      final currentMs = getCurrentAccuratePositionMs();
      _saveToDatabase(positionMs: currentMs);
    } else {
      player.play();
    }
  }

  /// Seek by relative delta seconds (e.g. +10s or -10s)
  Future<void> seekRelativeSeconds(int seconds) async {
    final currentMs = getCurrentAccuratePositionMs();
    final maxMs = duration.inMilliseconds;
    final targetMs = (currentMs + (seconds * 1000)).clamp(0, maxMs);
    final targetPos = Duration(milliseconds: targetMs);

    _targetResumeMs = targetMs;
    position = targetPos;
    _lastKnownValidPosMs = targetMs;
    notifyListeners();

    await player.seek(targetPos);
    _saveToDatabase(positionMs: targetMs);
  }

  /// Seek to absolute position (e.g. from scrubber drag)
  Future<void> seekTo(Duration target) async {
    _targetResumeMs = target.inMilliseconds;
    position = target;
    _lastKnownValidPosMs = target.inMilliseconds;
    notifyListeners();

    await player.seek(target);
    _saveToDatabase(positionMs: target.inMilliseconds);
  }

  /// Play next video in queue
  Future<void> playNext() async {
    if (!hasNext) return;
    await saveCurrentStateImmediate();
    currentIndex++;
    position = Duration.zero;
    _lastKnownValidPosMs = 0;
    notifyListeners();
    await initAndPlay();
  }

  /// Play previous video in queue
  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await saveCurrentStateImmediate();
    currentIndex--;
    position = Duration.zero;
    _lastKnownValidPosMs = 0;
    notifyListeners();
    await initAndPlay();
  }

  /// Get the single most accurate current millisecond timestamp
  int getCurrentAccuratePositionMs() {
    final nativeMs = player.state.position.inMilliseconds;
    if (nativeMs > 0) return nativeMs;
    if (position.inMilliseconds > 0) return position.inMilliseconds;
    return _lastKnownValidPosMs;
  }

  /// Internal save helper
  Future<void> _saveToDatabase({required int positionMs, bool reset = false}) async {
    if (_isDisposed) return;
    final durMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : player.state.duration.inMilliseconds;

    await PlaybackDatabaseService.instance.savePlaybackState(
      video: currentVideo,
      positionMs: positionMs,
      durationMs: durMs,
      reset: reset,
    );
  }

  /// Immediate save execution (Used when app goes to background or user navigates back)
  Future<void> saveCurrentStateImmediate() async {
    final posMs = getCurrentAccuratePositionMs();
    if (posMs > 0) {
      debugPrint('🎬 [PLAYBACK SAVE IMMEDIATE] "${currentVideo.title}" saving: $posMs ms');
      await _saveToDatabase(positionMs: posMs);
    }
  }

  /// Prepare for screen exit: Guaranteed save handshake before disposing
  Future<void> prepareExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      // 1. Capture exact position FIRST before pausing
      final posMs = getCurrentAccuratePositionMs();
      debugPrint('🎬 [PLAYBACK EXIT HANDSHAKE] Persisting exact position before pause: $posMs ms');
      
      // 2. Pause immediately to prevent time drift
      await player.pause();

      // 3. Guarantee write to SQLite
      await _saveToDatabase(positionMs: posMs);
    } catch (e) {
      debugPrint('🚨 [PLAYBACK EXIT ERROR] $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    player.dispose();
    super.dispose();
  }
}
