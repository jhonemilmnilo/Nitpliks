import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';

/// Provider for fast folder scanning on home screen
final deviceFoldersProvider = FutureProvider<DeviceMediaResult>((ref) async {
  return await DeviceMediaService.fetchFolders();
});

/// Family provider for loading videos on-demand for a clicked folder
final folderVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, folderId) async {
  return await DeviceMediaService.fetchVideosInFolder(folderId);
});

/// State provider to track folder ID currently undergoing rename/update for skeleton animation
final updatingFolderIdProvider = StateProvider<String?>((ref) => null);

/// State provider to track video ID currently undergoing rename/update for skeleton animation
final updatingVideoIdProvider = StateProvider<String?>((ref) => null);
