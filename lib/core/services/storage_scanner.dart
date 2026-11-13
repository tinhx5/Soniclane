import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_models.dart';

/// Scans local storage, Windows external drives, or Android/iOS folders for audio files.
/// Automatically filters out Dashcam / DVR video folders (`DCIM`, `DVR`, `Dashcam`).
class StorageScanner {
  StorageScanner._();
  static final StorageScanner instance = StorageScanner._();

  static const Set<String> audioExtensions = {
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
  };

  static const Set<String> videoExtensions = {
    'mp4',
    'ts',
    'mov',
    'mkv',
    'm4v',
  };

  static final Set<String> mediaExtensions = {
    ...audioExtensions,
    ...videoExtensions,
  };

  static bool isVideoPath(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return false;
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    return videoExtensions.contains(ext);
  }

  static bool isSupportedMediaPath(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return false;
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    return mediaExtensions.contains(ext);
  }

  /// Builds a normalized local/USB MediaTrack for both audio files and dashcam/local videos.
  static MediaTrack buildLocalMediaTrack(
    String filePath, {
    required TrackSource source,
    String idPrefix = 'local_',
    String? artistOverride,
  }) {
    final extLower = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    final extUpper = (extLower.isEmpty ? 'mp3' : extLower).toUpperCase();
    final isVideo = videoExtensions.contains(extLower);
    final fileUri = filePath.startsWith('file://') ? filePath : 'file://$filePath';
    final parentFolder = p.basename(p.dirname(filePath));
    final badge = isVideo
        ? '$extUpper Video'
        : ((extLower == 'flac' || extLower == 'wav')
            ? (idPrefix == 'local_' ? '$extUpper 24-bit' : '$extUpper Master')
            : extUpper);
    return MediaTrack(
      id: '$idPrefix${filePath.hashCode.abs()}',
      title: p.basenameWithoutExtension(filePath),
      artist: artistOverride ??
          (isVideo
              ? (parentFolder.isNotEmpty ? parentFolder : 'Dashcam / Local Video')
              : (parentFolder.isNotEmpty ? parentFolder : 'Local Audio')),
      thumbnailUrl: '',
      durationSeconds: isVideo ? 0 : 240,
      source: source,
      localPath: filePath,
      videoStreamUrl: isVideo ? fileUri : null,
      videoHasAudio: isVideo,
      qualityBadge: badge,
      recommendationTag: source == TrackSource.usb
          ? 'LOCAL USB $extUpper'
          : (isVideo ? 'LOCAL VIDEO' : null),
    );
  }

  static const Set<String> ignoredDashcamFolders = {
    'dcim',
    'dvr',
    'dashcam',
    'camera_record',
    'movie',
    'system volume information',
    r'$recycle.bin',
  };

  static String? testDropDirectoryPath;

