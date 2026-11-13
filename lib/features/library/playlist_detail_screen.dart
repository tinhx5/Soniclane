import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/offline_download_service.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final HybridPlaylist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  static Future<void> open(BuildContext context, HybridPlaylist playlist) {
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist)),
    );
  }

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _batchDownloading = false;

  Future<void> _downloadAllOffline(HybridPlaylist livePlaylist) async {
    if (_batchDownloading) return;
    setState(() => _batchDownloading = true);
    final count =
        await OfflineDownloadService.instance.downloadPlaylist(livePlaylist);
    await ref.read(libraryProvider.notifier).refresh();
    if (mounted) {
      setState(() => _batchDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: SonicTokens.surfaceElevated,
          content: Text(
            'Cached $count personal Drive track(s) for offline playback.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final livePlaylist = library.playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );

    return StreamBuilder<DownloadStatus>(
      stream: OfflineDownloadService.instance.statusStream,
      initialData: OfflineDownloadService.instance.currentStatus,
      builder: (context, snapshot) {
        final dlStatus =
            snapshot.data ?? OfflineDownloadService.instance.currentStatus;

        return Scaffold(
          backgroundColor: SonicTokens.surfaceBase,
          appBar: AppBar(
            backgroundColor: SonicTokens.surfaceLowest,
            title: Text(livePlaylist.name),
            actions: [
              IconButton(
                tooltip: 'Delete Playlist',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: SonicTokens.errorRed),
                onPressed: () async {
                  await ref
                      .read(libraryProvider.notifier)
                      .deletePlaylist(livePlaylist.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceCard,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                  border: Border.all(color: SonicTokens.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      livePlaylist.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (livePlaylist.streamCount > 0)
                          SourceBadgeChip(
                            source: TrackSource.customStream,
                            customLabel:
                                '🌐 ${livePlaylist.streamCount} Stream Info',
                          ),
                        if (livePlaylist.usbCount > 0)
                          SourceBadgeChip(
                            source: TrackSource.usb,
                            customLabel: '💾 ${livePlaylist.usbCount} USB FLAC',
                          ),
                        if (livePlaylist.localCount > 0)
                          SourceBadgeChip(
                            source: TrackSource.local,
                            customLabel:
                                '📱 ${livePlaylist.localCount} Local',
                          ),
                        Text(
                          '${livePlaylist.items.length} tracks • ${livePlaylist.formattedTotalDuration}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          height: SonicTokens.minTouchTarget,
                          child: ElevatedButton.icon(
                            onPressed: livePlaylist.items.isNotEmpty
                                ? () => playTrackAndOpenMobile(
                                      context,
                                      ref,
                                      livePlaylist.items.first,
                                      queue: livePlaylist.items,
                                      playlistName: livePlaylist.name,
                                      playlistId: livePlaylist.id,
                                    )
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SonicTokens.primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(SonicTokens.radiusLg),
                              ),
                            ),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 28),
                            label: const Text('Play All',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        SizedBox(
                          height: SonicTokens.minTouchTarget,
                          child: OutlinedButton.icon(
                            onPressed: livePlaylist.items.isNotEmpty
                                  ? () {
                                    SonicAudioEngine.instance.toggleShuffle();
                                    playTrackAndOpenMobile(
                                      context,
                                      ref,
                                      livePlaylist.items.first,
                                      queue: livePlaylist.items,
                                      playlistName: livePlaylist.name,
                                      playlistId: livePlaylist.id,
                                    );
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: SonicTokens.glassBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(SonicTokens.radiusLg),
                              ),
                            ),
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('Shuffle'),
                          ),
                        ),
                        if (livePlaylist.items
                            .any((t) => t.source == TrackSource.googleDrive))
                          SizedBox(
                            height: SonicTokens.minTouchTarget,
                            child: ElevatedButton.icon(
                              onPressed: _batchDownloading
                                  ? null
                                  : () => _downloadAllOffline(livePlaylist),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SonicTokens.surfaceElevated,
                                foregroundColor: SonicTokens.secondaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      SonicTokens.radiusLg),
                                  side: const BorderSide(
                                      color: SonicTokens.activeBorderCyan),
                                ),
                              ),
                              icon: _batchDownloading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.download_for_offline_rounded),
                              label: Text(_batchDownloading
                                  ? 'Caching...'
                                  : 'Save All Offline'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (livePlaylist.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'This hybrid playlist has no tracks yet.\nAdd tracks from Home, Search, or USB Browser.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SonicTokens.textSecondary),
                    ),
                  ),
                )
              else
                ...livePlaylist.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final track = entry.value;
                  final progress = dlStatus.progressByTrackId[track.id];
                  final isOfflineCached = library.offlineTracks
                      .any((off) => off.id == track.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: track.isAvailable ? 1.0 : 0.45,
                      child: Column(
                        children: [
                          ListTile(
                            tileColor: SonicTokens.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SonicTokens.radiusLg),
                              side: const BorderSide(
                                  color: SonicTokens.glassBorder),
                            ),
                            leading: TrackArtwork(
                              url: track.thumbnailUrl,
                              width: 52,
                              height: 52,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SourceBadgeChip(
                                  source: track.source,
                                  customLabel: !track.isAvailable
                                      ? '🔌 Plug USB'
                                      : (isOfflineCached
                                          ? '📥 Cached'
                                          : null),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (track.source == TrackSource.googleDrive &&
                                    !isOfflineCached)
                                  IconButton(
                                    tooltip: 'Save Drive File Offline',
                                    icon: const Icon(Icons.download_rounded,
                                        color: SonicTokens.secondaryContainer,
                                        size: 20),
                                    onPressed: () async {
                                      await OfflineDownloadService.instance
                                          .downloadTrack(track);
                                      await ref
                                          .read(libraryProvider.notifier)
                                          .refresh();
                                    },
                                  ),
                                Text('${idx + 1}',
                                    style: const TextStyle(
                                        color: SonicTokens.textTertiary)),
                                IconButton(
                                  icon:
                                      const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () => ref
                                      .read(libraryProvider.notifier)
                                      .removeTrackFromPlaylist(
                                          livePlaylist.id, track.id),
                                ),
                              ],
                            ),
                            onTap: track.isAvailable
                                ? () => playTrackAndOpenMobile(
                                      context,
                                      ref,
                                      track,
                                      queue: livePlaylist.items,
                                      playlistName: livePlaylist.name,
                                      playlistId: livePlaylist.id,
                                    )
                                : null,
                          ),
                          if (progress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                color: SonicTokens.secondaryContainer,
                                backgroundColor: SonicTokens.surfaceHighest,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
