import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import 'package:video_player/data/services/video_thumbnail_service.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'package:video_player/presentation/folder/widgets/video_action_bottom_sheet.dart';
import 'package:video_player/presentation/home/providers/media_provider.dart';

class VideoListItem extends ConsumerWidget {
  final VideoModel video;
  final String folderId;
  final VoidCallback onTap;

  const VideoListItem({
    super.key,
    required this.video,
    required this.folderId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final updatingVideoId = ref.watch(updatingVideoIdProvider);
    final isUpdating = updatingVideoId == video.id;

    if (isUpdating) {
      return _VideoListItemSkeleton(palette: palette);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Real Video Thumbnail with Duration badge
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 90,
                  height: 56,
                  color: palette.border.withValues(alpha: 0.3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // High quality 1-minute frame thumbnail
                      FutureBuilder<String?>(
                        future: VideoThumbnailService.getThumbnailPath(
                          videoPath: video.path,
                          duration: video.duration,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done &&
                              snapshot.data != null &&
                              snapshot.data!.isNotEmpty) {
                            return Image.file(
                              File(snapshot.data!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildAssetOrFallback(palette),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
                            return _buildAssetOrFallback(palette);
                          }

                          // Subtle pulsing placeholder while loading 1-minute frame
                          return Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        },
                      ),

                      // Duration Badge (bottom right)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          video.formattedSize,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: palette.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(video.modifiedDate),
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3-dots Contextual Action Menu Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final action = await VideoActionBottomSheet.show(context, video, folderId);
                    if (!context.mounted || action == null) return;

                    switch (action) {
                      case VideoMenuAction.rename:
                        VideoActionBottomSheet.showRenameDialog(context, ref, video, folderId);
                        break;
                      case VideoMenuAction.delete:
                        VideoActionBottomSheet.showDeleteDialog(context, ref, video, folderId);
                        break;
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.moreVertical,
                      color: palette.textMuted,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetOrFallback(dynamic palette) {
    if (video.asset != null) {
      return FutureBuilder(
        future: video.asset!.thumbnailDataWithSize(
          const ThumbnailSize(240, 150),
          quality: 80,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(palette),
            );
          }
          return _buildFallbackThumbnail(palette);
        },
      );
    }
    return _buildFallbackThumbnail(palette);
  }

  Widget _buildFallbackThumbnail(dynamic palette) {
    return Center(
      child: Icon(
        LucideIcons.video,
        color: palette.textMuted.withValues(alpha: 0.6),
        size: 22,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inDays == 0) {
      final hours = dt.hour.toString().padLeft(2, '0');
      final minutes = dt.minute.toString().padLeft(2, '0');
      return 'Today $hours:$minutes';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
}

class _VideoListItemSkeleton extends StatefulWidget {
  final dynamic palette;

  const _VideoListItemSkeleton({required this.palette});

  @override
  State<_VideoListItemSkeleton> createState() => _VideoListItemSkeletonState();
}

class _VideoListItemSkeletonState extends State<_VideoListItemSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        final shimmerColor = palette.border.withValues(alpha: _opacityAnim.value);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Skeleton Thumbnail Box
              Container(
                width: 90,
                height: 56,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),

              // Skeleton Title & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 90,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shimmerColor.withValues(alpha: _opacityAnim.value * 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),

              // 3-dots placeholder
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: shimmerColor.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

