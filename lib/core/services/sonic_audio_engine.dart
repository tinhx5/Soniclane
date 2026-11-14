import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media_models.dart';
import '../utils/url_parser.dart';
import 'database_service.dart';
import 'storage_scanner.dart';
import 'stream_resolver.dart';

class PlaybackSnapshot {
  final MediaTrack? currentTrack;
  final List<MediaTrack> queue;
  final List<MediaTrack> habitSuggestions;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool isVideoMode;
  final bool isShuffle;
  final bool isRepeat;
  final bool isLiked;
  final Duration position;
  final Duration duration;
  final String? activeTierLabel;
  final String? activePlaylistName;
  final String? activePlaylistId;
  final bool isTempPlaylist;
  final int? sleepTimerRemainingSec;
  final EqSettings eqSettings;
  final String? statusBanner;

  const PlaybackSnapshot({
    this.currentTrack,
    this.queue = const [],
    this.habitSuggestions = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isVideoMode = false,
    this.isShuffle = false,
    this.isRepeat = false,
    this.isLiked = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.activeTierLabel,
    this.activePlaylistName,
    this.activePlaylistId,
    this.isTempPlaylist = false,
    this.sleepTimerRemainingSec,
    this.eqSettings = const EqSettings(),
    this.statusBanner,
  });

  PlaybackSnapshot copyWith({
    MediaTrack? currentTrack,
    List<MediaTrack>? queue,
    List<MediaTrack>? habitSuggestions,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    bool? isVideoMode,
    bool? isShuffle,
    bool? isRepeat,
    bool? isLiked,
    Duration? position,
    Duration? duration,
    String? activeTierLabel,
    String? activePlaylistName,
    String? activePlaylistId,
    bool clearActivePlaylistId = false,
    bool? isTempPlaylist,
    int? sleepTimerRemainingSec,
    bool clearSleepTimer = false,
    EqSettings? eqSettings,
    String? statusBanner,
    bool clearBanner = false,
  }) {
    return PlaybackSnapshot(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      habitSuggestions: habitSuggestions ?? this.habitSuggestions,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isVideoMode: isVideoMode ?? this.isVideoMode,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      isLiked: isLiked ?? this.isLiked,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      activeTierLabel: activeTierLabel ?? this.activeTierLabel,
      activePlaylistName: activePlaylistName ?? this.activePlaylistName,
      activePlaylistId: clearActivePlaylistId
          ? null
          : (activePlaylistId ?? this.activePlaylistId),
      isTempPlaylist: isTempPlaylist ?? this.isTempPlaylist,
      sleepTimerRemainingSec: clearSleepTimer
          ? null
          : (sleepTimerRemainingSec ?? this.sleepTimerRemainingSec),
      eqSettings: eqSettings ?? this.eqSettings,
      statusBanner: clearBanner ? null : (statusBanner ?? this.statusBanner),
    );
  }
}

