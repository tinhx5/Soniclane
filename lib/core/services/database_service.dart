import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/media_models.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  static bool _ffiInitialized = false;
  static String? testDbDirectoryPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _initDb() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }

    final Directory appDir;
    if (testDbDirectoryPath != null) {
      appDir = Directory(testDbDirectoryPath!);
    } else {
      appDir = await getApplicationSupportDirectory();
    }
    await appDir.create(recursive: true);
    final dbPath = p.join(appDir.path, 'soniclane_cockpit.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playback_history (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            channel_id TEXT,
            thumbnail_url TEXT,
            duration_seconds INTEGER DEFAULT 0,
            source TEXT NOT NULL,
            stream_url TEXT,
            video_stream_url TEXT,
            local_path TEXT,
            quality_badge TEXT,
            recommendation_tag TEXT,
            view_count_label TEXT,
            play_count INTEGER DEFAULT 1,
            last_position_ms INTEGER DEFAULT 0,
            is_completed INTEGER DEFAULT 0,
            last_played_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlist_items (
            row_id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id TEXT NOT NULL,
            track_id TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            channel_id TEXT,
            thumbnail_url TEXT,
            duration_seconds INTEGER DEFAULT 0,
            source TEXT NOT NULL,
            stream_url TEXT,
            video_stream_url TEXT,
            local_path TEXT,
            quality_badge TEXT,
            sort_order INTEGER DEFAULT 0,
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE liked_tracks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            channel_id TEXT,
            thumbnail_url TEXT,
            duration_seconds INTEGER DEFAULT 0,
            source TEXT NOT NULL,
            stream_url TEXT,
            video_stream_url TEXT,
            local_path TEXT,
            quality_badge TEXT,
            liked_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE recent_searches (
            query TEXT PRIMARY KEY,
            searched_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_offline_tracks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            channel_id TEXT,
            thumbnail_url TEXT,
            duration_seconds INTEGER DEFAULT 0,
            source TEXT NOT NULL,
            local_path TEXT NOT NULL,
            quality_badge TEXT,
            added_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS followed_channels (
            channel_id TEXT PRIMARY KEY,
            channel_name TEXT NOT NULL,
            avatar_url TEXT,
            banner_url TEXT,
            server_url TEXT,
            track_count INTEGER DEFAULT 0,
            followed_at INTEGER NOT NULL
          )
        ''');

        await _seedInitialData(db);
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS followed_channels (
            channel_id TEXT PRIMARY KEY,
            channel_name TEXT NOT NULL,
            avatar_url TEXT,
            banner_url TEXT,
            server_url TEXT,
            track_count INTEGER DEFAULT 0,
            followed_at INTEGER NOT NULL
          )
        ''');
        for (final table in [
          'playback_history',
          'playlist_items',
          'liked_tracks',
          'cached_offline_tracks'
        ]) {
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN channel_id TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('playlists', {
      'id': 'pl_my_driving_mix',
      'name': 'My Driving Mix',
      'created_at': now,
    });
  }

  // --- Playback History & Smart Resume ---

  Future<void> recordPlayProgress(MediaTrack track, int positionMs) async {
    final db = await database;
    final totalMs = track.durationSeconds * 1000;
    final completed = totalMs > 0 && positionMs >= (totalMs * 0.9);
    final existing = await db.query(
      'playback_history',
      where: 'id = ?',
      whereArgs: [track.id],
    );

    final playCount = existing.isNotEmpty
        ? ((existing.first['play_count'] as int?) ?? 1)
        : 1;

    await db.insert(
      'playback_history',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'thumbnail_url': track.thumbnailUrl,
        'duration_seconds': track.durationSeconds,
        'source': track.source.name,
        'stream_url': track.streamUrl,
        'video_stream_url': track.videoStreamUrl,
        'local_path': track.localPath,
        'quality_badge': track.qualityBadge,
        'recommendation_tag': track.recommendationTag,
        'view_count_label': track.viewCountLabel,
        'play_count': playCount,
        'last_position_ms': positionMs,
        'is_completed': completed ? 1 : 0,
        'last_played_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> incrementPlayCount(MediaTrack track) async {
    final db = await database;
    final existing = await db.query(
      'playback_history',
      where: 'id = ?',
      whereArgs: [track.id],
    );
    final nextCount = existing.isNotEmpty
        ? ((existing.first['play_count'] as int?) ?? 0) + 1
        : 1;
    await db.insert(
      'playback_history',
      {
        ...track.toMap(),
        'play_count': nextCount,
        'last_played_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MediaTrack?> getLatestUnfinishedTrack() async {
    final db = await database;
    final rows = await db.query(
      'playback_history',
      where: 'is_completed = 0 AND last_position_ms > 5000',
      orderBy: 'last_played_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MediaTrack.fromMap(rows.first);
  }

  Future<List<MediaTrack>> getListenAgainTracks({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      'playback_history',
      orderBy: 'play_count DESC, last_played_at DESC',
      limit: limit,
    );
    return rows.map(MediaTrack.fromMap).toList();
  }

  Future<List<MediaTrack>> getFullHistory({bool unfinishedOnly = false}) async {
    final db = await database;
    final rows = await db.query(
      'playback_history',
      where: unfinishedOnly ? 'is_completed = 0' : null,
      orderBy: 'last_played_at DESC',
    );
    return rows.map(MediaTrack.fromMap).toList();
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('playback_history');
  }

  Future<void> deleteHistoryItem(String id) async {
    final db = await database;
    await db.delete('playback_history', where: 'id = ?', whereArgs: [id]);
  }

  // --- Hybrid Playlists ---

  Future<List<HybridPlaylist>> getPlaylists() async {
    final db = await database;
    final plRows = await db.query('playlists', orderBy: 'created_at DESC');
    final List<HybridPlaylist> list = [];

    for (final row in plRows) {
      final plId = row['id'] as String;
      final itemRows = await db.query(
        'playlist_items',
        where: 'playlist_id = ?',
        whereArgs: [plId],
        orderBy: 'sort_order ASC, row_id ASC',
      );
      final items = itemRows.map((item) {
        final localPath = item['local_path'] as String?;
        final src =
            TrackSource.fromString((item['source'] as String?) ?? 'customStream');
        final available = !src.isOfflineCapable ||
            (localPath != null && File(localPath).existsSync());
        return MediaTrack(
          id: item['track_id'] as String,
          title: item['title'] as String,
          artist: item['artist'] as String,
          thumbnailUrl: (item['thumbnail_url'] as String?) ?? '',
          durationSeconds: (item['duration_seconds'] as int?) ?? 0,
          source: src,
          streamUrl: item['stream_url'] as String?,
          videoStreamUrl: item['video_stream_url'] as String?,
          localPath: localPath,
          qualityBadge: (item['quality_badge'] as String?) ?? '128k AAC',
          isAvailable: available,
        );
      }).toList();

      list.add(
        HybridPlaylist(
          id: plId,
          name: row['name'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
          items: items,
        ),
      );
    }
    return list;
  }

  Future<HybridPlaylist> createPlaylist(
    String name, {
    List<MediaTrack> initialTracks = const [],
  }) async {
    final db = await database;
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    await db.insert('playlists', {
      'id': id,
      'name': name,
      'created_at': now.millisecondsSinceEpoch,
    });
    for (int i = 0; i < initialTracks.length; i++) {
      await addTrackToPlaylist(id, initialTracks[i], sortOrder: i);
    }
    return HybridPlaylist(id: id, name: name, createdAt: now, items: initialTracks);
  }

  Future<void> addTrackToPlaylist(
    String playlistId,
    MediaTrack track, {
    int? sortOrder,
  }) async {
    final db = await database;
    await db.insert('playlist_items', {
      'playlist_id': playlistId,
      'track_id': track.id,
      'title': track.title,
      'artist': track.artist,
      'thumbnail_url': track.thumbnailUrl,
      'duration_seconds': track.durationSeconds,
      'source': track.source.name,
      'stream_url': track.streamUrl,
      'video_stream_url': track.videoStreamUrl,
      'local_path': track.localPath,
      'quality_badge': track.qualityBadge,
      'sort_order': sortOrder ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final db = await database;
    await db.delete(
      'playlist_items',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await database;
    await db.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [playlistId]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }

  // --- Liked Tracks ---

  Future<List<MediaTrack>> getLikedTracks() async {
    final db = await database;
    final rows = await db.query('liked_tracks', orderBy: 'liked_at DESC');
    return rows.map(MediaTrack.fromMap).toList();
  }

  Future<bool> isTrackLiked(String trackId) async {
    final db = await database;
    final rows = await db.query(
      'liked_tracks',
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleLikeTrack(MediaTrack track) async {
    final db = await database;
    final liked = await isTrackLiked(track.id);
    if (liked) {
      await db.delete('liked_tracks', where: 'id = ?', whereArgs: [track.id]);
      return false;
    } else {
      await db.insert(
        'liked_tracks',
        {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'thumbnail_url': track.thumbnailUrl,
          'duration_seconds': track.durationSeconds,
          'source': track.source.name,
          'stream_url': track.streamUrl,
          'video_stream_url': track.videoStreamUrl,
          'local_path': track.localPath,
          'quality_badge': track.qualityBadge,
          'liked_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    }
  }

  // --- Offline Downloads / Local Cache ---

  Future<void> saveOfflineTrack(MediaTrack track, String localPath) async {
    final db = await database;
    await db.insert(
      'cached_offline_tracks',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'channel_id': track.channelId,
        'thumbnail_url': track.thumbnailUrl,
        'duration_seconds': track.durationSeconds,
        'source': TrackSource.local.name,
        'local_path': localPath,
        'quality_badge': track.qualityBadge,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MediaTrack>> getOfflineTracks() async {
    final db = await database;
    final rows = await db.query('cached_offline_tracks', orderBy: 'added_at DESC');
    return rows.map(MediaTrack.fromMap).toList();
  }

  Future<MediaTrack?> getOfflineTrackById(String trackId) async {
    final db = await database;
    final rows = await db.query(
      'cached_offline_tracks',
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final track = MediaTrack.fromMap(rows.first);
    if (track.localPath != null && File(track.localPath!).existsSync()) {
      return track;
    }
    return null;
  }

  Future<void> deleteOfflineTrack(String trackId) async {
    final existing = await getOfflineTrackById(trackId);
    if (existing?.localPath != null) {
      final f = File(existing!.localPath!);
      if (await f.exists()) {
        await f.delete();
      }
    }
    final db = await database;
    await db.delete('cached_offline_tracks', where: 'id = ?', whereArgs: [trackId]);
  }

  // --- Followed Channels (Personalization) ---

  Future<List<FollowedChannel>> getFollowedChannels() async {
    final db = await database;
    final rows = await db.query(
      'followed_channels',
      orderBy: 'followed_at DESC',
    );
    return rows.map(FollowedChannel.fromMap).toList();
  }

  Future<bool> isChannelFollowed(String channelId, {String? channelName}) async {
    final cleanId = channelId.trim();
    if (cleanId.isEmpty && (channelName == null || channelName.trim().isEmpty)) {
      return false;
    }
    final db = await database;
    if (cleanId.isNotEmpty) {
      final rows = await db.query(
        'followed_channels',
        where: 'channel_id = ?',
        whereArgs: [cleanId],
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }
    if (channelName != null && channelName.trim().isNotEmpty) {
      final rows = await db.query(
        'followed_channels',
        where: 'LOWER(channel_name) = ?',
        whereArgs: [channelName.trim().toLowerCase()],
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<FollowedChannel?> getFollowedChannel(String channelId, {String? channelName}) async {
    final cleanId = channelId.trim();
    final db = await database;
    if (cleanId.isNotEmpty) {
      final rows = await db.query(
        'followed_channels',
        where: 'channel_id = ?',
        whereArgs: [cleanId],
        limit: 1,
      );
      if (rows.isNotEmpty) return FollowedChannel.fromMap(rows.first);
    }
    if (channelName != null && channelName.trim().isNotEmpty) {
      final rows = await db.query(
        'followed_channels',
        where: 'LOWER(channel_name) = ?',
        whereArgs: [channelName.trim().toLowerCase()],
        limit: 1,
      );
      if (rows.isNotEmpty) return FollowedChannel.fromMap(rows.first);
    }
    return null;
  }

  Future<void> followChannel(FollowedChannel channel) async {
    final db = await database;
    if (channel.channelName.trim().isNotEmpty) {
      await db.delete(
        'followed_channels',
        where: 'LOWER(channel_name) = ?',
        whereArgs: [channel.channelName.trim().toLowerCase()],
      );
    }
    await db.insert(
      'followed_channels',
      channel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unfollowChannel(String channelId, {String? channelName}) async {
    final db = await database;
    if (channelId.trim().isNotEmpty) {
      await db.delete(
        'followed_channels',
        where: 'channel_id = ?',
        whereArgs: [channelId.trim()],
      );
    }
    if (channelName != null && channelName.trim().isNotEmpty) {
      await db.delete(
        'followed_channels',
        where: 'LOWER(channel_name) = ?',
        whereArgs: [channelName.trim().toLowerCase()],
      );
    }
  }

  // --- Recent Searches ---

  Future<List<String>> getRecentSearches() async {
    final db = await database;
    final rows = await db.query(
      'recent_searches',
      orderBy: 'searched_at DESC',
      limit: 10,
    );
    return rows.map((e) => e['query'] as String).toList();
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final db = await database;
    await db.insert(
      'recent_searches',
      {'query': q, 'searched_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeRecentSearch(String query) async {
    final db = await database;
    await db.delete('recent_searches', where: 'query = ?', whereArgs: [query]);
  }

  Future<void> clearRecentSearches() async {
    final db = await database;
    await db.delete('recent_searches');
  }

  // --- App Settings ---

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      autoSelectFastestServer: prefs.getBool('auto_fastest_server') ?? true,
      customServerUrl: prefs.getString('custom_server_url') ?? '',
      syncedDefaultServers: prefs.getString('synced_default_servers') ?? '',
      audioBitrate: prefs.getString('audio_bitrate') ?? '128k',
      videoQuality: prefs.getString('video_quality') ?? '720p',
      gpsParkDetection: prefs.getBool('gps_park_detection') ?? false,
      drivingVideoLockout: prefs.getBool('driving_video_lockout') ?? false,
      autoFlowHabits: prefs.getBool('auto_flow_habits') ?? true,
      wifiServerEnabled: prefs.getBool('wifi_server_enabled') ?? false,
      isPro: prefs.getBool('is_pro') ?? false,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_fastest_server', s.autoSelectFastestServer);
    await prefs.setString('custom_server_url', s.customServerUrl);
    await prefs.setString('synced_default_servers', s.syncedDefaultServers);
    await prefs.setString('audio_bitrate', s.audioBitrate);
    await prefs.setString('video_quality', s.videoQuality);
    await prefs.setBool('gps_park_detection', s.gpsParkDetection);
    await prefs.setBool('driving_video_lockout', s.drivingVideoLockout);
    await prefs.setBool('auto_flow_habits', s.autoFlowHabits);
    await prefs.setBool('wifi_server_enabled', s.wifiServerEnabled);
    await prefs.setBool('is_pro', s.isPro);
  }
}
