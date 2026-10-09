import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Representation of an online subtitle search result
class OnlineSubtitleItem {
  final String fileId;
  final String fileName;
  final String language;
  final String languageName;
  final int downloadCount;
  final double rating;
  final String format;
  final String? release;

  const OnlineSubtitleItem({
    required this.fileId,
    required this.fileName,
    required this.language,
    required this.languageName,
    required this.downloadCount,
    required this.rating,
    required this.format,
    this.release,
  });

  factory OnlineSubtitleItem.fromOpenSubtitlesJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final files = attributes['files'] as List<dynamic>? ?? [];
    final firstFile = files.isNotEmpty ? files.first as Map<String, dynamic> : <String, dynamic>{};

    final fileId = firstFile['file_id']?.toString() ?? json['id']?.toString() ?? '';
    final fileName = firstFile['file_name']?.toString() ?? attributes['release']?.toString() ?? 'Subtitle';
    final language = attributes['language']?.toString() ?? 'en';
    final downloadCount = attributes['download_count'] is int ? attributes['download_count'] as int : 0;
    final rating = attributes['ratings'] is num ? (attributes['ratings'] as num).toDouble() : 0.0;
    final format = attributes['format']?.toString() ?? 'srt';
    final release = attributes['release']?.toString();

    return OnlineSubtitleItem(
      fileId: fileId,
      fileName: fileName,
      language: language,
      languageName: _mapLanguageName(language),
      downloadCount: downloadCount,
      rating: rating,
      format: format,
      release: release,
    );
  }

  static String _mapLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'tl':
      case 'fil':
        return 'Tagalog';
      case 'es':
        return 'Spanish';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'zh-cn':
      case 'zh':
        return 'Chinese';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'id':
        return 'Indonesian';
      case 'vi':
        return 'Vietnamese';
      case 'ar':
        return 'Arabic';
      case 'pt':
        return 'Portuguese';
      case 'ru':
        return 'Russian';
      default:
        return code.toUpperCase();
    }
  }
}

/// Service handling OpenSubtitles REST API search and file download
class OnlineSubtitleService {
  OnlineSubtitleService._();
  static final OnlineSubtitleService instance = OnlineSubtitleService._();

  static const String _apiBase = 'https://api.opensubtitles.com/api/v1';

  // Registered consumer API Key for NitPliks
  static const String _apiKey = 'd1vOK0y96phIuj2BMwlJ0pepLGoDkyPs';

  // Header factory to inject proper User-Agent and Api-Key
  static const Map<String, String> _headers = {
    'User-Agent': 'NitPliks v1.0.0',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Api-Key': _apiKey,
  };

