import 'package:video_player/domain/models/media_models.dart';

/// Sample data to test and visualize the UI before connecting device scanner
class MockMediaData {
  static final List<RecentPlayModel> recentPlays = [
    RecentPlayModel(
      video: VideoModel(
        id: '1',
        title: 'Interstellar.2014.IMAX.1080p.BluRay.x265.mp4',
        path: '/storage/emulated/0/Movies/Interstellar.mp4',
        duration: const Duration(hours: 2, minutes: 49),
        sizeInBytes: 2500000000,
        parentFolder: 'Movies',
        modifiedDate: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      lastPosition: const Duration(hours: 1, minutes: 42),
      lastWatchedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    RecentPlayModel(
      video: VideoModel(
        id: '2',
        title: 'Flutter Advanced Architecture Crash Course 2026.mkv',
        path: '/storage/emulated/0/Downloads/FlutterCourse.mkv',
        duration: const Duration(minutes: 54, seconds: 20),
        sizeInBytes: 680000000,
        parentFolder: 'Downloads',
        modifiedDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      lastPosition: const Duration(minutes: 28, seconds: 10),
      lastWatchedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RecentPlayModel(
      video: VideoModel(
        id: '3',
        title: 'Attack on Titan Final Season - Ep 24.mp4',
        path: '/storage/emulated/0/Anime/AOT_24.mp4',
        duration: const Duration(minutes: 24, seconds: 15),
        sizeInBytes: 420000000,
        parentFolder: 'Anime',
        modifiedDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      lastPosition: const Duration(minutes: 19, seconds: 00),
      lastWatchedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<FolderModel> folders = [
    FolderModel(
      name: 'Movies',
      path: '/storage/emulated/0/Movies',
      videos: List.generate(
        12,
        (i) => VideoModel(
          id: 'mov_$i',
          title: 'Cinematic Movie Clip ${i + 1}.mp4',
          path: '/storage/emulated/0/Movies/movie_$i.mp4',
          duration: const Duration(hours: 1, minutes: 30),
          sizeInBytes: 1500000000,
          parentFolder: 'Movies',
          modifiedDate: DateTime.now().subtract(Duration(days: i)),
        ),
      ),
    ),
    FolderModel(
      name: 'Camera (DCIM)',
      path: '/storage/emulated/0/DCIM/Camera',
      videos: List.generate(
        24,
        (i) => VideoModel(
          id: 'cam_$i',
          title: 'VID_2026100${i + 1}_RECORD.mp4',
          path: '/storage/emulated/0/DCIM/Camera/vid_$i.mp4',
          duration: const Duration(minutes: 3, seconds: 45),
          sizeInBytes: 120000000,
          parentFolder: 'Camera',
          modifiedDate: DateTime.now().subtract(Duration(hours: i * 4)),
        ),
      ),
    ),
    FolderModel(
      name: 'Downloads',
      path: '/storage/emulated/0/Downloads',
      videos: List.generate(
        8,
        (i) => VideoModel(
          id: 'dl_$i',
          title: 'Downloaded File ${i + 1}.mp4',
          path: '/storage/emulated/0/Downloads/dl_$i.mp4',
          duration: const Duration(minutes: 15, seconds: 20),
          sizeInBytes: 250000000,
          parentFolder: 'Downloads',
          modifiedDate: DateTime.now().subtract(Duration(days: i + 2)),
        ),
      ),
    ),
    FolderModel(
      name: 'Screen Recordings',
      path: '/storage/emulated/0/Movies/Screenrecords',
      videos: List.generate(
        5,
        (i) => VideoModel(
          id: 'rec_$i',
          title: 'Screen_Capture_demo_${i + 1}.mp4',
          path: '/storage/emulated/0/Movies/Screenrecords/rec_$i.mp4',
          duration: const Duration(minutes: 2, seconds: 10),
          sizeInBytes: 45000000,
          parentFolder: 'Screen Recordings',
          modifiedDate: DateTime.now().subtract(Duration(days: i)),
        ),
      ),
    ),
  ];

  static final List<VideoModel> looseVideos = [
    VideoModel(
      id: 'loose_1',
      title: 'WhatsApp_Video_Sent_20261005.mp4',
      path: '/storage/emulated/0/WhatsApp_Video_Sent_20261005.mp4',
      duration: const Duration(minutes: 1, seconds: 45),
      sizeInBytes: 18000000,
      parentFolder: 'Root',
      modifiedDate: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    VideoModel(
      id: 'loose_2',
      title: 'Quick_Voice_Note_Visualizer.mp4',
      path: '/storage/emulated/0/Quick_Voice_Note_Visualizer.mp4',
      duration: const Duration(minutes: 0, seconds: 58),
      sizeInBytes: 8500000,
      parentFolder: 'Root',
      modifiedDate: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    VideoModel(
      id: 'loose_3',
      title: 'Shared_Demo_Build_Recording.mp4',
      path: '/storage/emulated/0/Shared_Demo_Build_Recording.mp4',
      duration: const Duration(minutes: 5, seconds: 12),
      sizeInBytes: 74000000,
      parentFolder: 'Root',
      modifiedDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    VideoModel(
      id: 'loose_4',
      title: 'Exported_Drone_Shot_4K.mov',
      path: '/storage/emulated/0/Exported_Drone_Shot_4K.mov',
      duration: const Duration(minutes: 4, seconds: 30),
      sizeInBytes: 450000000,
      parentFolder: 'Root',
      modifiedDate: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
}
