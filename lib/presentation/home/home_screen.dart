import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/app/theme/app_theme.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'providers/media_provider.dart';
import 'widgets/folder_card.dart';
import 'widgets/video_list_item.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(deviceMediaProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search videos, folders...',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text(
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
            icon: Icon(
              _isSearching ? LucideIcons.x : LucideIcons.search,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.rotateCw, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              ref.invalidate(deviceMediaProvider);
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          return ref.refresh(deviceMediaProvider);
        },
        child: mediaAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.accent),
                SizedBox(height: 16),
                Text(
                  'Scanning your device for videos...',
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
                    'Failed to scan videos: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(deviceMediaProvider),
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
                        'NitPliks needs permission to access your device videos so you can browse and play your clips.',
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
                            ref.invalidate(deviceMediaProvider);
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

            final filteredFolders = result.folders.where((FolderModel f) {
              return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            final filteredLooseVideos = result.looseVideos.where((VideoModel v) {
              return v.title.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            if (filteredFolders.isEmpty && filteredLooseVideos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.film, size: 52, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No results found for "$_searchQuery"'
                          : 'No videos found on this device',
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

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ──────────────────────────────────────────────
                // SECTION: FOLDERS & ALBUMS (FIRST PRIORITY)
                // ──────────────────────────────────────────────
                if (filteredFolders.isNotEmpty) ...[
                  Row(
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
                      const Text(
                        'Folders First',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredFolders.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.1,
                    ),
                    itemBuilder: (context, index) {
                      final folder = filteredFolders[index];
                      return FolderCard(
                        folder: folder,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opening ${folder.name} (${folder.videoCount} videos)'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                ],

                // ──────────────────────────────────────────────
                // SECTION: ALL VIDEOS (STANDALONE)
                // ──────────────────────────────────────────────
                if (filteredLooseVideos.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Videos (${filteredLooseVideos.length})',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Device Storage',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredLooseVideos.length,
                    itemBuilder: (context, index) {
                      final video = filteredLooseVideos[index];
                      return VideoListItem(
                        video: video,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playing "${video.title}"')),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