  /// Clean filename query to strip technical tags and get a pure movie/show title
  static String cleanSearchQuery(String rawTitle) {
    // Strip file extension
    String clean = rawTitle.replaceAll(RegExp(r'\.(mp4|mkv|avi|mov|wmv|flv|webm)$', caseSensitive: false), '');
    // Replace dots, underscores, dashes with spaces
    clean = clean.replaceAll(RegExp(r'[\._\-]'), ' ');
    // Strip common release tags and resolutions
    clean = clean.replaceAll(
      RegExp(
        r'\b(1080p|720p|480p|2160p|4k|uhd|bluray|blu-ray|bdrip|brrip|web-dl|webrip|web|hdtv|x264|x265|hevc|aac|dts|remux|yify|yts|rarbg|eztv)\b',
        caseSensitive: false,
      ),
      '',
    );
    // Remove brackets and excess whitespace
    clean = clean.replaceAll(RegExp(r'[\[\]\(\)]'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Search subtitles by query and optional language code.
  /// Throws or returns empty with specific error logging.
  Future<({List<OnlineSubtitleItem> items, String? errorMessage})> searchSubtitles({
    required String query,
    String? languageCode,
  }) async {
    try {
      final cleanQuery = cleanSearchQuery(query);
      if (cleanQuery.isEmpty) return (items: <OnlineSubtitleItem>[], errorMessage: null);

      final queryParams = <String, String>{
        'query': cleanQuery,
      };

      if (languageCode != null && languageCode.isNotEmpty && languageCode != 'all') {
        queryParams['languages'] = languageCode;
      }

      final uri = Uri.parse('$_apiBase/subtitles').replace(queryParameters: queryParams);
      debugPrint('🌐 [SUBTITLE API] Searching: $uri');

      var response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));

      // Handle redirect if OpenSubtitles responds with 301/302 canonical path
      if ((response.statusCode == 301 || response.statusCode == 302) && response.headers['location'] != null) {
        final redirectUrl = response.headers['location']!;
        final resolvedUri = redirectUrl.startsWith('http') ? Uri.parse(redirectUrl) : Uri.parse('$_apiBase$redirectUrl');
        debugPrint('🔀 [SUBTITLE API REDIRECT] Following to: $resolvedUri');
        response = await http.get(resolvedUri, headers: _headers).timeout(const Duration(seconds: 12));
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>? ?? [];

        final results = <OnlineSubtitleItem>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            results.add(OnlineSubtitleItem.fromOpenSubtitlesJson(item));
          }
        }
        return (items: results, errorMessage: null);
      } else if (response.statusCode == 403) {
        debugPrint('⚠️ [SUBTITLE API 403]: ${response.body}');
        return (
          items: <OnlineSubtitleItem>[],
          errorMessage: 'Access denied or quota limit reached. Please try again later.'
        );
      } else {
        debugPrint('⚠️ [SUBTITLE API ERROR] Status ${response.statusCode}: ${response.body}');
        return (
          items: <OnlineSubtitleItem>[],
          errorMessage: 'Server returned error ${response.statusCode}. Please try again later.'
        );
      }
    } catch (e) {
      debugPrint('🚨 [SUBTITLE API EXCEPTION] $e');
      return (items: <OnlineSubtitleItem>[], errorMessage: 'Network error: Please check your internet connection.');
    }
  }

  /// Download subtitle by file ID and save to local disk
  Future<File?> downloadSubtitle({
    required OnlineSubtitleItem item,
    required String videoTitle,
  }) async {
    try {
      final uri = Uri.parse('$_apiBase/download');
      debugPrint('📥 [SUBTITLE DOWNLOAD] Requesting fileId: ${item.fileId}');

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({'file_id': int.tryParse(item.fileId) ?? item.fileId}),
      ).timeout(const Duration(seconds: 15));

      String? downloadLink;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        downloadLink = decoded['link']?.toString();
      }

      if (downloadLink == null) {
        debugPrint('⚠️ [SUBTITLE DOWNLOAD] No link in response. Status: ${response.statusCode}');
        return null;
      }

      // 2. Fetch actual subtitle binary / file stream
      final fileResponse = await http.get(Uri.parse(downloadLink)).timeout(const Duration(seconds: 20));
      if (fileResponse.statusCode != 200) {
        return null;
      }

      final bytes = fileResponse.bodyBytes;

      // 3. Prepare local subtitles directory
      final appDir = await getApplicationDocumentsDirectory();
      final subDir = Directory('${appDir.path}/subtitles');
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
      }

      // Safe clean filename
      final safeName = '${cleanSearchQuery(videoTitle)}_${item.language}_${DateTime.now().millisecondsSinceEpoch}';

      // 4. Handle zipped content or direct srt/vtt bytes
      if (downloadLink.endsWith('.zip') || _isZip(bytes)) {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('.srt') || file.name.endsWith('.vtt') || file.name.endsWith('.ass'))) {
            final ext = file.name.split('.').last;
            final targetFile = File('${subDir.path}/$safeName.$ext');
            await targetFile.writeAsBytes(file.content as List<int>);
            debugPrint('✅ [SUBTITLE SAVED UNZIPPED] ${targetFile.path}');
            return targetFile;
          }
        }
      }

      // Direct write (.srt or .vtt)
      final ext = item.format.isNotEmpty ? item.format : 'srt';
      final targetFile = File('${subDir.path}/$safeName.$ext');
      await targetFile.writeAsBytes(bytes);
      debugPrint('✅ [SUBTITLE SAVED DIRECT] ${targetFile.path}');
      return targetFile;
    } catch (e, stack) {
      debugPrint('🚨 [SUBTITLE DOWNLOAD ERROR] $e\n$stack');
      return null;
    }
  }

  static bool _isZip(List<int> bytes) {
    if (bytes.length < 4) return false;
    // PK zip signature
    return bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
  }
}
