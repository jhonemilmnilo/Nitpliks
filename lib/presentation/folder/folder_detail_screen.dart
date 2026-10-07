import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';
import '../home/providers/media_provider.dart';
import '../home/widgets/video_list_item.dart';

class FolderDetailScreen extends ConsumerWidget {
  final DeviceFolderModel folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final videosAsync = ref.watch(folderVideosProvider(folder.id));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'}',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: videosAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: palette.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, size: 40, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  'Failed to load videos: $err',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.film,
                    size: 44,
                    color: palette.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No videos found in this folder.',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoListItem(
                video: video,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing "${video.title}"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
