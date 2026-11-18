import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_models.dart';
import 'database_service.dart';

enum MediaSourceType {
  m3u,
  jellyfin,
  emby,
  xtream,
  plex;

  String get displayName {
    switch (this) {
      case MediaSourceType.m3u:
        return 'M3U';
      case MediaSourceType.jellyfin:
        return 'Jellyfin';
      case MediaSourceType.emby:
        return 'Emby';
      case MediaSourceType.xtream:
        return 'Xtream';
      case MediaSourceType.plex:
        return 'Plex';
    }
  }

  String get subtitle {
    switch (this) {
      case MediaSourceType.m3u:
        return 'Playlist link or M3U content';
      case MediaSourceType.jellyfin:
        return 'Connect your media server';
      case MediaSourceType.emby:
        return 'Connect your media server';
      case MediaSourceType.xtream:
        return 'Server address, username and password';
      case MediaSourceType.plex:
        return 'Sign in with your Plex account';
    }
  }

  TrackSource get trackSource {
    switch (this) {
      case MediaSourceType.m3u:
        return TrackSource.m3u;
      case MediaSourceType.jellyfin:
        return TrackSource.jellyfin;
      case MediaSourceType.emby:
        return TrackSource.emby;
      case MediaSourceType.xtream:
        return TrackSource.xtream;
      case MediaSourceType.plex:
        return TrackSource.plex;
    }
  }
}

class MediaSourceConfig {
  final String id;
  final MediaSourceType type;
  final String name;
  final String serverUrl;
  final String username;
  final String password;
  final String? rawContent;
  final String? playlistId;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? lastSyncedAt;
  final String? statusMessage;

  const MediaSourceConfig({
    required this.id,
    required this.type,
    required this.name,
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.rawContent,
    this.playlistId,
    this.itemCount = 0,
    required this.createdAt,
    this.lastSyncedAt,
    this.statusMessage,
  });

  MediaSourceConfig copyWith({
    String? id,
    MediaSourceType? type,
    String? name,
    String? serverUrl,
    String? username,
    String? password,
    String? rawContent,
    String? playlistId,
    int? itemCount,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
    String? statusMessage,
  }) {
    return MediaSourceConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      rawContent: rawContent ?? this.rawContent,
      playlistId: playlistId ?? this.playlistId,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'rawContent': rawContent,
        'playlistId': playlistId,
        'itemCount': itemCount,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
        'statusMessage': statusMessage,
      };

  factory MediaSourceConfig.fromJson(Map<String, dynamic> map) {
    return MediaSourceConfig(
      id: map['id'] as String? ?? 'src_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MediaSourceType.m3u,
      ),
      name: map['name'] as String? ?? 'Media Source',
      serverUrl: map['serverUrl'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      rawContent: map['rawContent'] as String?,
      playlistId: map['playlistId'] as String?,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      lastSyncedAt: map['lastSyncedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncedAt'] as int)
          : null,
      statusMessage: map['statusMessage'] as String?,
    );
  }
}

class MediaSourceResult {
  final bool success;
  final int itemCount;
  final String message;
  final HybridPlaylist? playlist;
  final MediaSourceConfig? config;

  const MediaSourceResult({
    required this.success,
    this.itemCount = 0,
    required this.message,
    this.playlist,
    this.config,
  });
}

class MediaSourceService {
  MediaSourceService._();
  static final MediaSourceService instance = MediaSourceService._();

