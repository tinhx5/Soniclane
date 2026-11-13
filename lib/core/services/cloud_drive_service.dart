import 'package:dio/dio.dart';
import '../models/media_models.dart';

/// Parses and fetches personal Google Drive / Cloud audio files & public Drive folders.
/// Supports direct Drive share URLs (`drive.google.com/file/d/<ID>/...`)
/// and optional Drive API v3 public folder listing when user provides an API Key + Folder ID.
class CloudDriveService {
  CloudDriveService._();
  static final CloudDriveService instance = CloudDriveService._();

  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 8)),
  );

  static final RegExp _driveFileRegex = RegExp(
    r'drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  static final RegExp _driveOpenIdRegex = RegExp(
    r'drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  static final RegExp _driveFolderRegex = RegExp(
    r'drive\.google\.com\/drive\/(?:u\/\d+\/)?folders\/([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  String? extractFileId(String url) {
    return _driveFileRegex.firstMatch(url)?.group(1) ??
        _driveOpenIdRegex.firstMatch(url)?.group(1);
  }

  String? extractFolderId(String url) {
    return _driveFolderRegex.firstMatch(url)?.group(1);
  }

  String buildDirectStreamUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  MediaTrack buildTrackFromShareUrl({
    required String shareUrl,
    String customTitle = 'Google Drive Audio Track',
  }) {
    final fileId = extractFileId(shareUrl);
    final streamUrl = fileId != null ? buildDirectStreamUrl(fileId) : shareUrl;
    return MediaTrack(
      id: 'gdrive_${fileId ?? shareUrl.hashCode.abs()}',
      title: customTitle,
      artist: 'Google Drive Personal',
      thumbnailUrl: '',
      durationSeconds: 240,
      source: TrackSource.googleDrive,
      streamUrl: streamUrl,
      qualityBadge: 'Drive Stream',
    );
  }

  /// List audio files from a Google Drive folder using a user-supplied Drive API Key (optional).
  Future<List<MediaTrack>> listFolderTracks({
    required String folderUrlOrId,
    required String apiKey,
  }) async {
    final folderId = extractFolderId(folderUrlOrId) ?? folderUrlOrId.trim();
    if (folderId.isEmpty || apiKey.trim().isEmpty) return [];

    try {
      final q = Uri.encodeQueryComponent(
          "'$folderId' in parents and trashed = false and mimeType contains 'audio/'");
      final url =
          'https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id,name,mimeType,size)&key=${apiKey.trim()}';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data is Map) {
        final files = (res.data['files'] as List?) ?? [];
        return files.map((f) {
          final id = f['id'] as String? ?? '';
          final name = f['name'] as String? ?? 'Drive Track';
          final cleanName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
          return MediaTrack(
            id: 'gdrive_$id',
            title: cleanName,
            artist: 'Google Drive',
            thumbnailUrl: '',
            durationSeconds: 240,
            source: TrackSource.googleDrive,
            streamUrl: buildDirectStreamUrl(id),
            qualityBadge: 'Cloud FLAC/MP3',
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