/// Bridges iOS CarPlay / Control Center / Android Auto / Steering Wheel AVRCP
/// commands directly to SonicAudioEngine.
class SonicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final SonicAudioEngine engine;

  SonicAudioHandler(this.engine);

  @override
  Future<void> play() => engine.play();

  @override
  Future<void> pause() => engine.pause();

  @override
  Future<void> stop() => engine.stop();

  @override
  Future<void> skipToNext() => engine.skipToNext();

  @override
  Future<void> skipToPrevious() => engine.skipToPrevious();

  @override
  Future<void> fastForward() => engine.seekRelative(const Duration(seconds: 15));

  @override
  Future<void> rewind() => engine.seekRelative(const Duration(seconds: -15));

  @override
  Future<void> seek(Duration position) => engine.seekTo(position);

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(
          id: 'sonic_explore',
          title: 'Explore Trending',
          playable: false,
        ),
        MediaItem(
          id: 'sonic_playlists',
          title: 'Hybrid Playlists',
          playable: false,
        ),
        MediaItem(
          id: 'sonic_liked',
          title: 'Liked Songs',
          playable: false,
        ),
        MediaItem(
          id: 'sonic_offline',
          title: 'USB & Offline Files',
          playable: false,
        ),
      ];
    }

    if (parentMediaId == 'sonic_explore') {
      final list = await StreamResolver.instance.fetchTrendingMusic();
      return list.map(_toMediaItem).toList();
    }

    if (parentMediaId == 'sonic_liked') {
      final list = await DatabaseService.instance.getLikedTracks();
      return list.map(_toMediaItem).toList();
    }

    if (parentMediaId == 'sonic_offline') {
      final cached = await DatabaseService.instance.getOfflineTracks();
      final local = await StorageScanner.instance.scanInternalDeviceMusic();
      return [...cached, ...local].map(_toMediaItem).toList();
    }

    if (parentMediaId == 'sonic_playlists') {
      final pls = await DatabaseService.instance.getPlaylists();
      return pls
          .map((p) => MediaItem(
                id: 'pl_dir_${p.id}',
                title: p.name,
                album:
                    '${p.items.length} tracks • 🌐 ${p.streamCount} • 💾 ${p.usbCount}',
                playable: false,
              ))
          .toList();
    }

    if (parentMediaId.startsWith('pl_dir_')) {
      final plId = parentMediaId.replaceFirst('pl_dir_', '');
      final pls = await DatabaseService.instance.getPlaylists();
      final match = pls.where((p) => p.id == plId).toList();
      if (match.isNotEmpty) {
        return match.first.items
            .map((t) => _toMediaItem(t, prefix: 'pl_${plId}__'))
            .toList();
      }
    }

    return const [];
  }

  @override
  Future<List<MediaItem>> search(String query,
      [Map<String, dynamic>? extras]) async {
    final results = await StreamResolver.instance.searchRemote(query);
    return results.map(_toMediaItem).toList();
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    if (mediaId.startsWith('pl_') && mediaId.contains('__')) {
      final sep = mediaId.indexOf('__');
      final plId = mediaId.substring(3, sep);
      final trackId = mediaId.substring(sep + 2);
      final pls = await DatabaseService.instance.getPlaylists();
      final match = pls.where((p) => p.id == plId).toList();
      if (match.isNotEmpty) {
        final pl = match.first;
        final target = pl.items.firstWhere(
          (t) => t.id == trackId,
          orElse: () => pl.items.first,
        );
        await engine.playTrack(
          target,
          queue: pl.items,
          playlistName: pl.name,
          playlistId: pl.id,
        );
        return;
      }
    }

    final offline = await DatabaseService.instance.getOfflineTrackById(mediaId);
    if (offline != null) {
      await engine.playTrack(offline);
      return;
    }

    final bundle = await StreamResolver.instance.resolveTrack(mediaId);
    if (bundle != null) {
      await engine.playTrack(bundle.track,
          relatedForAutoQueue: bundle.relatedTracks);
    }
  }

  MediaItem _toMediaItem(MediaTrack t, {String prefix = ''}) {
    return MediaItem(
      id: '$prefix${t.id}',
      title: t.title,
      artist: '${t.artist} • ${t.source.shortTag}',
      duration: Duration(seconds: t.durationSeconds),
      artUri: t.thumbnailUrl.isNotEmpty ? Uri.tryParse(t.thumbnailUrl) : null,
      playable: true,
    );
  }

  void broadcastTrack(MediaTrack track, Duration duration) {
    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        duration: duration,
        artUri: track.thumbnailUrl.isNotEmpty
            ? Uri.tryParse(track.thumbnailUrl)
            : null,
      ),
    );
  }

  void broadcastState({
    required bool playing,
    required bool buffering,
    required Duration position,
    required double speed,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.fastForward,
          MediaControl.rewind,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        speed: speed,
      ),
    );
  }
}

class SonicAudioEngine {
  SonicAudioEngine._();
  static final SonicAudioEngine instance = SonicAudioEngine._();

  static const MethodChannel _carPlayChannel =
      MethodChannel('com.soniclane.app/carplay');

  Player? _player;
  VideoController? _videoController;
  SonicAudioHandler? _audioHandler;

  final _stateController = StreamController<PlaybackSnapshot>.broadcast();
  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  final List<MediaTrack> _historyStack = [];

  Timer? _progressSaveTimer;
  Timer? _sleepTimer;
  Timer? _bannerTimer;
  AppSettings _settings = const AppSettings();
  bool _preferredVideoMode = false;
  String? _pendingExternalAudioUri;
  int _pendingExternalAudioGen = 0;
  int _retryAttempts = 0;
  bool _isRecoveringError = false;
  String? _lastResolvedServerUrl;
  final Set<String> _failedServerUrls = {};
  int _openGeneration = 0;

  PlaybackSnapshot get snapshot => _snapshot;
  Stream<PlaybackSnapshot> get stream => _stateController.stream;
  VideoController? get videoController => _videoController;
  bool get preferredVideoMode => _preferredVideoMode;

  bool _initialized = false;

