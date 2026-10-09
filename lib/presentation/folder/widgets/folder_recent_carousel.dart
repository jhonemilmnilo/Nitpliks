import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../app/theme/palette_provider.dart';
import '../../../data/services/playback_database_service.dart';
import '../../../data/services/video_thumbnail_service.dart';
import '../../../domain/models/media_models.dart';

/// Item pairing a VideoModel with its playback history record
class FolderRecentItem {
  final VideoModel video;
  final PlaybackHistoryRecord record;

  const FolderRecentItem({
    required this.video,
    required this.record,
  });
}

/// Custom high-momentum, ultra-smooth scroll physics
/// Decreases drag friction and increases fling velocity for butter-smooth gliding
class _UltraSmoothCarouselPhysics extends ScrollPhysics {
  const _UltraSmoothCarouselPhysics({super.parent});

  @override
  _UltraSmoothCarouselPhysics applyTo(ScrollPhysics? ancestor) {
    return _UltraSmoothCarouselPhysics(parent: buildParent(ancestor));
  }

  // Significantly reduced drag friction coefficient (default is ~0.015, 0.006 gives premium glide)
  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double get minFlingVelocity => 50.0; // Responds to light finger flicks

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 70,
        stiffness: 100,
        damping: 1.1,
      );
}

/// Horizontal carousel displaying up to 5 recently played videos in the active folder
class FolderRecentCarousel extends ConsumerWidget {
  final List<FolderRecentItem> items;
  final ValueChanged<FolderRecentItem> onVideoTap;

  const FolderRecentCarousel({
    super.key,
    required this.items,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final palette = ref.watch(paletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Icon(
                LucideIcons.history,
                size: 15,
                color: palette.primary,
              ),
              const SizedBox(width: 7),
              Text(
                'Recently Played',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}/5',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Carousel List - Ultra-smooth gliding
        SizedBox(
          height: 142,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const _UltraSmoothCarouselPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _FolderRecentCard(
                item: item,
                palette: palette,
                onTap: () => onVideoTap(item),
              );
            },
          ),
        ),

        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: palette.border.withValues(alpha: 0.35),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FolderRecentCard extends StatefulWidget {
  final FolderRecentItem item;
  final dynamic palette;
  final VoidCallback onTap;

  const _FolderRecentCard({
    required this.item,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_FolderRecentCard> createState() => _FolderRecentCardState();
}

class _FolderRecentCardState extends State<_FolderRecentCard> {
  Future<String?>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant _FolderRecentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.video.path != widget.item.video.path) {
      _initThumbnail();
    }
  }

  void _initThumbnail() {
    if (VideoThumbnailService.getCachedThumbnailPath(widget.item.video.path) == null) {
      _thumbnailFuture = VideoThumbnailService.getThumbnailPath(
        videoPath: widget.item.video.path,
        duration: widget.item.video.duration,
      );
    }
  }

  String _formatMs(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final video = widget.item.video;
    final record = widget.item.record;
    final cachedPath = VideoThumbnailService.getCachedThumbnailPath(video.path);

    // Progress calculation
    final totalMs = record.durationMs > 0 ? record.durationMs : video.duration.inMilliseconds;
    final posMs = record.lastPositionMs;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progress * 100).toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 148,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail Stack
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      if (cachedPath != null)
                        Image.file(
                          File(cachedPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(palette, video),
                        )
                      else
                        FutureBuilder<String?>(
                          future: _thumbnailFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done &&
                                snapshot.data != null &&
                                snapshot.data!.isNotEmpty) {
                              return Image.file(
                                File(snapshot.data!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(palette, video),
                              );
                            }

                            if (snapshot.connectionState == ConnectionState.done && snapshot.data == null) {
                              return _buildPlaceholder(palette, video);
                            }

                            return _buildPlaceholder(palette, video);
                          },
                        ),

                      // Subtle Dark Gradient Overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Duration Badge
                      Positioned(
                        bottom: 6,
                        right: 6,
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
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Progress Bar at the bottom
                      if (progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 3,
                            color: Colors.black45,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Title (2 lines max)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              // Resume Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.play,
                      size: 10,
                      color: palette.primary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        record.isCompleted ? 'Finished' : '${_formatMs(posMs)} ($progressPercent%)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(dynamic palette, VideoModel video) {
    if (video.asset != null) {
      return FutureBuilder<dynamic>(
        future: video.asset!.thumbnailDataWithSize(
          const ThumbnailSize(240, 150),
          quality: 80,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _defaultPlaceholder(palette),
            );
          }
          return _defaultPlaceholder(palette);
        },
      );
    }
    return _defaultPlaceholder(palette);
  }

  Widget _defaultPlaceholder(dynamic palette) {
    return Container(
      color: palette.surfaceLight,
      child: Center(
        child: Icon(
          LucideIcons.film,
          size: 20,
          color: palette.textMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
