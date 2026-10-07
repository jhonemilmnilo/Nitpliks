import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';
import '../home/providers/media_provider.dart';
import '../home/widgets/video_list_item.dart';
import '../player/player_screen.dart';
import 'providers/video_sort_provider.dart';
import 'widgets/video_sort_bottom_sheet.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final DeviceFolderModel folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isModalOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSortModal() async {
    setState(() {
      _isModalOpen = true;
    });

    await VideoSortBottomSheet.show(context);

    if (mounted) {
      setState(() {
        _isModalOpen = false;
      });
    }
  }

  List<VideoModel> _applyFilterAndSort(List<VideoModel> videos, VideoSortOption sortOption) {
    // 1. Filter by search query
    var result = videos;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((v) => v.title.toLowerCase().contains(query)).toList();
    } else {
      result = List.from(result);
    }

    // 2. Sort
    switch (sortOption) {
      case VideoSortOption.dateDesc:
        result.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
        break;
      case VideoSortOption.dateAsc:
        result.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case VideoSortOption.sizeDesc:
        result.sort((a, b) => b.sizeInBytes.compareTo(a.sizeInBytes));
        break;
      case VideoSortOption.sizeAsc:
        result.sort((a, b) => a.sizeInBytes.compareTo(b.sizeInBytes));
        break;
      case VideoSortOption.durationDesc:
        result.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case VideoSortOption.durationAsc:
        result.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case VideoSortOption.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case VideoSortOption.titleDesc:
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final videosAsync = ref.watch(folderVideosProvider(widget.folder.id));
    final sortOption = ref.watch(videoSortProvider);

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
              widget.folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.folder.videoCount} ${widget.folder.videoCount == 1 ? 'video' : 'videos'}',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.rotateCw, color: palette.textMuted, size: 19),
            tooltip: 'Refresh videos',
            onPressed: () {
              ref.invalidate(folderVideosProvider(widget.folder.id));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          videosAsync.when(
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
            data: (allVideos) {
              if (allVideos.isEmpty) {
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

              final filteredVideos = _applyFilterAndSort(allVideos, sortOption);

              if (filteredVideos.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.searchX,
                        size: 44,
                        color: palette.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No videos match "$_searchQuery"',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try searching for another keyword',
                        style: TextStyle(color: palette.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: palette.primary,
                backgroundColor: palette.surface,
                onRefresh: () async {
                  return ref.read(folderVideosProvider(widget.folder.id).notifier).refresh();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Header with Count indicator & Active Sort Chip
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Videos (${filteredVideos.length})',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: _openSortModal,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: palette.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.arrowUpDown,
                                      size: 13,
                                      color: palette.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sortOption.label,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Video list items
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final video = filteredVideos[index];
                            return VideoListItem(
                              video: video,
                              folderId: widget.folder.id,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      videos: filteredVideos,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: filteredVideos.length,
                        ),
                      ),
                    ),

                    // Bottom padding spacer so dock never blocks the last items
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 90),
                    ),
                  ],
                ),
              );
            },
          ),

          // ──────────────────────────────────────────────
          // FLOATING BOTTOM SEARCHBAR & SORT ACTION
          // Inverted contrast styling matching HomeScreen
          // ──────────────────────────────────────────────
          Builder(
            builder: (context) {
              final dockBg = palette.isDark
                  ? const Color(0xFF1E222D)
                  : const Color(0xFF0F172A);
              final dockBorder = palette.isDark
                  ? const Color(0xFF2E3547)
                  : const Color(0xFF1E293B);
              final dockText = palette.isDark
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9);
              final dockMuted = palette.isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF94A3B8);

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: 16,
                right: 16,
                bottom: _isModalOpen ? -80 : 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isModalOpen ? 0.0 : 1.0,
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Floating Search Input Bar
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: dockBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: dockBorder),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: dockText, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search videos in ${widget.folder.name}...',
                                hintStyle: TextStyle(color: dockMuted, fontSize: 13),
                                border: InputBorder.none,
                                prefixIcon: Icon(
                                  LucideIcons.search,
                                  size: 18,
                                  color: dockMuted,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          LucideIcons.x,
                                          size: 16,
                                          color: dockMuted,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Floating Sort Button
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: dockBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: dockBorder),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _openSortModal,
                              child: Center(
                                child: Icon(
                                  LucideIcons.arrowUpDown,
                                  color: dockText,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
