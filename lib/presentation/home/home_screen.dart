import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/app/theme/app_theme.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'package:video_player/presentation/folder/folder_detail_screen.dart';
import 'providers/folder_sort_provider.dart';
import 'providers/media_provider.dart';
import 'widgets/folder_card.dart';
import 'widgets/folder_sort_bottom_sheet.dart';
import 'widgets/settings_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    await FolderSortBottomSheet.show(context);

    if (mounted) {
      setState(() {
        _isModalOpen = false;
      });
    }
  }

  Future<void> _openSettingsModal() async {
    setState(() {
      _isModalOpen = true;
    });

    await SettingsBottomSheet.show(context);

    if (mounted) {
      setState(() {
        _isModalOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(deviceFoldersProvider);
    final sortOption = ref.watch(folderSortProvider);
    final palette = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text(
          'NitPliks',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Rescan Folders',
            onPressed: () {
              ref.invalidate(deviceFoldersProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: palette.primary,
            backgroundColor: palette.surface,
            onRefresh: () async {
              return ref.refresh(deviceFoldersProvider);
            },
            child: foldersAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 16),
                    Text(
                      'Scanning video folders...',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to scan folders: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(deviceFoldersProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (result) {
                if (!result.hasPermission) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.shieldAlert, size: 56, color: AppTheme.accent),
                          const SizedBox(height: 16),
                          const Text(
                            'Storage Permission Required',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'NitPliks needs permission to browse video folders on your device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(LucideIcons.unlock, size: 16),
                            label: const Text('Grant Permission'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final granted = await DeviceMediaService.requestPermission();
                              if (granted) {
                                ref.invalidate(deviceFoldersProvider);
                              } else {
                                await PhotoManager.openSetting();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final filteredFolders = result.folders.where((DeviceFolderModel f) {
                  return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                // Apply selected sorting criteria
                switch (sortOption) {
                  case FolderSortOption.videoCountDesc:
                    filteredFolders.sort((a, b) => b.videoCount.compareTo(a.videoCount));
                    break;
                  case FolderSortOption.videoCountAsc:
                    filteredFolders.sort((a, b) => a.videoCount.compareTo(b.videoCount));
                    break;
                  case FolderSortOption.dateDesc:
                    filteredFolders.sort((a, b) {
                      final dateA = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final dateB = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return dateB.compareTo(dateA);
                    });
                    break;
                  case FolderSortOption.dateAsc:
                    filteredFolders.sort((a, b) {
                      final dateA = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final dateB = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return dateA.compareTo(dateB);
                    });
                    break;
                  case FolderSortOption.nameAsc:
                    filteredFolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    break;
                  case FolderSortOption.nameDesc:
                    filteredFolders.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
                    break;
                }

                if (filteredFolders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.folderX, size: 52, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No folders found for "$_searchQuery"'
                              : 'No video folders found on this device',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Download or record some videos to get started!',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // Virtualized CustomScrollView with pure Slivers for 120Hz smooth scrolling
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Header Count indicator with interactive Sort Button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Folders (${filteredFolders.length})',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: _openSortModal,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
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

                    // Virtualized folder list (one item per line)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final folder = filteredFolders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FolderCard(
                                folder: folder,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FolderDetailScreen(folder: folder),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: filteredFolders.length,
                        ),
                      ),
                    ),

                    // Extra space at bottom so floating search bar doesn't obscure content
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 90),
                    ),
                  ],
                );
              },
            ),
          ),

          // ──────────────────────────────────────────────
          // FLOATING BOTTOM SEARCHBAR & SETTINGS ACTION
          // Automatically hides with animation when sort modal is open
          // ──────────────────────────────────────────────
          AnimatedPositioned(
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
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search folders...',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: AppTheme.textMuted,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      LucideIcons.x,
                                      size: 16,
                                      color: AppTheme.textMuted,
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

                    // Floating Settings Button
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _openSettingsModal,
                          child: const Center(
                            child: Icon(
                              LucideIcons.settings,
                              color: AppTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
