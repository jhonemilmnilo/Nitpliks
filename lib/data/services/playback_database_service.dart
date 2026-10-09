import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../domain/models/media_models.dart';

/// Elite Playback History Record Model for SQLite
class PlaybackHistoryRecord {
  final int? id;
  final String videoPath;
  final String? videoId;
  final String title;
  final int lastPositionMs;
  final int durationMs;
  final bool isCompleted;
  final int lastPlayedAt;

  const PlaybackHistoryRecord({
    this.id,
    required this.videoPath,
    this.videoId,
    required this.title,
    required this.lastPositionMs,
    required this.durationMs,
    required this.isCompleted,
    required this.lastPlayedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'video_path': videoPath,
      'video_id': videoId,
      'title': title,
      'last_position_ms': lastPositionMs,
      'duration_ms': durationMs,
      'is_completed': isCompleted ? 1 : 0,
      'last_played_at': lastPlayedAt,
    };
  }

  factory PlaybackHistoryRecord.fromMap(Map<String, dynamic> map) {
    return PlaybackHistoryRecord(
      id: map['id'] as int?,
      videoPath: map['video_path'] as String,
      videoId: map['video_id'] as String?,
      title: map['title'] as String,
      lastPositionMs: map['last_position_ms'] as int? ?? 0,
      durationMs: map['duration_ms'] as int? ?? 0,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      lastPlayedAt: map['last_played_at'] as int? ?? 0,
    );
  }
}

/// Robust Singleton Service for managing Video Playback Persistence via SQLite
class PlaybackDatabaseService {
  PlaybackDatabaseService._();
  static final PlaybackDatabaseService instance = PlaybackDatabaseService._();

  static Database? _database;
  static const String _dbName = 'nitpliks_media.db';
  static const int _dbVersion = 1;
  static const String tableName = 'watch_history';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_path TEXT NOT NULL UNIQUE,
            video_id TEXT,
            title TEXT NOT NULL,
            last_position_ms INTEGER NOT NULL DEFAULT 0,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            is_completed INTEGER NOT NULL DEFAULT 0,
            last_played_at INTEGER NOT NULL
          )
        ''');

        // Indexes for lightning-fast lookups and sorting
        await db.execute(
          'CREATE UNIQUE INDEX idx_watch_history_path ON $tableName(video_path)',
        );
        await db.execute(
          'CREATE INDEX idx_watch_history_last_played ON $tableName(last_played_at DESC)',
        );
      },
    );
  }

  /// Get the saved playback position for a specific video
  /// Searches by path or ID to handle any device path formatting nuances
  /// Returns null if never played, finished, or position is negligible (< 3 seconds)
  Future<PlaybackHistoryRecord?> getPlaybackRecord({
    required String videoPath,
    String? videoId,
  }) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results;
      
      if (videoId != null && videoId.isNotEmpty) {
        results = await db.query(
          tableName,
          where: 'video_path = ? OR video_id = ?',
          whereArgs: [videoPath, videoId],
          limit: 1,
        );
      } else {
        results = await db.query(
          tableName,
          where: 'video_path = ?',
          whereArgs: [videoPath],
          limit: 1,
        );
      }

      if (results.isNotEmpty) {
        return PlaybackHistoryRecord.fromMap(results.first);
      }
    } catch (e) {
      debugPrint('🚨 [DB ERROR] getPlaybackRecord failed: $e');
    }
    return null;
  }

  /// Save or update playback state on-demand when a video is played
  Future<void> savePlaybackState({
    required VideoModel video,
    required int positionMs,
    required int durationMs,
    bool reset = false,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Rule: If video completed (>= 95% of duration) or explicitly reset
      final bool isNearEnd = durationMs > 0 && positionMs >= (durationMs * 0.95);
      final bool isCompleted = reset || isNearEnd;
      final int savedPos = isCompleted ? 0 : positionMs;

      // Upsert: update exact position and timestamps
      await db.rawInsert('''
        INSERT INTO $tableName (
          video_path,
          video_id,
          title,
          last_position_ms,
          duration_ms,
          is_completed,
          last_played_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(video_path) DO UPDATE SET
          video_id = excluded.video_id,
          title = excluded.title,
          last_position_ms = excluded.last_position_ms,
          duration_ms = CASE WHEN excluded.duration_ms > 0 THEN excluded.duration_ms ELSE $tableName.duration_ms END,
          is_completed = excluded.is_completed,
          last_played_at = excluded.last_played_at
      ''', [
        video.path,
        video.id,
        video.title,
        savedPos,
        durationMs,
        isCompleted ? 1 : 0,
        now,
      ]);

      debugPrint('🎬 [SQLITE SAVED] "${video.title}" pos: $savedPos ms, dur: $durationMs ms, completed: $isCompleted');
    } catch (e) {
      debugPrint('🚨 [DB ERROR] savePlaybackState failed: $e');
    }
  }

  /// Reset or mark video as completed (start from zero next time)
  Future<void> clearPlaybackPosition(String videoPath) async {
    try {
      final db = await database;
      await db.update(
        tableName,
        {
          'last_position_ms': 0,
          'is_completed': 1,
          'last_played_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'video_path = ?',
        whereArgs: [videoPath],
      );
      debugPrint('🎬 [SQLITE CLEARED] Position reset for: $videoPath');
    } catch (e) {
      debugPrint('🚨 [DB ERROR] clearPlaybackPosition failed: $e');
    }
  }

  /// Retrieve top recently played videos across all folders for the Home Screen
  /// Returns records ordered by latest played timestamp
  Future<List<PlaybackHistoryRecord>> getRecentlyPlayed({int limit = 7}) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        orderBy: 'last_played_at DESC',
        limit: limit,
      );

      return results.map((m) => PlaybackHistoryRecord.fromMap(m)).toList();
    } catch (e) {
      debugPrint('🚨 [DB ERROR] getRecentlyPlayed failed: $e');
      return [];
    }
  }

  /// Retrieve top recently played videos scoped specifically to a list of folder video paths
  /// Strictly limited (default 5 items) and sorted by latest played timestamp
  Future<List<PlaybackHistoryRecord>> getFolderRecentlyPlayed({
    required List<String> folderVideoPaths,
    int limit = 5,
  }) async {
    if (folderVideoPaths.isEmpty) return [];
    try {
      final db = await database;
      // SQLite IN clause placeholders (?, ?, ...)
      final placeholders = List.filled(folderVideoPaths.length, '?').join(',');
      final results = await db.rawQuery('''
        SELECT * FROM $tableName
        WHERE video_path IN ($placeholders)
        ORDER BY last_played_at DESC
        LIMIT $limit
      ''', folderVideoPaths);

      return results.map((m) => PlaybackHistoryRecord.fromMap(m)).toList();
    } catch (e) {
      debugPrint('🚨 [DB ERROR] getFolderRecentlyPlayed failed: $e');
      return [];
    }
  }
}
