import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../app/theme/app_theme.dart';
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
    final videosAsync = ref.watch(folderVideosProvider(folder.id));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: videosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Failed to load videos: $err',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'No videos found in this folder.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoListItem(
                video: video,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing "${video.title}"')),
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
