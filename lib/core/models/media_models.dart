import 'package:flutter/material.dart';
import '../theme/sonic_tokens.dart';

enum TrackSource {
  customStream,
  usb,
  local,
  googleDrive;

  String get badgeLabel {
    switch (this) {
      case TrackSource.customStream:
        return '🌐 Remote Stream';
      case TrackSource.usb:
        return '💾 USB FLAC';
      case TrackSource.local:
        return '📱 On-Device';
      case TrackSource.googleDrive:
        return '☁️ Drive';
    }
  }

  String get shortTag {
    switch (this) {
      case TrackSource.customStream:
        return 'STREAM';
      case TrackSource.usb:
        return 'USB HI-RES';
      case TrackSource.local:
        return 'LOCAL';
      case TrackSource.googleDrive:
        return 'DRIVE';
    }
  }

  Color get accentColor {
    switch (this) {
      case TrackSource.customStream:
        return SonicTokens.primaryContainer;
      case TrackSource.usb:
        return SonicTokens.secondaryContainer;
      case TrackSource.local:
        return SonicTokens.tertiaryLight;
      case TrackSource.googleDrive:
        return SonicTokens.successGreen;
    }
  }

  bool get isOfflineCapable =>
      this == TrackSource.usb || this == TrackSource.local;

  static TrackSource fromString(String raw) {
    final normalized = raw.toLowerCase();
    return TrackSource.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => TrackSource.customStream,
    );
  }
}

class MediaTrack {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationSeconds;
  final TrackSource source;
  final String? streamUrl;
  final String? videoStreamUrl;
  final bool videoHasAudio;
  final String? localPath;
  final String qualityBadge;
  final String? recommendationTag;
  final String? viewCountLabel;
  final int playCount;
  final int lastPositionMs;
  final bool isCompleted;
  final DateTime? lastPlayedAt;
  final bool isAvailable;
  final String? channelId;

  const MediaTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.source,
    this.channelId,
    this.streamUrl,
    this.videoStreamUrl,
    this.videoHasAudio = false,
    this.localPath,
    this.qualityBadge = '128k AAC',
    this.recommendationTag,
    this.viewCountLabel,
    this.playCount = 0,
    this.lastPositionMs = 0,
    this.isCompleted = false,
    this.lastPlayedAt,
    this.isAvailable = true,
  });

  String get playbackUri {
    if (localPath != null && localPath!.isNotEmpty) {
      return localPath!.startsWith('file://')
          ? localPath!
          : 'file://${localPath!}';
    }
    return streamUrl ?? '';
  }

  double get progressRatio {
    if (durationSeconds <= 0) return 0;
    return (lastPositionMs / (durationSeconds * 1000)).clamp(0.0, 1.0);
  }

  String get formattedDuration => formatSeconds(durationSeconds);

  String get formattedResumePosition =>
      formatSeconds((lastPositionMs / 1000).round());

  static String formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  MediaTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnailUrl,
    int? durationSeconds,
    TrackSource? source,
    String? streamUrl,
    String? videoStreamUrl,
    bool? videoHasAudio,
    String? localPath,
    String? qualityBadge,
    String? recommendationTag,
    String? viewCountLabel,
    int? playCount,
    int? lastPositionMs,
    bool? isCompleted,
    DateTime? lastPlayedAt,
    bool? isAvailable,
    String? channelId,
  }) {
    return MediaTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      source: source ?? this.source,
      channelId: channelId ?? this.channelId,
      streamUrl: streamUrl ?? this.streamUrl,
      videoStreamUrl: videoStreamUrl ?? this.videoStreamUrl,
      videoHasAudio: videoHasAudio ?? this.videoHasAudio,
      localPath: localPath ?? this.localPath,
      qualityBadge: qualityBadge ?? this.qualityBadge,
      recommendationTag: recommendationTag ?? this.recommendationTag,
      viewCountLabel: viewCountLabel ?? this.viewCountLabel,
      playCount: playCount ?? this.playCount,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      isCompleted: isCompleted ?? this.isCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'channel_id': channelId,
        'thumbnail_url': thumbnailUrl,
        'duration_seconds': durationSeconds,
        'source': source.name,
        'stream_url': streamUrl,
        'video_stream_url': videoStreamUrl,
        'local_path': localPath,
        'quality_badge': qualityBadge,
        'recommendation_tag': recommendationTag,
        'view_count_label': viewCountLabel,
        'play_count': playCount,
        'last_position_ms': lastPositionMs,
        'is_completed': isCompleted ? 1 : 0,
        'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      };

  factory MediaTrack.fromMap(Map<String, dynamic> map) => MediaTrack(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? 'Unknown Track',
        artist: (map['artist'] as String?) ?? 'Unknown Artist',
        channelId: map['channel_id'] as String?,
        thumbnailUrl: (map['thumbnail_url'] as String?) ?? '',
        durationSeconds: (map['duration_seconds'] as int?) ?? 0,
        source:
            TrackSource.fromString((map['source'] as String?) ?? 'customStream'),
        streamUrl: map['stream_url'] as String?,
        videoStreamUrl: map['video_stream_url'] as String?,
        localPath: map['local_path'] as String?,
        qualityBadge: (map['quality_badge'] as String?) ?? '128k AAC',
        recommendationTag: map['recommendation_tag'] as String?,
        viewCountLabel: map['view_count_label'] as String?,
        playCount: (map['play_count'] as int?) ?? 0,
        lastPositionMs: (map['last_position_ms'] as int?) ?? 0,
        isCompleted: ((map['is_completed'] as int?) ?? 0) == 1,
        lastPlayedAt: map['last_played_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'] as int)
            : null,
      );
}

