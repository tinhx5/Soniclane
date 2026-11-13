import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/media_models.dart';
import 'database_service.dart';
import 'storage_scanner.dart';
import 'stream_resolver.dart';

class DownloadStatus {
  final Map<String, double> progressByTrackId;
  final Set<String> activeIds;

  const DownloadStatus({
    this.progressByTrackId = const {},
    this.activeIds = const {},
  });

  bool get isDownloading => activeIds.isNotEmpty;

  DownloadStatus copyWith({
    Map<String, double>? progressByTrackId,
    Set<String>? activeIds,
  }) {
    return DownloadStatus(
      progressByTrackId: progressByTrackId ?? this.progressByTrackId,
      activeIds: activeIds ?? this.activeIds,
    );
  }
}

/// Downloads user's personal cloud audio files into `SoniclaneMusic/OfflineCache/`
/// and persists records in SQLite for zero-data offline playback.
/// Remote streams (`TrackSource.customStream`) store metadata only and are never downloaded.
class OfflineDownloadService {
  OfflineDownloadService._();
  static final OfflineDownloadService instance = OfflineDownloadService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  final _statusController = StreamController<DownloadStatus>.broadcast();
  DownloadStatus _status = const DownloadStatus();

  DownloadStatus get currentStatus => _status;
  Stream<DownloadStatus> get statusStream => _statusController.stream;

  Future<Directory> _getOfflineDir() async {
    final base = await StorageScanner.instance.getInternalDropDirectory();
    final cacheDir = Directory(p.join(base.path, 'OfflineCache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<bool> downloadTrack(MediaTrack track, {String? customDirectUrl}) async {
    if (track.source.isOfflineCapable &&
        track.localPath != null &&
        File(track.localPath!).existsSync()) {
      return true;
    }

    final existing = await DatabaseService.instance.getOfflineTrackById(track.id);
    if (existing != null &&
        existing.localPath != null &&
        File(existing.localPath!).existsSync()) {
      return true;
    }

    _updateTrackProgress(track.id, 0.04, active: true);

    try {
      String? urlToDownload = customDirectUrl ?? track.streamUrl;

      // If streamUrl is not direct or empty, resolve it via StreamResolver
      if (urlToDownload == null ||
          urlToDownload.isEmpty ||
          !urlToDownload.startsWith('http')) {
        final bundle = await StreamResolver.instance.resolveTrack(track.id);
        urlToDownload = bundle?.track.streamUrl;
      }

      if (urlToDownload == null || urlToDownload.isEmpty) {
        _updateTrackProgress(track.id, 0, active: false);
        return false;
      }

      final dir = await _getOfflineDir();
      final outPath = p.join(dir.path, '${track.id}.m4a');

      await _dio.download(
        urlToDownload,
        outPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _updateTrackProgress(track.id, received / total, active: true);
          }
        },
      );

      await DatabaseService.instance.saveOfflineTrack(
        track.copyWith(
          source: TrackSource.local,
          localPath: outPath,
          qualityBadge: 'Offline Cached',
        ),
        outPath,
      );

      _updateTrackProgress(track.id, 1.0, active: false);
      return true;
    } catch (_) {
      _updateTrackProgress(track.id, 0, active: false);
      return false;
    }
  }

  Future<int> downloadPlaylist(HybridPlaylist playlist) async {
    int downloaded = 0;
    for (final item in playlist.items) {
      final ok = await downloadTrack(item);
      if (ok) downloaded++;
    }
    return downloaded;
  }

  void _updateTrackProgress(String trackId, double progress,
      {required bool active}) {
    final map = Map<String, double>.from(_status.progressByTrackId);
    final actives = Set<String>.from(_status.activeIds);

    if (active) {
      map[trackId] = progress.clamp(0.0, 1.0);
      actives.add(trackId);
    } else {
      map.remove(trackId);
      actives.remove(trackId);
    }

    _status = _status.copyWith(progressByTrackId: map, activeIds: actives);
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }
}
