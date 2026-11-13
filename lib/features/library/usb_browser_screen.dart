import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/services/storage_scanner.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../overlays/playlist_modals.dart';

class UsbBrowserScreen extends ConsumerStatefulWidget {
  final String? initialFolderPath;
  final TrackSource source;

  const UsbBrowserScreen({
    super.key,
    this.initialFolderPath,
    this.source = TrackSource.usb,
  });

  static Future<void> open(
    BuildContext context, {
    String? initialFolderPath,
    TrackSource source = TrackSource.usb,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsbBrowserScreen(
          initialFolderPath: initialFolderPath,
          source: source,
        ),
      ),
    );
  }

  @override
  ConsumerState<UsbBrowserScreen> createState() => _UsbBrowserScreenState();
}

class _UsbBrowserScreenState extends ConsumerState<UsbBrowserScreen> {
  List<MediaTrack> _tracks = [];
  String? _activePath;
  bool _scanning = true;
  bool _manualDashcamScan = false;

  @override
  void initState() {
    super.initState();
    _activePath = widget.initialFolderPath;
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    List<MediaTrack> found;
    if (_activePath != null) {
      found = await StorageScanner.instance.scanDirectory(
        Directory(_activePath!),
        source: widget.source,
        includeVideos: _manualDashcamScan,
        includeDashcamFolders: _manualDashcamScan,
      );
    } else {
      found = await StorageScanner.instance.scanInternalDeviceMusic();
    }
    if (mounted) {
      setState(() {
        _tracks = found;
        _scanning = false;
      });
    }
  }

  Future<void> _pickFolder() async {
    final res = await StorageScanner.instance.pickFolderAndScan(
      source: widget.source,
      includeVideos: true,
      includeDashcamFolders: true,
    );
    if (res != null && mounted) {
      setState(() {
        _manualDashcamScan = true;
        _activePath = res.folderPath;
        _tracks = res.tracks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      appBar: AppBar(
        backgroundColor: SonicTokens.surfaceLowest,
        title: Text(widget.source == TrackSource.usb
            ? 'In-Car USB & Drive Browser'
            : 'On-Device Music Files'),
        actions: [
          IconButton(
            tooltip: 'Pick Folder',
            icon: const Icon(Icons.folder_open_rounded,
                color: SonicTokens.secondaryContainer),
            onPressed: _pickFolder,
          ),
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceCard,
              borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
              border: Border.all(color: SonicTokens.activeBorderCyan),
            ),
            child: Row(
              children: [
                const Icon(Icons.usb_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activePath ?? 'Internal Music & Wi-Fi Drop Folder',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Dashcam folders (DCIM, DVR) automatically filtered out.',
                        style: TextStyle(
                            color: SonicTokens.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickFolder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SonicTokens.secondaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Select Drive'),
                ),
              ],
            ),
          ),
          if (_tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: SonicTokens.minTouchTarget,
                      child: ElevatedButton.icon(
                        onPressed: () => playTrackAndOpenMobile(
                          context,
                          ref,
                          _tracks.first,
                          queue: _tracks,
                          playlistName: 'Hardware USB Mix',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SonicTokens.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SonicTokens.radiusLg),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Play All (${_tracks.length})'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: () => CreatePlaylistDialog.show(context,
                          initialTracks: _tracks),
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Save Playlist'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _scanning
                ? const Center(child: CircularProgressIndicator())
                : _tracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_off_rounded,
                                size: 48, color: SonicTokens.textTertiary),
                            const SizedBox(height: 12),
                            const Text(
                              'No MP3 / FLAC / WAV files found here.',
                              style:
                                  TextStyle(color: SonicTokens.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _pickFolder,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('Choose USB / Music Folder'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final t = _tracks[i];
                          final isVideo = t.videoStreamUrl != null &&
                              t.videoStreamUrl!.isNotEmpty;
                          return ListTile(
                            tileColor: SonicTokens.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SonicTokens.radiusLg),
                            ),
                            leading: Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.audiotrack_rounded,
                                color: SonicTokens.secondaryContainer),
                            title: Text(t.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Row(
                              children: [
                                Text(t.artist),
                                const SizedBox(width: 8),
                                SourceBadgeChip(
                                    source: t.source,
                                    customLabel: t.qualityBadge),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.playlist_add_rounded),
                              onPressed: () =>
                                  AddToPlaylistSheet.show(context, t),
                            ),
                            onTap: () => playTrackAndOpenMobile(
                              context,
                              ref,
                              t,
                              queue: _tracks,
                              playlistName: 'Hardware Storage',
                              keepVideoMode: isVideo ? true : null,
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
