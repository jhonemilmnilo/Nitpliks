import 'dart:io';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoThumbnailService {
  static final FcNativeVideoThumbnail _plugin = FcNativeVideoThumbnail();
  static String? _cacheDirPath;

  /// In-memory cache for fast UI access
  static final Map<String, String> _memoryCache = {};

  /// Fast synchronous lookup from memory cache
  static String? getCachedThumbnailPath(String videoPath) {
    if (_memoryCache.containsKey(videoPath)) {
      final cached = _memoryCache[videoPath]!;
      if (File(cached).existsSync()) {
        return cached;
      }
    }
    return null;
  }

  static Future<String> _getCacheDirectory() async {
    if (_cacheDirPath != null) return _cacheDirPath!;
    final tempDir = await getTemporaryDirectory();
    final thumbDir = Directory(p.join(tempDir.path, 'video_thumbnails_1m'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    _cacheDirPath = thumbDir.path;
    return _cacheDirPath!;
  }

  /// Get thumbnail file path captured at 1 minute (or midpoint if under 1 minute)
  static Future<String?> getThumbnailPath({
    required String videoPath,
    required Duration duration,
  }) async {
    if (videoPath.isEmpty || !File(videoPath).existsSync()) {
      return null;
    }

    if (_memoryCache.containsKey(videoPath)) {
      final cached = _memoryCache[videoPath]!;
      if (File(cached).existsSync()) {
        return cached;
      }
    }

    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = 'thumb_1m_${videoPath.hashCode}.jpg';
      final destPath = p.join(cacheDir, fileName);

      final destFile = File(destPath);
      if (await destFile.exists() && await destFile.length() > 0) {
        _memoryCache[videoPath] = destPath;
        return destPath;
      }

      // Calculate timestamp: 1 minute (60,000ms), or halfway if < 60s
      int seekTimeMs;
      final totalMs = duration.inMilliseconds;

      if (totalMs > 60000) {
        seekTimeMs = 60000; // 1 minute mark
      } else if (totalMs > 3000) {
        seekTimeMs = totalMs ~/ 2; // Midpoint
      } else {
        seekTimeMs = totalMs > 500 ? 500 : 0;
      }

      final success = await _plugin.saveThumbnailToFile(
        srcFile: videoPath,
        destFile: destPath,
        width: 320,
        height: 180,
        format: 'jpeg',
        quality: 85,
        at: FcVideoThumbnailTime(seekTimeMs, FcVideoThumbnailTimeUnit.milliseconds),
      );

      if (success && await destFile.exists() && await destFile.length() > 0) {
        _memoryCache[videoPath] = destPath;
        return destPath;
      }

      return null;
    } catch (e) {
      debugPrint('Error generating 1m thumbnail for $videoPath: $e');
      return null;
    }
  }
}