class HybridPlaylist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<MediaTrack> items;

  const HybridPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  int get streamCount =>
      items.where((t) => t.source == TrackSource.customStream).length;

  int get usbCount => items.where((t) => t.source == TrackSource.usb).length;

  int get localCount =>
      items.where((t) => t.source == TrackSource.local).length;

  int get totalDurationSeconds =>
      items.fold(0, (sum, item) => sum + item.durationSeconds);

  String get formattedTotalDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final mins = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) return '$hours hr $mins min';
    return '$mins min';
  }

  List<String> get coverArtUrls => items
      .map((e) => e.thumbnailUrl)
      .where((url) => url.isNotEmpty)
      .take(4)
      .toList();

  HybridPlaylist copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    List<MediaTrack>? items,
  }) {
    return HybridPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}

class FollowedChannel {
  final String channelId;
  final String channelName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? serverUrl;
  final int? trackCount;
  final DateTime followedAt;

  const FollowedChannel({
    required this.channelId,
    required this.channelName,
    this.avatarUrl,
    this.bannerUrl,
    this.serverUrl,
    this.trackCount,
    required this.followedAt,
  });

  Map<String, dynamic> toMap() => {
        'channel_id': channelId,
        'channel_name': channelName,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
        'server_url': serverUrl,
        'track_count': trackCount,
        'followed_at': followedAt.millisecondsSinceEpoch,
      };

  factory FollowedChannel.fromMap(Map<String, dynamic> map) => FollowedChannel(
        channelId: (map['channel_id'] as String?) ?? '',
        channelName: (map['channel_name'] as String?) ?? 'Unknown Channel',
        avatarUrl: map['avatar_url'] as String?,
        bannerUrl: map['banner_url'] as String?,
        serverUrl: map['server_url'] as String?,
        trackCount: map['track_count'] as int?,
        followedAt: map['followed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['followed_at'] as int)
            : DateTime.now(),
      );

  FollowedChannel copyWith({
    String? channelId,
    String? channelName,
    String? avatarUrl,
    String? bannerUrl,
    String? serverUrl,
    int? trackCount,
    DateTime? followedAt,
  }) {
    return FollowedChannel(
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      serverUrl: serverUrl ?? this.serverUrl,
      trackCount: trackCount ?? this.trackCount,
      followedAt: followedAt ?? this.followedAt,
    );
  }
}

class ChannelDetails {
  final String channelId;
  final String channelName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? subscriberCountLabel;
  final List<MediaTrack> tracks;
  final List<HybridPlaylist> playlists;

  const ChannelDetails({
    required this.channelId,
    required this.channelName,
    this.avatarUrl,
    this.bannerUrl,
    this.subscriberCountLabel,
    this.tracks = const [],
    this.playlists = const [],
  });

  ChannelDetails copyWith({
    String? channelId,
    String? channelName,
    String? avatarUrl,
    String? bannerUrl,
    String? subscriberCountLabel,
    List<MediaTrack>? tracks,
    List<HybridPlaylist>? playlists,
  }) {
    return ChannelDetails(
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      subscriberCountLabel: subscriberCountLabel ?? this.subscriberCountLabel,
      tracks: tracks ?? this.tracks,
      playlists: playlists ?? this.playlists,
    );
  }
}

class ServerInstance {
  final String url;
  final String name;
  final String tier; // 'Custom Server'
  final int? latencyMs;
  final bool isHealthy;