  Future<Directory> getInternalDropDirectory() async {
    if (testDropDirectoryPath != null) {
      final dir = Directory(testDropDirectoryPath!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final musicDir = Directory(p.join(docDir.path, 'SoniclaneMusic'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }
    return musicDir;
  }

  /// Scan user's internal Soniclane Wi-Fi Drop folder (audio + dropped videos) + Music folders (audio only).
  Future<List<MediaTrack>> scanInternalDeviceMusic() async {
    final List<MediaTrack> found = [];
    final dropDir = await getInternalDropDirectory();
    found.addAll(await scanDirectory(
      dropDir,
      source: TrackSource.local,
      includeVideos: true,
    ));

    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        final winMusic = Directory(p.join(home, 'Music'));
        if (await winMusic.exists()) {
          found.addAll(await scanDirectory(winMusic, source: TrackSource.local));
        }
      }
    } else if (Platform.isAndroid) {
      final androidMusic = Directory('/storage/emulated/0/Music');
      if (await androidMusic.exists()) {
        found.addAll(await scanDirectory(androidMusic, source: TrackSource.local));
      }
    }
    return _deduplicateByPath(found);
  }

  /// Detect mounted USB / external storage paths (Windows drive letters E..Z or Android /storage/).
  Future<List<StorageDeviceInfo>> detectHardwareDrives() async {
    final List<StorageDeviceInfo> devices = [];

    if (Platform.isWindows) {
      for (final code in ['E', 'F', 'G', 'H', 'I', 'J']) {
        final drive = Directory('$code:\\');
        if (await drive.exists()) {
          final tracks = await scanDirectory(drive, source: TrackSource.usb, maxDepth: 4);
          devices.add(
            StorageDeviceInfo(
              id: 'win_drive_$code',
              name: 'USB / Drive ($code:)',
              subtitle: 'External Hardware Storage',
              source: TrackSource.usb,
              isMounted: true,
              trackCount: tracks.length,
              usedGb: 24.5,
              totalGb: 64.0,
              rootPath: drive.path,
            ),
          );
        }
      }
    } else if (Platform.isAndroid) {
      final storageRoot = Directory('/storage');
      if (await storageRoot.exists()) {
        try {
          for (final entry in storageRoot.listSync(followLinks: false)) {
            if (entry is Directory) {
              final name = p.basename(entry.path);
              if (name != 'emulated' && name != 'self') {
                final tracks = await scanDirectory(entry, source: TrackSource.usb, maxDepth: 4);
                devices.add(
                  StorageDeviceInfo(
                    id: 'usb_$name',
                    name: 'In-Car USB ($name)',
                    subtitle: 'External OTG / SD Card',
                    source: TrackSource.usb,
                    isMounted: true,
                    trackCount: tracks.length,
                    usedGb: 18.2,
                    totalGb: 64.0,
                    rootPath: entry.path,
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }
    }

    return devices;
  }

  /// Recursively scan a folder for audio files (and optionally dashcam/local videos).
  Future<List<MediaTrack>> scanDirectory(
    Directory dir, {
    TrackSource source = TrackSource.usb,
    int maxDepth = 5,
    int currentDepth = 0,
    bool includeVideos = false,
    bool includeDashcamFolders = false,
  }) async {
    if (currentDepth > maxDepth) return [];
    final List<MediaTrack> results = [];

    try {
      await for (final entity in dir.list(followLinks: false)) {
        final baseName = p.basename(entity.path).toLowerCase();
        if (entity is Directory) {
          if (baseName.startsWith('.') ||
              (!includeDashcamFolders &&
                  ignoredDashcamFolders.contains(baseName))) {
            continue; // Ignore hidden folders and auto-filtered dashcam folders
          }
          results.addAll(
            await scanDirectory(
              entity,
              source: source,
              maxDepth: maxDepth,
              currentDepth: currentDepth + 1,
              includeVideos: includeVideos,
              includeDashcamFolders: includeDashcamFolders,
            ),
          );
        } else if (entity is File) {
          final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
          final matches = audioExtensions.contains(ext) ||
              (includeVideos && videoExtensions.contains(ext));
          if (matches) {
            results.add(
              buildLocalMediaTrack(entity.path, source: source),
            );
          }
        }
      }
    } catch (_) {
      // Permission-protected system directories are safely skipped
    }

    return results;
  }

  /// Allow user to manually pick a USB/SD Card folder (including dashcam video folders).
  Future<({String folderPath, List<MediaTrack> tracks})?> pickFolderAndScan({
    TrackSource source = TrackSource.usb,
    bool includeVideos = true,
    bool includeDashcamFolders = true,
  }) async {
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Music, Video, or SD/USB Folder',
    );
    if (selectedDir == null) return null;
    final dir = Directory(selectedDir);
    final tracks = await scanDirectory(
      dir,
      source: source,
      includeVideos: includeVideos,
      includeDashcamFolders: includeDashcamFolders,
    );
    return (folderPath: selectedDir, tracks: tracks);
  }

  /// Pick individual audio or dashcam video files (.mp3, .flac, .mp4, .ts, .mov, etc.).
  Future<List<MediaTrack>> pickMediaFiles() async {
    final res = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (res == null) return [];

    return res.files
        .where((f) => f.path != null && isSupportedMediaPath(f.path))
        .map(
          (f) => buildLocalMediaTrack(
            f.path!,
            source: TrackSource.local,
            idPrefix: 'file_',
            artistOverride: isVideoPath(f.path) ? 'Imported Video' : 'Imported File',
          ),
        )
        .toList();
  }

  Future<List<MediaTrack>> pickAudioFiles() => pickMediaFiles();

  List<MediaTrack> _deduplicateByPath(List<MediaTrack> list) {
    final seen = <String>{};
    return list.where((t) => seen.add(t.localPath ?? t.id)).toList();
  }
}