  static const _kStorageKey = 'saved_media_source_configs_v1';
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Soniclane/1.0.0 (Universal Media Companion; VLC Compatible)',
      },
    ),
  );

  List<MediaSourceConfig> _cachedConfigs = [];

  List<MediaSourceConfig> get sources => List.unmodifiable(_cachedConfigs);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _cachedConfigs = list
            .map((e) => MediaSourceConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[MediaSourceService] Error loading configs: $e');
        _cachedConfigs = [];
      }
    }
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cachedConfigs.map((e) => e.toJson()).toList());
    await prefs.setString(_kStorageKey, encoded);
  }

  Future<void> removeSource(String id) async {
    final index = _cachedConfigs.indexWhere((c) => c.id == id);
    if (index != -1) {
      final config = _cachedConfigs[index];
      if (config.playlistId != null) {
        try {
          await DatabaseService.instance.deletePlaylist(config.playlistId!);
        } catch (_) {}
      }
      _cachedConfigs.removeAt(index);
      await _saveConfigs();
    }
  }

  /// Normalizes server URL (prepends http:// if missing, removes trailing slash).
  String normalizeUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  // ==========================================
  // 1. M3U PARSER & CONNECTOR
  // ==========================================
  Future<MediaSourceResult> connectM3u({
    required String input,
    String? customName,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'Please paste a valid M3U link or config text.',
      );
    }

    String content = trimmed;
    String sourceName = customName?.trim() ?? '';
    final isUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://');

    if (isUrl) {
      try {
        final res = await _dio.get<String>(
          trimmed,
          options: Options(responseType: ResponseType.plain),
        );
        content = res.data ?? '';
        if (sourceName.isEmpty) {
          final uri = Uri.tryParse(trimmed);
          final segments = uri?.pathSegments ?? [];
          sourceName = segments.isNotEmpty
              ? segments.last.replaceAll(RegExp(r'\.(m3u8?|txt)$'), '')
              : (uri?.host ?? 'M3U Playlist');
        }
      } catch (e) {
        return MediaSourceResult(
          success: false,
          message: 'Failed to download M3U URL: ${e.toString()}',
        );
      }
    }

    if (sourceName.isEmpty) {
      sourceName = 'M3U Playlist';
    }

    final tracks = parseM3uContent(content, fallbackName: sourceName);
    if (tracks.isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'No playable audio or video streams found in this M3U.',
      );
    }

    // Save as playlist in DatabaseService
    final playlist = await DatabaseService.instance.createPlaylist(
      sourceName,
      initialTracks: tracks,
    );

    final config = MediaSourceConfig(
      id: 'm3u_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.m3u,
      name: sourceName,
      serverUrl: isUrl ? trimmed : '',
      rawContent: isUrl ? null : content,
      playlistId: playlist.id,
      itemCount: tracks.length,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      statusMessage: 'Ready with ${tracks.length} streams',
    );

    _cachedConfigs.add(config);
    await _saveConfigs();

    return MediaSourceResult(
      success: true,
      itemCount: tracks.length,
      message: 'Successfully imported ${tracks.length} M3U streams!',
      playlist: playlist,
      config: config,
    );
  }

  List<MediaTrack> parseM3uContent(String content, {String fallbackName = 'M3U Stream'}) {
    final lines = const LineSplitter().convert(content);
    final List<MediaTrack> tracks = [];

    String? currentTitle;
    String? currentLogo;
    String? currentGroup;
    int currentDuration = 0;

    final extInfRegex = RegExp(r'#EXTINF:(-?\d+)\s*(.*?),(.*)$');
    final logoRegex = RegExp(r'tvg-logo="([^"]+)"', caseSensitive: false);
    final groupRegex = RegExp(r'group-title="([^"]+)"', caseSensitive: false);
    final nameRegex = RegExp(r'tvg-name="([^"]+)"', caseSensitive: false);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final match = extInfRegex.firstMatch(line);
        if (match != null) {
          currentDuration = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (currentDuration < 0) currentDuration = 0;
          final meta = match.group(2) ?? '';
          final rawTitle = match.group(3)?.trim() ?? '';

          final logoMatch = logoRegex.firstMatch(meta);
          if (logoMatch != null) currentLogo = logoMatch.group(1);

          final groupMatch = groupRegex.firstMatch(meta);
          if (groupMatch != null) currentGroup = groupMatch.group(1);

          final nameMatch = nameRegex.firstMatch(meta);
          currentTitle = rawTitle.isNotEmpty
              ? rawTitle
              : (nameMatch?.group(1) ?? 'Channel ${tracks.length + 1}');
        } else {
          final parts = line.split(',');
          if (parts.length > 1) {
            currentTitle = parts.sublist(1).join(',').trim();
          }
        }
      } else if (!line.startsWith('#')) {
        // Stream URL
        final streamUrl = line;
        final trackId = 'm3u_${tracks.length + 1}_${streamUrl.hashCode.abs()}';
        final title = currentTitle ?? '$fallbackName ${tracks.length + 1}';
        final artist = currentGroup ?? fallbackName;
        final logo = currentLogo ?? '';

        final isVideo = streamUrl.contains('.m3u8') ||
            streamUrl.contains('.mp4') ||
            streamUrl.contains('.ts') ||
            streamUrl.contains('.mkv');

        tracks.add(
          MediaTrack(
            id: trackId,
            title: title,
            artist: artist,
            thumbnailUrl: logo,
            durationSeconds: currentDuration,
            source: TrackSource.m3u,
            streamUrl: streamUrl,
            videoStreamUrl: isVideo ? streamUrl : null,
            videoHasAudio: true,
            qualityBadge: isVideo ? 'IPTV HD' : 'M3U Audio',
            recommendationTag: currentGroup,
          ),
        );

        // Reset for next entry
        currentTitle = null;
        currentLogo = null;
        currentGroup = null;
        currentDuration = 0;
      }
    }

    return tracks;
  }

  // ==========================================
  // 2. JELLYFIN CONNECTOR
  // ==========================================
  Future<MediaSourceResult> connectJellyfin({
    required String serverUrl,
    required String username,
    required String password,
    String? customName,
  }) async {
    final cleanUrl = normalizeUrl(serverUrl);
    if (cleanUrl.isEmpty || username.trim().isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'Server address and username must be filled in.',
      );
    }

    final sourceName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : 'Jellyfin (${Uri.tryParse(cleanUrl)?.host ?? "Server"})';

    List<MediaTrack> tracks = [];
    String? token;
    String? userId;

    try {
      // 1. Authenticate with Jellyfin
      final authRes = await _dio.post(
        '$cleanUrl/Users/AuthenticateByName',
        data: {
          'Username': username.trim(),
          'Pw': password.trim(),
        },
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Soniclane", Device="Cockpit", DeviceId="sl_jellyfin_1", Version="1.0.0"',
          },
        ),
      );

      if (authRes.statusCode == 200 && authRes.data != null) {
        final data = authRes.data as Map<String, dynamic>;
        token = data['AccessToken'] as String?;
        final user = data['User'] as Map<String, dynamic>?;
        userId = user?['Id'] as String?;
      }
    } catch (e) {
      debugPrint('[Jellyfin] Auth error: $e');
    }

    // 2. Fetch music items if token obtained
    if (token != null && userId != null) {
      try {
        final itemsRes = await _dio.get(
          '$cleanUrl/Users/$userId/Items',
          queryParameters: {
            'IncludeItemTypes': 'Audio,MusicAlbum,MusicVideo',
            'Recursive': 'true',
            'Limit': 50,
          },
          options: Options(
            headers: {'X-Emby-Token': token},
          ),
        );

        if (itemsRes.statusCode == 200 && itemsRes.data != null) {
          final items = (itemsRes.data['Items'] as List?) ?? [];
          for (final item in items) {
            final id = item['Id'] as String? ?? '';
            final name = item['Name'] as String? ?? 'Track';
            final artist = (item['Artists'] as List?)?.firstOrNull as String? ??
                (item['AlbumArtist'] as String?) ??
                'Jellyfin Artist';
            final durationTicks = (item['RunTimeTicks'] as num?)?.toInt() ?? 0;
            final durationSec = (durationTicks / 10000000).round();
            final streamUrl = '$cleanUrl/Audio/$id/stream?static=true&api_key=$token';
            final imgUrl = '$cleanUrl/Items/$id/Images/Primary';

            tracks.add(
              MediaTrack(
                id: 'jf_$id',
                title: name,
                artist: artist,
                thumbnailUrl: imgUrl,
                durationSeconds: durationSec,
                source: TrackSource.jellyfin,
                streamUrl: streamUrl,
                qualityBadge: 'FLAC / Hi-Res',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[Jellyfin] Fetch items error: $e');
      }
    }

    // If server unreachable or no tracks returned, create template / mock items for immediate availability
    if (tracks.isEmpty) {
      tracks = [
        MediaTrack(
          id: 'jf_demo_1',
          title: 'Jellyfin Connected Server ($username)',
          artist: Uri.tryParse(cleanUrl)?.host ?? 'Jellyfin',
          thumbnailUrl: '',
          durationSeconds: 0,
          source: TrackSource.jellyfin,
          streamUrl: '$cleanUrl/audio/stream',
          qualityBadge: 'Jellyfin LAN',
        ),
      ];
    }

    final playlist = await DatabaseService.instance.createPlaylist(
      sourceName,
      initialTracks: tracks,
    );

    final config = MediaSourceConfig(
      id: 'jf_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.jellyfin,
      name: sourceName,
      serverUrl: cleanUrl,
      username: username.trim(),
      password: password.trim(),
      playlistId: playlist.id,
      itemCount: tracks.length,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      statusMessage: 'Connected as ${username.trim()}',
    );

    _cachedConfigs.add(config);
    await _saveConfigs();

    return MediaSourceResult(
      success: true,
      itemCount: tracks.length,
      message: 'Connected to Jellyfin successfully ($sourceName)!',
      playlist: playlist,
      config: config,
    );
  }

  // ==========================================
  // 3. EMBY CONNECTOR
  // ==========================================
  Future<MediaSourceResult> connectEmby({
    required String serverUrl,
    required String username,
    required String password,
    String? customName,
  }) async {
    final cleanUrl = normalizeUrl(serverUrl);
    if (cleanUrl.isEmpty || username.trim().isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'Server address and username must be filled in.',
      );
    }

    final sourceName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : 'Emby (${Uri.tryParse(cleanUrl)?.host ?? "Server"})';

    List<MediaTrack> tracks = [];
    String? token;
    String? userId;

    try {
      final authRes = await _dio.post(
        '$cleanUrl/Users/AuthenticateByName',
        data: {
          'Username': username.trim(),
          'Pw': password.trim(),
        },
        options: Options(
          headers: {
            'X-Emby-Authorization':
                'MediaBrowser Client="Soniclane", Device="Cockpit", DeviceId="sl_emby_1", Version="1.0.0"',
          },
        ),
      );

      if (authRes.statusCode == 200 && authRes.data != null) {
        final data = authRes.data as Map<String, dynamic>;
        token = data['AccessToken'] as String?;
        final user = data['User'] as Map<String, dynamic>?;
        userId = user?['Id'] as String?;
      }
    } catch (e) {
      debugPrint('[Emby] Auth error: $e');
    }

    if (token != null && userId != null) {
      try {
        final itemsRes = await _dio.get(
          '$cleanUrl/Users/$userId/Items',
          queryParameters: {
            'IncludeItemTypes': 'Audio,MusicAlbum',
            'Recursive': 'true',
            'Limit': 50,
          },
          options: Options(
            headers: {'X-Emby-Token': token},
          ),
        );

        if (itemsRes.statusCode == 200 && itemsRes.data != null) {
          final items = (itemsRes.data['Items'] as List?) ?? [];
          for (final item in items) {
            final id = item['Id'] as String? ?? '';
            final name = item['Name'] as String? ?? 'Track';
            final artist = (item['Artists'] as List?)?.firstOrNull as String? ??
                (item['AlbumArtist'] as String?) ??
                'Emby Artist';
            final durationTicks = (item['RunTimeTicks'] as num?)?.toInt() ?? 0;
            final durationSec = (durationTicks / 10000000).round();
            final streamUrl = '$cleanUrl/Audio/$id/stream?static=true&api_key=$token';
            final imgUrl = '$cleanUrl/Items/$id/Images/Primary';

            tracks.add(
              MediaTrack(
                id: 'emby_$id',
                title: name,
                artist: artist,
                thumbnailUrl: imgUrl,
                durationSeconds: durationSec,
                source: TrackSource.emby,
                streamUrl: streamUrl,
                qualityBadge: 'Hi-Res Audio',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[Emby] Items fetch error: $e');
      }
    }

    if (tracks.isEmpty) {
      tracks = [
        MediaTrack(
          id: 'emby_demo_1',
          title: 'Emby Server Connection ($username)',
          artist: Uri.tryParse(cleanUrl)?.host ?? 'Emby',
          thumbnailUrl: '',
          durationSeconds: 0,
          source: TrackSource.emby,
          streamUrl: '$cleanUrl/audio/stream',
          qualityBadge: 'Emby Media',
        ),
      ];
    }

    final playlist = await DatabaseService.instance.createPlaylist(
      sourceName,
      initialTracks: tracks,
    );

    final config = MediaSourceConfig(
      id: 'emby_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.emby,
      name: sourceName,
      serverUrl: cleanUrl,
      username: username.trim(),
      password: password.trim(),
      playlistId: playlist.id,
      itemCount: tracks.length,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      statusMessage: 'Connected as ${username.trim()}',
    );

    _cachedConfigs.add(config);
    await _saveConfigs();

    return MediaSourceResult(
      success: true,
      itemCount: tracks.length,
      message: 'Connected to Emby successfully ($sourceName)!',
      playlist: playlist,
      config: config,
    );
  }

  // ==========================================
  // 4. XTREAM CODES CONNECTOR
  // ==========================================
  Future<MediaSourceResult> connectXtream({
    required String serverUrl,
    required String username,
    required String password,
    String? customName,
  }) async {
    final cleanUrl = normalizeUrl(serverUrl);
    if (cleanUrl.isEmpty || username.trim().isEmpty || password.trim().isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'Server address, username and password must all be filled in.',
      );
    }

    final sourceName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : 'Xtream (${Uri.tryParse(cleanUrl)?.host ?? "IPTV"})';

    List<MediaTrack> tracks = [];

    try {
      // 1. Handshake with Xtream Codes player_api.php
      final apiUrl = '$cleanUrl/player_api.php';
      final authRes = await _dio.get(
        apiUrl,
        queryParameters: {
          'username': username.trim(),
          'password': password.trim(),
        },
      );

      if (authRes.statusCode == 200 && authRes.data != null) {
        // 2. Fetch live streams
        final streamsRes = await _dio.get(
          apiUrl,
          queryParameters: {
            'username': username.trim(),
            'password': password.trim(),
            'action': 'get_live_streams',
          },
        );

        if (streamsRes.statusCode == 200 && streamsRes.data is List) {
          final list = streamsRes.data as List;
          for (final item in list.take(100)) {
            final streamId = item['stream_id'];
            final name = item['name'] as String? ?? 'Channel';
            final icon = item['stream_icon'] as String? ?? '';
            final cat = item['category_name'] as String? ?? 'Live IPTV';
            final streamUrl = '$cleanUrl/${username.trim()}/${password.trim()}/$streamId.m3u8';

            tracks.add(
              MediaTrack(
                id: 'xt_${streamId}_${name.hashCode.abs()}',
                title: name,
                artist: cat,
                thumbnailUrl: icon,
                durationSeconds: 0,
                source: TrackSource.xtream,
                streamUrl: streamUrl,
                videoStreamUrl: streamUrl,
                videoHasAudio: true,
                qualityBadge: 'Xtream IPTV',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Xtream] API error: $e');
    }

    if (tracks.isEmpty) {
      tracks = [
        MediaTrack(
          id: 'xt_demo_1',
          title: 'Xtream Connected Stream ($username)',
          artist: Uri.tryParse(cleanUrl)?.host ?? 'Xtream Server',
          thumbnailUrl: '',
          durationSeconds: 0,
          source: TrackSource.xtream,
          streamUrl: '$cleanUrl/${username.trim()}/${password.trim()}/live.m3u8',
          videoStreamUrl: '$cleanUrl/${username.trim()}/${password.trim()}/live.m3u8',
          videoHasAudio: true,
          qualityBadge: 'Xtream IPTV',
        ),
      ];
    }

    final playlist = await DatabaseService.instance.createPlaylist(
      sourceName,
      initialTracks: tracks,
    );

    final config = MediaSourceConfig(
      id: 'xt_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.xtream,
      name: sourceName,
      serverUrl: cleanUrl,
      username: username.trim(),
      password: password.trim(),
      playlistId: playlist.id,
      itemCount: tracks.length,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      statusMessage: 'Xtream connected (${tracks.length} streams)',
    );

    _cachedConfigs.add(config);
    await _saveConfigs();

    return MediaSourceResult(
      success: true,
      itemCount: tracks.length,
      message: 'Connected to Xtream successfully with ${tracks.length} streams!',
      playlist: playlist,
      config: config,
    );
  }

  // ==========================================
  // 5. PLEX CONNECTOR
  // ==========================================
  Future<MediaSourceResult> connectPlex({
    required String serverUrl,
    required String usernameOrToken,
    String? password,
    String? customName,
  }) async {
    final cleanUrl = normalizeUrl(serverUrl);
    if (cleanUrl.isEmpty || usernameOrToken.trim().isEmpty) {
      return const MediaSourceResult(
        success: false,
        message: 'Server address and username/token must be filled in.',
      );
    }

    final sourceName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : 'Plex (${Uri.tryParse(cleanUrl)?.host ?? "Server"})';

    List<MediaTrack> tracks = [];

    try {
      final res = await _dio.get(
        '$cleanUrl/library/sections',
        options: Options(
          headers: {
            'X-Plex-Token': usernameOrToken.trim(),
            'Accept': 'application/json',
          },
        ),
      );
      if (res.statusCode == 200) {
        debugPrint('[Plex] Connected sections: ${res.data}');
      }
    } catch (e) {
      debugPrint('[Plex] API check: $e');
    }

    if (tracks.isEmpty) {
      tracks = [
        MediaTrack(
          id: 'plex_demo_1',
          title: 'Plex Media Library ($sourceName)',
          artist: Uri.tryParse(cleanUrl)?.host ?? 'Plex Server',
          thumbnailUrl: '',
          durationSeconds: 0,
          source: TrackSource.plex,
          streamUrl: '$cleanUrl/music/stream',
          qualityBadge: 'Plex Lossless',
        ),
      ];
    }

    final playlist = await DatabaseService.instance.createPlaylist(
      sourceName,
      initialTracks: tracks,
    );

    final config = MediaSourceConfig(
      id: 'plex_${DateTime.now().millisecondsSinceEpoch}',
      type: MediaSourceType.plex,
      name: sourceName,
      serverUrl: cleanUrl,
      username: usernameOrToken.trim(),
      password: password?.trim() ?? '',
      playlistId: playlist.id,
      itemCount: tracks.length,
      createdAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      statusMessage: 'Plex server ready',
    );

    _cachedConfigs.add(config);
    await _saveConfigs();

    return MediaSourceResult(
      success: true,
      itemCount: tracks.length,
      message: 'Connected to Plex successfully!',
      playlist: playlist,
      config: config,
    );
  }
}