  const ServerInstance({
    required this.url,
    required this.name,
    required this.tier,
    this.latencyMs,
    this.isHealthy = true,
  });

  ServerInstance copyWith({
    String? url,
    String? name,
    String? tier,
    int? latencyMs,
    bool? isHealthy,
  }) {
    return ServerInstance(
      url: url ?? this.url,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      latencyMs: latencyMs ?? this.latencyMs,
      isHealthy: isHealthy ?? this.isHealthy,
    );
  }
}

class StorageDeviceInfo {
  final String id;
  final String name;
  final String subtitle;
  final TrackSource source;
  final bool isMounted;
  final int trackCount;
  final double usedGb;
  final double totalGb;
  final String? rootPath;

  const StorageDeviceInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.source,
    required this.isMounted,
    required this.trackCount,
    required this.usedGb,
    required this.totalGb,
    this.rootPath,
  });

  double get usageRatio => totalGb > 0 ? (usedGb / totalGb).clamp(0.0, 1.0) : 0;
}

class EqSettings {
  final String presetName;
  final List<double> bands; // 10 bands: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
  final double playbackSpeed;
  final double bassBoostDb;
  final bool spatialDsp;
  final bool volumeNormalization;

  const EqSettings({
    this.presetName = 'Cabin Bass',
    this.bands = const [4.0, 3.5, 2.0, 0.0, -1.0, 0.5, 1.5, 2.5, 3.0, 2.0],
    this.playbackSpeed = 1.0,
    this.bassBoostDb = 4.0,
    this.spatialDsp = true,
    this.volumeNormalization = true,
  });

  static const Map<String, List<double>> presets = {
    'Cabin Bass': [4.0, 3.5, 2.0, 0.0, -1.0, 0.5, 1.5, 2.5, 3.0, 2.0],
    'Highway Clear': [1.0, 1.5, 1.0, 0.5, 2.0, 3.0, 3.5, 2.5, 1.5, 1.0],
    'Vocal Podcast': [-2.0, -1.0, 0.0, 2.0, 4.0, 4.5, 3.5, 1.5, 0.0, -1.0],
    'Flat Master': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  };

  EqSettings copyWith({
    String? presetName,
    List<double>? bands,
    double? playbackSpeed,
    double? bassBoostDb,
    bool? spatialDsp,
    bool? volumeNormalization,
  }) {
    return EqSettings(
      presetName: presetName ?? this.presetName,
      bands: bands ?? this.bands,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      bassBoostDb: bassBoostDb ?? this.bassBoostDb,
      spatialDsp: spatialDsp ?? this.spatialDsp,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
    );
  }
}

class AppSettings {
  final bool autoSelectFastestServer;
  final String customServerUrl;
  final String syncedDefaultServers;
  final String audioBitrate; // '128k' | '256k'
  final String videoQuality; // '720p' | '1080p'
  final bool gpsParkDetection;
  final bool drivingVideoLockout;
  final bool autoFlowHabits;
  final bool wifiServerEnabled;
  final bool isPro;

  const AppSettings({
    this.autoSelectFastestServer = true,
    this.customServerUrl = '',
    this.syncedDefaultServers = '',
    this.audioBitrate = '128k',
    this.videoQuality = '720p',
    this.gpsParkDetection = false,
    this.drivingVideoLockout = false,
    this.autoFlowHabits = true,
    this.wifiServerEnabled = false,
    this.isPro = true,
  });

  AppSettings copyWith({
    bool? autoSelectFastestServer,
    String? customServerUrl,
    String? syncedDefaultServers,
    String? audioBitrate,
    String? videoQuality,
    bool? gpsParkDetection,
    bool? drivingVideoLockout,
    bool? autoFlowHabits,
    bool? wifiServerEnabled,
    bool? isPro,
  }) {
    return AppSettings(
      autoSelectFastestServer:
          autoSelectFastestServer ?? this.autoSelectFastestServer,
      customServerUrl: customServerUrl ?? this.customServerUrl,
      syncedDefaultServers:
          syncedDefaultServers ?? this.syncedDefaultServers,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      videoQuality: videoQuality ?? this.videoQuality,
      gpsParkDetection: gpsParkDetection ?? this.gpsParkDetection,
      drivingVideoLockout: drivingVideoLockout ?? this.drivingVideoLockout,
      autoFlowHabits: autoFlowHabits ?? this.autoFlowHabits,
      wifiServerEnabled: wifiServerEnabled ?? this.wifiServerEnabled,
      isPro: isPro ?? this.isPro,
    );
  }
}
