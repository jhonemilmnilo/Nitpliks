import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme/palette_provider.dart';
import '../../../data/services/online_subtitle_service.dart';

/// Modal dialog for searching and downloading online subtitles
class OnlineSubtitleModal extends ConsumerStatefulWidget {
  final String videoTitle;
  final ValueChanged<File> onSubtitleDownloaded;

  const OnlineSubtitleModal({
    super.key,
    required this.videoTitle,
    required this.onSubtitleDownloaded,
  });

  static Future<void> show(
    BuildContext context, {
    required String videoTitle,
    required ValueChanged<File> onSubtitleDownloaded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OnlineSubtitleModal(
        videoTitle: videoTitle,
        onSubtitleDownloaded: onSubtitleDownloaded,
      ),
    );
  }

  @override
  ConsumerState<OnlineSubtitleModal> createState() => _OnlineSubtitleModalState();
}

class _OnlineSubtitleModalState extends ConsumerState<OnlineSubtitleModal> {
  late final TextEditingController _searchController;
  String _selectedLanguageCode = 'en';
  bool _isLoading = false;
  String? _downloadingId;
  List<OnlineSubtitleItem> _results = [];
  bool _hasSearched = false;
  String? _errorMessage;

  final List<Map<String, String>> _languages = const [
    {'code': 'en', 'label': 'English'},
    {'code': 'tl', 'label': 'Tagalog'},
    {'code': 'all', 'label': 'All Languages'},
    {'code': 'es', 'label': 'Spanish'},
    {'code': 'ja', 'label': 'Japanese'},
    {'code': 'ko', 'label': 'Korean'},
    {'code': 'zh-cn', 'label': 'Chinese'},
    {'code': 'fr', 'label': 'French'},
    {'code': 'id', 'label': 'Indonesian'},
    {'code': 'vi', 'label': 'Vietnamese'},
  ];

  @override
  void initState() {
    super.initState();
    final cleanInitialQuery = OnlineSubtitleService.cleanSearchQuery(widget.videoTitle);
    _searchController = TextEditingController(text: cleanInitialQuery);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    final result = await OnlineSubtitleService.instance.searchSubtitles(
      query: query,
      languageCode: _selectedLanguageCode,
    );

    if (mounted) {
      setState(() {
        _results = result.items;
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadSubtitle(OnlineSubtitleItem item) async {
    setState(() {
      _downloadingId = item.fileId;
    });

    final file = await OnlineSubtitleService.instance.downloadSubtitle(
      item: item,
      videoTitle: widget.videoTitle,
    );

    if (!mounted) return;

    setState(() {
      _downloadingId = null;
    });

    if (file != null) {
      widget.onSubtitleDownloaded(file);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtitle applied: ${item.fileName}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download subtitle. Please try another track.'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.border, width: 1)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.downloadCloud, color: palette.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Download Subtitles Online',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, color: palette.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(LucideIcons.search, color: palette.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: palette.textPrimary, fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        hintText: 'Search movie or show title...',
                        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(LucideIcons.x, color: palette.textMuted, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      splashRadius: 16,
                    ),
                  IconButton(
                    icon: Icon(LucideIcons.arrowRight, color: palette.primary, size: 18),
                    onPressed: _performSearch,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Language Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _languages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = _selectedLanguageCode == lang['code'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLanguageCode = lang['code']!;
                    });
                    _performSearch();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? palette.primary : palette.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? palette.primary : palette.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        lang['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : palette.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          Divider(color: palette.border.withValues(alpha: 0.5), height: 1),

          // Results List / States
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Searching OpenSubtitles...',
                          style: TextStyle(color: palette.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.alertCircle,
                                size: 36,
                                color: palette.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _performSearch,
                                icon: const Icon(LucideIcons.rotateCw, size: 14),
                                label: const Text('Try Again', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.fileQuestion,
                                  size: 40,
                                  color: palette.textMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _hasSearched ? 'No subtitles found for this query' : 'Enter a query to search',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try simplifying the title or switching language filter',
                                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => Divider(
                          color: palette.border.withValues(alpha: 0.3),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isDownloadingThis = _downloadingId == item.fileId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fileName,
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: palette.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.languageName,
                                              style: TextStyle(
                                                color: palette.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '.${item.format.toUpperCase()}',
                                            style: TextStyle(
                                              color: palette.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (item.downloadCount > 0) ...[
                                            const SizedBox(width: 8),
                                            Icon(LucideIcons.download, size: 11, color: palette.textMuted),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${item.downloadCount}',
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: isDownloadingThis ? null : () => _downloadSubtitle(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: const Size(40, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isDownloadingThis
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(LucideIcons.download, size: 14),
                                            SizedBox(width: 4),
                                            Text('Get', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