  Future<void> initialize({bool testMode = false}) async {
    if (_initialized) return;
    _initialized = true;

    _settings = await DatabaseService.instance.loadSettings();

    if (testMode) return;

    try {
      MediaKit.ensureInitialized();
      _player = Player(
        configuration: const PlayerConfiguration(
          title: 'Soniclane Cockpit Player',
          logLevel: MPVLogLevel.warn,
        ),
      );
      final arch = Platform.version.toLowerCase();
      final isAndroidX86 = !kIsWeb &&
          Platform.isAndroid &&
          (arch.contains('x86') ||
              arch.contains('x64') ||
              arch.contains('ia32'));
      debugPrint(
          '[AudioEngine] Platform.version=${Platform.version} isAndroidX86=$isAndroidX86');
      _videoController = VideoController(
        _player!,
        configuration: !kIsWeb && Platform.isAndroid
            ? VideoControllerConfiguration(
                enableHardwareAcceleration: !isAndroidX86,
                hwdec: isAndroidX86 ? 'no' : 'mediacodec-copy',
              )
            : const VideoControllerConfiguration(),
      );
      if (_player!.platform is NativePlayer) {
        final native = _player!.platform as NativePlayer;
        await native.setProperty('user-agent', StreamResolver.kStreamUserAgent);
        await native.setProperty('cache-on-disk', 'no');
        await native.setProperty('cache-secs', '8');
        await native.setProperty('demuxer-readahead-secs', '8');
        await native.setProperty('demuxer-max-bytes', '24MiB');
        await native.setProperty('demuxer-max-back-bytes', '8MiB');
        await native.setProperty('network-timeout', '10');
        await native.setProperty(
          'demuxer-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=3',
        );
        if (isAndroidX86) {
          await native.setProperty('gpu-dumb-mode', 'yes');
        }
      }
      _attachPlayerListeners();
    } catch (e) {
      debugPrint('[AudioEngine] Player init note: $e');
    }

    // Initialize OS background AudioService on Android & iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _audioHandler = await AudioService.init(
          builder: () => SonicAudioHandler(this),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.soniclane.app.channel.audio',
            androidNotificationChannelName: 'Soniclane Cockpit Audio',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: true,
          ),
        );
      } catch (e) {
        debugPrint('[AudioEngine] AudioService init note: $e');
      }
    }

    // Bridge Apple CarPlay MethodChannel requests
    if (!kIsWeb && Platform.isIOS) {
      _carPlayChannel.setMethodCallHandler(_handleCarPlayCall);
    }

    // Periodic 5-second progress save for accurate Smart Resume
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final track = _snapshot.currentTrack;
      if (track != null && _snapshot.isPlaying) {
        DatabaseService.instance
            .recordPlayProgress(track, _snapshot.position.inMilliseconds);
      }
    });
  }

  Future<dynamic> _handleCarPlayCall(MethodCall call) async {
    switch (call.method) {
      case 'getTrending':
        final list = await StreamResolver.instance.fetchTrendingMusic();
        return list.map((t) => t.toMap()).toList();
      case 'getLikedTracks':
        final list = await DatabaseService.instance.getLikedTracks();
        return list.map((t) => t.toMap()).toList();
      case 'getPlaylists':
        final pls = await DatabaseService.instance.getPlaylists();
        return pls
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'count': p.items.length,
                })
            .toList();
      case 'getPlaylistTracks':
        final playlistId = call.arguments as String?;
        final pls = await DatabaseService.instance.getPlaylists();
        final matched = pls.where((p) => p.id == playlistId).toList();
        if (matched.isEmpty) return <Map<String, dynamic>>[];
        return matched.first.items.map((t) => t.toMap()).toList();
      case 'playPlaylistTrack':
        final args = call.arguments as Map?;
        final playlistId = args?['playlistId'] as String?;
        final trackId = args?['trackId'] as String?;
        final pls = await DatabaseService.instance.getPlaylists();
        final matched = pls.where((p) => p.id == playlistId).toList();
        if (matched.isNotEmpty) {
          final pl = matched.first;
          final target = pl.items.firstWhere(
            (t) => t.id == trackId,
            orElse: () => pl.items.first,
          );
          await playTrack(
            target,
            queue: pl.items,
            playlistName: pl.name,
            playlistId: pl.id,
          );
        }
        return true;
      case 'playTrackById':
        final id = call.arguments as String?;
        if (id != null) {
          final offline = await DatabaseService.instance.getOfflineTrackById(id);
          if (offline != null) {
            await playTrack(offline);
            return true;
          }
          final bundle = await StreamResolver.instance.resolveTrack(
            id,
            preferredBitrate: _settings.audioBitrate,
            preferredVideoQuality: _settings.videoQuality,
            includeVideo: false,
          );
          if (bundle != null) {
            await playTrack(bundle.track,
                relatedForAutoQueue: bundle.relatedTracks);
          }
        }
        return true;
      default:
        return null;
    }
  }

  void _attachPlayerListeners() {
    final player = _player;
    if (player == null) return;

    player.stream.log.listen((log) {
      debugPrint('[mpv-${log.level}] ${log.prefix}: ${log.text}');
    });

    player.stream.error.listen((err) {
      debugPrint('[mpv-error] $err');
      _handlePlayerError(err);
    });

    player.stream.playing.listen((playing) {
      _emit(_snapshot.copyWith(isPlaying: playing));
      _syncHandlerState();
      if (!playing &&
          !_snapshot.isRepeat &&
          !_isSkipping &&
          _snapshot.duration > const Duration(seconds: 3) &&
          _snapshot.position >=
              _snapshot.duration - const Duration(seconds: 1)) {
        skipToNext();
      }
    });

    player.stream.buffering.listen((buffering) {
      _emit(_snapshot.copyWith(isBuffering: buffering));
      _syncHandlerState();
    });

    player.stream.position.listen((pos) {
      _emit(_snapshot.copyWith(position: pos));
    });

    player.stream.duration.listen((dur) {
      if (dur > Duration.zero) {
        _emit(_snapshot.copyWith(duration: dur));
        _attachPendingExternalAudioIfReady();
      }
    });

    player.stream.tracks.listen((tracks) {
      if (tracks.video.any((v) => v.id != 'auto' && v.id != 'no')) {
        _attachPendingExternalAudioIfReady();
      }
    });

    player.stream.width.listen((w) {
      if ((w ?? 0) > 0) {
        _attachPendingExternalAudioIfReady();
      }
    });

    player.stream.completed.listen((completed) {
      if (completed) {
        if (_snapshot.isRepeat) {
          seekTo(Duration.zero).then((_) => play());
        } else {
          skipToNext();
        }
      }
    });
  }

  Future<void> _attachPendingExternalAudioIfReady() async {
    final uri = _pendingExternalAudioUri;
    final targetGen = _pendingExternalAudioGen;
    final player = _player;
    if (uri == null || player == null || targetGen != _openGeneration) return;
    _pendingExternalAudioUri = null;
    try {
      await player.setAudioTrack(
        AudioTrack.uri(uri, title: 'External Audio', language: 'auto'),
      );
    } catch (e) {
      debugPrint('[AudioEngine] External audio attach note: $e');
    }
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  static const String kTempNowPlayingPlaylistName = 'Nowplaying';

  Future<void> playTrack(
    MediaTrack track, {
    List<MediaTrack>? queue,
    String? playlistName,
    String? playlistId,
    bool? isTempPlaylist,
    List<MediaTrack>? relatedForAutoQueue,
    Duration? resumeAt,
    bool? keepVideoMode,
  }) async {
    final targetVideoMode = keepVideoMode ?? _preferredVideoMode;
    if (targetVideoMode) {
      await _enableWakeLock();
    } else {
      await _disableWakeLock();
    }

    final gen = ++_openGeneration;
    _retryAttempts = 0;
    _isRecoveringError = false;
    _failedServerUrls.clear();
    _pendingExternalAudioUri = null;
    _lastResolvedServerUrl = null;

    if (_snapshot.currentTrack != null &&
        _snapshot.currentTrack!.id != track.id) {
      _historyStack.add(_snapshot.currentTrack!);
    }

    final isTempSession = isTempPlaylist ??
        (playlistId == null && playlistName == kTempNowPlayingPlaylistName);
    final initialQueue = queue ?? [track];
    final idx = initialQueue.indexWhere((t) => t.id == track.id);

    final liked = await DatabaseService.instance.isTrackLiked(track.id);
    _emit(
      _snapshot.copyWith(
        currentTrack: track,
        queue: initialQueue,
        currentIndex: idx >= 0 ? idx : 0,
        isBuffering: true,
        isLiked: liked,
        isVideoMode: targetVideoMode,
        activePlaylistName: isTempSession
            ? kTempNowPlayingPlaylistName
            : (playlistName ?? 'Auto-Flow Cybermix'),
        activePlaylistId: isTempSession ? null : playlistId,
        clearActivePlaylistId: isTempSession || playlistId == null,
        isTempPlaylist: isTempSession,
        duration: Duration(seconds: track.durationSeconds),
        position: resumeAt ?? Duration.zero,
        clearBanner: true,
      ),
    );

    MediaTrack playableTrack = track;
    String tierLabel = track.source == TrackSource.customStream
        ? 'Remote Stream'
        : track.qualityBadge;

    // Prefer locally downloaded offline cache for zero-data local playback
    if (!targetVideoMode) {
      final offlineCached =
          await DatabaseService.instance.getOfflineTrackById(track.id);
      if (offlineCached != null &&
          offlineCached.localPath != null &&
          File(offlineCached.localPath!).existsSync()) {
        playableTrack = offlineCached.copyWith(
          lastPositionMs: track.lastPositionMs,
          playCount: track.playCount,
        );
        tierLabel = 'Offline Cached';
      }
    }

    // Resolve stream URLs for online remote items or direct media URLs
    if (playableTrack.source == TrackSource.customStream) {
      final isDirectMediaId =
          UrlParser.parse(track.id)?.type == MediaUrlType.directMedia;
      final hasDirectStream = isDirectMediaId &&
          playableTrack.streamUrl != null &&
          playableTrack.streamUrl!.startsWith('http');
      if (hasDirectStream) {
        tierLabel = 'Direct Media URL';
      } else {
        final lookupId = playableTrack.streamUrl != null &&
                playableTrack.streamUrl!.startsWith('http') &&
                playableTrack.id == playableTrack.streamUrl
            ? playableTrack.streamUrl!
            : track.id;
        final sw = Stopwatch()..start();
        final bundle = await StreamResolver.instance.resolveTrack(
          lookupId,
          preferredBitrate: _settings.audioBitrate,
          preferredVideoQuality: _settings.videoQuality,
          includeVideo: targetVideoMode,
        );
        sw.stop();
        debugPrint(
          '[AudioEngine] resolveTrack($lookupId, video=$targetVideoMode) -> '
          '${bundle?.resolvedByTier ?? "null"} in ${sw.elapsedMilliseconds}ms',
        );
        if (gen != _openGeneration) return;

        if (bundle != null) {
          _lastResolvedServerUrl = bundle.serverUrl;
          playableTrack = bundle.track.copyWith(
            lastPositionMs: track.lastPositionMs,
            playCount: track.playCount,
          );
          tierLabel = bundle.resolvedByTier;

          // Populate Dynamic Auto-Queue (for Steering wheel Next even without a playlist!)
          if (queue == null &&
              !_snapshot.isTempPlaylist &&
              bundle.relatedTracks.isNotEmpty) {
            final merged = [playableTrack, ...bundle.relatedTracks];
            _emit(
              _snapshot.copyWith(
                queue: merged,
                habitSuggestions: bundle.relatedTracks.take(4).toList(),
              ),
            );
          } else if (relatedForAutoQueue != null) {
            _emit(_snapshot.copyWith(habitSuggestions: relatedForAutoQueue));
          }
        } else {
          // If inside a queue/playlist and there are more tracks, auto-skip broken items
          if (queue != null && _snapshot.currentIndex < queue.length - 1) {
            debugPrint(
                '[AudioEngine] Track ${track.id} resolution failed; auto-skipping to next in queue...');
            _emit(_snapshot.copyWith(
              isBuffering: true,
              statusBanner: 'Skipping unavailable track...',
            ));
            await skipToNext();
            return;
          }
          // Fallback when offline: Smart-Skip to next offline track if inside hybrid playlist
          if (queue != null && queue.any((t) => t.source.isOfflineCapable)) {
            _emit(_snapshot.copyWith(
              isBuffering: false,
              statusBanner: 'Offline mode: Smart-skipping to local track...',
            ));
            await _skipToNextOfflineInQueue();
            return;
          }
          _emit(_snapshot.copyWith(
            isBuffering: false,
            isPlaying: false,
            statusBanner:
                'Stream unavailable. Configure Custom Server in Settings or play offline files.',
          ));
          return;
        }
      }
    } else if (relatedForAutoQueue != null) {
      _emit(_snapshot.copyWith(habitSuggestions: relatedForAutoQueue));
    }

    await DatabaseService.instance.incrementPlayCount(playableTrack);

    final effectiveVideoMode = _snapshot.isVideoMode &&
        !(playableTrack.source == TrackSource.customStream &&
            (playableTrack.videoStreamUrl == null ||
                playableTrack.videoStreamUrl!.isEmpty));
    _emit(
      _snapshot.copyWith(
        currentTrack: playableTrack,
        activeTierLabel: tierLabel,
        isVideoMode: effectiveVideoMode,
        isBuffering: _player != null,
        statusBanner: (_snapshot.isVideoMode && !effectiveVideoMode)
            ? 'Video stream unavailable for this track; playing audio.'
            : null,
      ),
    );

    _audioHandler?.broadcastTrack(
      playableTrack,
      Duration(seconds: playableTrack.durationSeconds),
    );

    await _openPlayerMedia(
      playableTrack,
      effectiveVideoMode,
      seekToPos: resumeAt,
      autoPlay: true,
      gen: gen,
    );
  }

  Future<void> _handlePlayerError(String err) async {
    final track = _snapshot.currentTrack;
    if (track == null || track.source != TrackSource.customStream) return;

    final lower = err.toLowerCase();
    if (lower.contains('file cache')) return;
    final isFatalOpen = lower.contains('failed to open') ||
        lower.contains('failed to recognize') ||
        lower.contains('protocol not found') ||
        lower.contains('server returned') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('404') ||
        lower.contains('410');
    if (!isFatalOpen || _isRecoveringError) return;

    final gen = _openGeneration;
    if (_retryAttempts < 2 && StreamResolver.instance.hasCustomServer) {
      _isRecoveringError = true;
      final attempt = _retryAttempts++;
      if (attempt > 0 && _lastResolvedServerUrl != null) {
        _failedServerUrls.add(_lastResolvedServerUrl!);
      }
      try {
        StreamResolver.instance.invalidateTrackCache(track.id);
        final retryBundle = await StreamResolver.instance.resolveTrack(
          track.id,
          preferredBitrate: _settings.audioBitrate,
          preferredVideoQuality: _settings.videoQuality,
          forceProxy: attempt == 0,
          includeVideo: _snapshot.isVideoMode,
          excludeServerUrls:
              _failedServerUrls.isNotEmpty ? Set.of(_failedServerUrls) : null,
        );
        if (gen != _openGeneration) return;
        if (retryBundle != null && _snapshot.currentTrack?.id == track.id) {
          _lastResolvedServerUrl = retryBundle.serverUrl;
          final refreshed = retryBundle.track.copyWith(
            lastPositionMs: track.lastPositionMs,
            playCount: track.playCount,
          );
          final useVideo = _snapshot.isVideoMode &&
              refreshed.videoStreamUrl != null &&
              refreshed.videoStreamUrl!.isNotEmpty;
          _emit(_snapshot.copyWith(
            currentTrack: refreshed,
            activeTierLabel: retryBundle.resolvedByTier,
            isVideoMode: useVideo,
            isBuffering: true,
          ));
          await _openPlayerMedia(
            refreshed,
            useVideo,
            seekToPos: _snapshot.position,
            autoPlay: true,
            gen: gen,
          );
          return;
        }
      } finally {
        _isRecoveringError = false;
      }
    }

    // If Video Mode failed while audio stream is available, fall back smoothly to Audio
    if (_snapshot.isVideoMode &&
        track.streamUrl != null &&
        track.streamUrl!.isNotEmpty &&
        track.streamUrl != track.videoStreamUrl) {
      _emit(_snapshot.copyWith(
        isVideoMode: false,
        isBuffering: true,
        statusBanner: 'Video stream failed; switched back to audio.',
      ));
      await _openPlayerMedia(
        track,
        false,
        seekToPos: _snapshot.position,
        autoPlay: true,
        gen: ++_openGeneration,
      );
      return;
    }

    _emit(_snapshot.copyWith(
      isBuffering: false,
      isPlaying: false,
      statusBanner:
          'Unable to load stream from current server. Try another server in Settings.',
    ));
  }

  Future<void> _openPlayerMedia(
    MediaTrack track,
    bool videoMode, {
    Duration? seekToPos,
    required bool autoPlay,
    int? gen,
  }) async {
    final targetGen = gen ?? _openGeneration;
    final targetUri = videoMode
        ? (track.videoStreamUrl ?? track.playbackUri)
        : track.playbackUri;
    if (_player == null || targetUri.isEmpty) return;

    try {
      final externalAudio = (videoMode &&
              !track.videoHasAudio &&
              track.streamUrl != null &&
              track.streamUrl!.isNotEmpty &&
              targetUri != track.streamUrl)
          ? track.streamUrl!
          : '';
      if (externalAudio.isNotEmpty) {
        _pendingExternalAudioUri = externalAudio;
        _pendingExternalAudioGen = targetGen;
      } else {
        _pendingExternalAudioUri = null;
      }

      final isHttp =
          targetUri.startsWith('http://') || targetUri.startsWith('https://');
      final startAt =
          (seekToPos != null && seekToPos > Duration.zero) ? seekToPos : null;
      final openSw = Stopwatch()..start();
      await _player!.open(
        Media(
          targetUri,
          start: startAt,
          httpHeaders: isHttp
              ? const {'User-Agent': StreamResolver.kStreamUserAgent}
              : null,
        ),
        play: autoPlay,
      );
      openSw.stop();
      debugPrint(
        '[AudioEngine] _openPlayerMedia(video=$videoMode, extAudio=${externalAudio.isNotEmpty}) '
        'open finished in ${openSw.elapsedMilliseconds}ms',
      );
      await _player!.setRate(_snapshot.eqSettings.playbackSpeed);
      if (autoPlay) {
        await _player!.play();
      }
      if (_pendingExternalAudioUri != null &&
          _player!.state.duration > Duration.zero) {
        await _attachPendingExternalAudioIfReady();
      }
    } catch (e) {
      debugPrint('[AudioEngine] Open media failed: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_snapshot.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    await _player?.play();
    _emit(_snapshot.copyWith(isPlaying: true));
    _syncHandlerState();
  }

  Future<void> pause() async {
    await _player?.pause();
    _emit(_snapshot.copyWith(isPlaying: false));
    if (_snapshot.currentTrack != null) {
      await DatabaseService.instance.recordPlayProgress(
        _snapshot.currentTrack!,
        _snapshot.position.inMilliseconds,
      );
    }
    _syncHandlerState();
  }

  Future<void> stop() async {
    await _player?.stop();
    await _disableWakeLock();
    _emit(_snapshot.copyWith(isPlaying: false, isVideoMode: false));
    _syncHandlerState();
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
    _emit(_snapshot.copyWith(position: position));
    _syncHandlerState();
  }

  Future<void> seekRelative(Duration delta) async {
    final next = _snapshot.position + delta;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (_snapshot.duration > Duration.zero && next > _snapshot.duration
            ? _snapshot.duration
            : next);
    await seekTo(clamped);
  }

  bool _isSkipping = false;

  /// Steering wheel Next button handler (works with playlists OR Dynamic Auto-Queue)
  Future<void> skipToNext() async {
    if (_isSkipping) return;
    _isSkipping = true;
    try {
      final q = _snapshot.queue;
      if (q.isEmpty) return;

      int nextIdx;
      if (_snapshot.isShuffle && q.length > 1) {
        nextIdx = (_snapshot.currentIndex + 2) % q.length;
      } else {
        nextIdx = _snapshot.currentIndex + 1;
      }

      if (nextIdx >= q.length) {
        // Auto-Flow: pull habit recommendations only outside explicit temp playlists
        if (!_snapshot.isTempPlaylist &&
            _settings.autoFlowHabits &&
            _snapshot.habitSuggestions.isNotEmpty) {
          final nextTrack = _snapshot.habitSuggestions.first;
          await playTrack(nextTrack, queue: [...q, ..._snapshot.habitSuggestions]);
        }
        return;
      }

      final candidate = q[nextIdx];
      if (!candidate.isAvailable) {
        _emit(_snapshot.copyWith(currentIndex: nextIdx));
        await skipToNext();
        return;
      }

      await playTrack(
        candidate,
        queue: q,
        playlistName: _snapshot.activePlaylistName,
        playlistId: _snapshot.activePlaylistId,
        isTempPlaylist: _snapshot.isTempPlaylist,
        keepVideoMode: _snapshot.isVideoMode,
      );
    } finally {
      _isSkipping = false;
    }
  }

  Future<void> _skipToNextOfflineInQueue() async {
    final q = _snapshot.queue;
    for (int i = _snapshot.currentIndex + 1; i < q.length; i++) {
      if (q[i].source.isOfflineCapable && q[i].isAvailable) {
        await playTrack(
          q[i],
          queue: q,
          playlistName: _snapshot.activePlaylistName,
          playlistId: _snapshot.activePlaylistId,
          isTempPlaylist: _snapshot.isTempPlaylist,
        );
        return;
      }
    }
  }

  /// Steering wheel Previous rule:
  /// If current playback > 3 seconds -> Restart current track.
  /// If <= 3 seconds -> Pop previous track from session history.
  Future<void> skipToPrevious() async {
    if (_snapshot.position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (_historyStack.isNotEmpty) {
      final prev = _historyStack.removeLast();
      await playTrack(
        prev,
        queue: _snapshot.queue,
        playlistName: _snapshot.activePlaylistName,
        playlistId: _snapshot.activePlaylistId,
        isTempPlaylist: _snapshot.isTempPlaylist,
        keepVideoMode: _snapshot.isVideoMode,
      );
    } else if (_snapshot.currentIndex > 0) {
      final prev = _snapshot.queue[_snapshot.currentIndex - 1];
      await playTrack(
        prev,
        queue: _snapshot.queue,
        playlistName: _snapshot.activePlaylistName,
        playlistId: _snapshot.activePlaylistId,
        isTempPlaylist: _snapshot.isTempPlaylist,
        keepVideoMode: _snapshot.isVideoMode,
      );
    }
  }

  /// Appends [track] to the temporary sequential "Nowplaying" playlist (FIFO).
  Future<({bool added, int totalCount, bool startedNow})>
      addToNowPlayingPlaylist(MediaTrack track) async {
    final cur = _snapshot.currentTrack;
    if (cur == null || _snapshot.queue.isEmpty) {
      _emit(_snapshot.copyWith(isShuffle: false));
      await playTrack(
        track,
        queue: [track],
        playlistName: kTempNowPlayingPlaylistName,
        isTempPlaylist: true,
      );
      return (added: true, totalCount: 1, startedNow: true);
    }

    final baseQueue = _snapshot.isTempPlaylist
        ? List<MediaTrack>.from(_snapshot.queue)
        : <MediaTrack>[cur];
    final safeIdx = _snapshot.isTempPlaylist
        ? (_snapshot.currentIndex >= 0 &&
                _snapshot.currentIndex < baseQueue.length
            ? _snapshot.currentIndex
            : 0)
        : 0;

    final alreadyQueued = baseQueue.any((t) => t.id == track.id);
    if (alreadyQueued) {
      if (!_snapshot.isTempPlaylist) {
        _emit(
          _snapshot.copyWith(
            queue: baseQueue,
            currentIndex: safeIdx,
            activePlaylistName: kTempNowPlayingPlaylistName,
            clearActivePlaylistId: true,
            isTempPlaylist: true,
            isShuffle: false,
          ),
        );
      }
      return (added: false, totalCount: baseQueue.length, startedNow: false);
    }

    baseQueue.add(track);
    _emit(
      _snapshot.copyWith(
        queue: baseQueue,
        currentIndex: safeIdx,
        activePlaylistName: kTempNowPlayingPlaylistName,
        clearActivePlaylistId: true,
        isTempPlaylist: true,
        isShuffle: false,
      ),
    );
    _syncHandlerState();
    return (added: true, totalCount: baseQueue.length, startedNow: false);
  }

  /// Keeps the active queue in sync when adding a track to the currently playing playlist.
  void appendTrackIfActivePlaylist(
      String playlistId, String playlistName, MediaTrack track) {
    if (_snapshot.isTempPlaylist) return;
    final matchesActive = _snapshot.activePlaylistId == playlistId ||
        (_snapshot.activePlaylistId == null &&
            _snapshot.activePlaylistName == playlistName);
    if (!matchesActive) return;
    if (_snapshot.queue.any((t) => t.id == track.id)) return;
    final updated = List<MediaTrack>.from(_snapshot.queue)..add(track);
    _emit(_snapshot.copyWith(queue: updated));
  }

  bool _isStreamUrlExpiringSoon(String? url) {
    if (url == null || url.isEmpty) return true;
    final expRaw = Uri.tryParse(url)?.queryParameters['expire'];
    final expSec = expRaw != null ? int.tryParse(expRaw) : null;
    if (expSec == null) return false;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expSec <= nowSec + 90;
  }

  /// Switch smoothly between Audio-only (128k) and Video (720p/1080p) at exact millisecond position.
  Future<void> setVideoMode(bool enableVideo) async {
    _preferredVideoMode = enableVideo;
    if (enableVideo) {
      await _enableWakeLock();
    } else {
      await _disableWakeLock();
    }

    final gen = ++_openGeneration;
    _retryAttempts = 0;
    _isRecoveringError = false;
    _failedServerUrls.clear();
    _pendingExternalAudioUri = null;

    var track = _snapshot.currentTrack;
    _emit(_snapshot.copyWith(
      isVideoMode: enableVideo,
      isBuffering: _player != null && track != null,
    ));
    if (track == null) return;

    final needResolveVideo = enableVideo &&
        track.source == TrackSource.customStream &&
        StreamResolver.instance.hasCustomServer &&
        (track.videoStreamUrl == null ||
            track.videoStreamUrl!.isEmpty ||
            _isStreamUrlExpiringSoon(track.videoStreamUrl));
    if (needResolveVideo) {
      final sw = Stopwatch()..start();
      final bundle = await StreamResolver.instance.resolveTrack(
        track.id,
        preferredBitrate: _settings.audioBitrate,
        preferredVideoQuality: _settings.videoQuality,
        includeVideo: true,
      );
      sw.stop();
      debugPrint(
        '[AudioEngine] setVideoMode(true) resolve(${track.id}) -> '
        '${bundle?.resolvedByTier ?? "null"} in ${sw.elapsedMilliseconds}ms',
      );
      if (gen != _openGeneration) return;
      if (bundle != null) {
        _lastResolvedServerUrl = bundle.serverUrl;
        final resolvedVideo = (bundle.track.videoStreamUrl != null &&
                bundle.track.videoStreamUrl!.isNotEmpty)
            ? bundle.track.videoStreamUrl
            : (bundle.track.streamUrl != null &&
                    (bundle.track.streamUrl!.contains('.mp4') ||
                        bundle.track.streamUrl!.contains('video/')))
                ? bundle.track.streamUrl
                : null;
        track = bundle.track.copyWith(
          videoStreamUrl: resolvedVideo ?? bundle.track.videoStreamUrl,
          lastPositionMs: track.lastPositionMs,
          playCount: track.playCount,
        );
        _emit(_snapshot.copyWith(
          currentTrack: track,
          activeTierLabel: bundle.resolvedByTier,
        ));
      }
    }

    if (enableVideo &&
        track.source == TrackSource.customStream &&
        (track.videoStreamUrl == null || track.videoStreamUrl!.isEmpty)) {
      await _disableWakeLock();
      _emit(_snapshot.copyWith(
        isVideoMode: false,
        statusBanner: 'Video stream unavailable for this track on current server.',
      ));
      return;
    }

    await _openPlayerMedia(
      track,
      enableVideo,
      seekToPos: _snapshot.position,
      autoPlay: enableVideo ? true : _snapshot.isPlaying,
      gen: gen,
    );
  }

  Future<void> toggleShuffle() async {
    _emit(_snapshot.copyWith(isShuffle: !_snapshot.isShuffle));
  }

  Future<void> toggleRepeat() async {
    _emit(_snapshot.copyWith(isRepeat: !_snapshot.isRepeat));
  }

  Future<void> toggleLikeCurrent() async {
    final track = _snapshot.currentTrack;
    if (track == null) return;
    final liked = await DatabaseService.instance.toggleLikeTrack(track);
    _emit(_snapshot.copyWith(isLiked: liked));
  }

  void addToQueue(MediaTrack track) {
    final updated = [..._snapshot.queue, track];
    _emit(_snapshot.copyWith(queue: updated));
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final q = List<MediaTrack>.from(_snapshot.queue);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = q.removeAt(oldIndex);
    q.insert(newIndex, item);
    final newCurrent = _snapshot.currentTrack != null
        ? q.indexWhere((t) => t.id == _snapshot.currentTrack!.id)
        : _snapshot.currentIndex;
    _emit(_snapshot.copyWith(
      queue: q,
      currentIndex: newCurrent >= 0 ? newCurrent : 0,
    ));
  }

  Future<void> updateEqSettings(EqSettings eq) async {
    _emit(_snapshot.copyWith(eqSettings: eq));
    await _player?.setRate(eq.playbackSpeed);
    await _applyMpvAudioFilters(eq);
  }

  Future<void> _applyMpvAudioFilters(EqSettings eq) async {
    final platform = _player?.platform;
    if (platform is NativePlayer) {
      const freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final filters = <String>[];
      for (int i = 0; i < freqs.length && i < eq.bands.length; i++) {
        final gain = eq.bands[i];
        if (gain.abs() >= 0.2) {
          filters.add(
              'equalizer=f=${freqs[i]}:t=q:w=1.4:g=${gain.toStringAsFixed(1)}');
        }
      }
      if (eq.volumeNormalization) {
        filters.add('dynaudnorm=f=150:g=15');
      }
      try {
        await platform.setProperty('af', filters.join(','));
      } catch (e) {
        debugPrint('[AudioEngine] EQ filter note: $e');
      }
    }
  }

  void setSleepTimerMinutes(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null || minutes <= 0) {
      _emit(_snapshot.copyWith(clearSleepTimer: true));
      return;
    }
    int remaining = minutes * 60;
    _emit(_snapshot.copyWith(sleepTimerRemainingSec: remaining));
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        pause();
        _emit(_snapshot.copyWith(clearSleepTimer: true));
      } else {
        _emit(_snapshot.copyWith(sleepTimerRemainingSec: remaining));
      }
    });
  }

  Future<void> _enableWakeLock() async {
    if (kIsWeb) return;
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    if (kIsWeb) return;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  void _syncHandlerState() {
    _audioHandler?.broadcastState(
      playing: _snapshot.isPlaying,
      buffering: _snapshot.isBuffering,
      position: _snapshot.position,
      speed: _snapshot.eqSettings.playbackSpeed,
    );
  }

  void clearStatusBanner() {
    _bannerTimer?.cancel();
    if (_snapshot.statusBanner != null) {
      _emit(_snapshot.copyWith(clearBanner: true));
    }
  }

  void _emit(PlaybackSnapshot next) {
    final prevBanner = _snapshot.statusBanner;
    _snapshot = next;
    if (next.statusBanner != null && next.statusBanner != prevBanner) {
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 4), clearStatusBanner);
    }
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void dispose() {
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _bannerTimer?.cancel();
    _player?.dispose();
    _stateController.close();
  }
}
