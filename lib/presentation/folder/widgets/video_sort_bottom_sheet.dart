import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import '../providers/video_sort_provider.dart';

class VideoSortBottomSheet extends ConsumerWidget {
  const VideoSortBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VideoSortBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(videoSortProvider);
    final palette = ref.watch(paletteProvider);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Sort Videos By',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),

              // Sort Options List
              ...VideoSortOption.values.map((option) {
                final isSelected = currentSort == option;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      ref.read(videoSortProvider.notifier).setSortOption(option);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            _getOptionIcon(option),
                            size: 18,
                            color: isSelected ? palette.primary : palette.textMuted,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                color: isSelected ? palette.primary : palette.textPrimary,
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              LucideIcons.check,
                              size: 18,
                              color: palette.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getOptionIcon(VideoSortOption option) {
    switch (option) {
      case VideoSortOption.dateDesc:
      case VideoSortOption.dateAsc:
        return LucideIcons.calendar;
      case VideoSortOption.sizeDesc:
      case VideoSortOption.sizeAsc:
        return LucideIcons.hardDrive;
      case VideoSortOption.durationDesc:
      case VideoSortOption.durationAsc:
        return LucideIcons.clock;
      case VideoSortOption.titleAsc:
      case VideoSortOption.titleDesc:
        return LucideIcons.arrowDownAZ;
    }
  }
}
