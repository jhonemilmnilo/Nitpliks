import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/media_models.dart';

class DeviceMediaResult {
  final List<FolderModel> folders;
  final List<VideoModel> looseVideos;
  final bool hasPermission;

  const DeviceMediaResult({
    required this.folders,
    required this.looseVideos,
    required this.hasPermission,
  });
}

class DeviceMediaService {
  /// Request storage/media permissions using PhotoManager
  static Future<bool> requestPermission() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  /// Check current permission state
  static Future<bool> hasPermission() async {
    final PermissionState state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.video,
          mediaLocation: false,
        ),
      ),
    );
    return state.isAuth || state.hasAccess;
  }

  /// Scan device and fetch all video folders and loose videos
  static Future<DeviceMediaResult> fetchDeviceMedia() async {
    final permitted = await requestPermission();
    if (!permitted) {
      return const DeviceMediaResult(
        folders: [],
        looseVideos: [],
        hasPermission: false,
      );
    }

    try {
      // Fetch only Video type asset paths (albums/folders)
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );

      final List<FolderModel> folderList = [];
      final List<VideoModel> allVideos = [];

      for (final album in albums) {
        // Skip the virtual "Recent" or "All" album from photo_manager to avoid duplicates in folder view
        if (album.isAll) {
          continue;
        }

        final int assetCount = await album.assetCountAsync;
        if (assetCount == 0) continue;

        // Fetch videos in this folder (up to 500 per album)
        final List<AssetEntity> assets = await album.getAssetListRange(
          start: 0,
          end: assetCount,
        );

        final List<VideoModel> folderVideos = [];

        for (final asset in assets) {
          final file = await asset.file;
          final path = file?.path ?? '';

          final video = VideoModel(
            id: asset.id,
            title: asset.title ?? 'Untitled Video',
            path: path,
            duration: Duration(seconds: asset.duration),
            sizeInBytes: file != null ? await file.length() : 0,
            parentFolder: album.name,
            modifiedDate: asset.createDateTime,
          );

          folderVideos.add(video);
          allVideos.add(video);
        }

        if (folderVideos.isNotEmpty) {
          folderList.add(
            FolderModel(
              name: album.name,
              path: album.id,
              videos: folderVideos,
            ),
          );
        }
      }

      // Sort folders by video count (most populated first)
      folderList.sort((a, b) => b.videoCount.compareTo(a.videoCount));

      // Loose/All videos sorted by latest date
      allVideos.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));

      return DeviceMediaResult(
        folders: folderList,
        looseVideos: allVideos,
        hasPermission: true,
      );
    } catch (e, stack) {
      debugPrint('Error fetching device media: $e\n$stack');
      return const DeviceMediaResult(
        folders: [],
        looseVideos: [],
        hasPermission: true,
      );
    }
  }
}
