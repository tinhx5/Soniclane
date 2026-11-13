import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/storage_scanner.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../overlays/cloud_drive_modal.dart';
import '../overlays/playlist_modals.dart';
import '../overlays/wifi_transfer_modal.dart';
import 'offline_downloads_screen.dart';
import 'channel_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'usb_browser_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final wifi = ref.watch(wifiServerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LibraryTopBar(sortBy: library.sortBy),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Hybrid Playlists Stack
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FollowedChannelsShelf(
                              channels: library.followedChannels,
                            ),
                            const SizedBox(height: 20),
                            _PlaylistsColumn(playlists: library.playlists),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right: Quick Access + Hardware & Wireless Storage Hub
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _QuickAccessGrid(
                              likedCount: library.likedTracks.length,
                              offlineCount: library.offlineTracks.length +
                                  library.localDeviceTracks.length,
                              onLikedTap: () {
                                if (library.likedTracks.isNotEmpty) {
                                  playTrackAndOpenMobile(
                                    context,
                                    ref,
                                    library.likedTracks.first,
                                    queue: library.likedTracks,
                                    playlistName: 'Liked Songs',
                                  );
                                }
                              },
                              onOfflineTap: () =>
                                  OfflineDownloadsScreen.open(context),
                            ),
                            const SizedBox(height: 16),
                            _UsbDriveCard(
                              usbDevices: library.usbDevices,
                              onBrowse: () => UsbBrowserScreen.open(
                                context,
                                initialFolderPath:
                                    library.usbDevices.isNotEmpty
                                        ? library.usbDevices.first.rootPath
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PhoneStorageCard(
                              localCount: library.localDeviceTracks.length,
                              onPickFiles: () async {
                                final files = await StorageScanner.instance
                                    .pickMediaFiles();
                                if (files.isNotEmpty && context.mounted) {
                                  await playTrackAndOpenMobile(
                                    context,
                                    ref,
                                    files.first,
                                    queue: files,
                                    playlistName: 'Imported Local Media',
                                    keepVideoMode:
                                        (files.first.videoStreamUrl != null &&
                                                files.first.videoStreamUrl!
                                                    .isNotEmpty)
                                            ? true
                                            : null,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            _WifiDropCard(
                              isRunning: wifi.isRunning,
                              url: wifi.serverUrl,
                              onTap: () => WifiTransferModal.show(context),
                            ),
                            const SizedBox(height: 14),
                            _GoogleDriveCard(
                              onTap: () => CloudDriveModal.show(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          // Mobile Portrait Layout matching Mobile_library_storage_hub Stitch
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
            children: [
              _LibraryTopBar(sortBy: library.sortBy),
              const SizedBox(height: 14),
              _FollowedChannelsShelf(channels: library.followedChannels),
              const SizedBox(height: 20),
              _PlaylistsColumn(playlists: library.playlists),
              const SizedBox(height: 20),
              _QuickAccessGrid(
                likedCount: library.likedTracks.length,
                offlineCount: library.offlineTracks.length +
                    library.localDeviceTracks.length,
                onLikedTap: () {
                  if (library.likedTracks.isNotEmpty) {
                    playTrackAndOpenMobile(
                      context,
                      ref,
                      library.likedTracks.first,
                      queue: library.likedTracks,
                      playlistName: 'Liked Songs',
                    );
                  }
                },
                onOfflineTap: () => OfflineDownloadsScreen.open(context),
              ),
              const SizedBox(height: 20),
              Text('Connected Storage & Wireless Sync',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SizedBox(
                height: 256,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _UsbDriveCard(
                        usbDevices: library.usbDevices,
                        onBrowse: () => UsbBrowserScreen.open(
                          context,
                          initialFolderPath: library.usbDevices.isNotEmpty
                              ? library.usbDevices.first.rootPath
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _PhoneStorageCard(
                        localCount: library.localDeviceTracks.length,
                        onPickFiles: () async {
                          final files =
                              await StorageScanner.instance.pickMediaFiles();
                          if (files.isNotEmpty && context.mounted) {
                            await playTrackAndOpenMobile(
                              context,
                              ref,
                              files.first,
                              queue: files,
                              playlistName: 'Device Media',
                              keepVideoMode:
                                  (files.first.videoStreamUrl != null &&
                                          files.first.videoStreamUrl!.isNotEmpty)
                                      ? true
                                      : null,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _WifiDropCard(
                        isRunning: wifi.isRunning,
                        url: wifi.serverUrl,
                        onTap: () => WifiTransferModal.show(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 300,
                      child: _GoogleDriveCard(
                        onTap: () => CloudDriveModal.show(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryTopBar extends ConsumerWidget {
  final String sortBy;
  const _LibraryTopBar({required this.sortBy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Playlists',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        PopupMenuButton<String>(
          color: SonicTokens.surfaceElevated,
          onSelected: (v) => ref.read(libraryProvider.notifier).setSort(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'Recent', child: Text('Sort: Recent')),
            PopupMenuItem(value: 'Name A-Z', child: Text('Sort: Name A-Z')),
            PopupMenuItem(
                value: 'Most Tracks', child: Text('Sort: Most Tracks')),
          ],
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
              border: Border.all(color: SonicTokens.glassBorder),
            ),
            child: Row(
              children: [
                Text(
                  'Sort: $sortBy',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        CockpitTouchButton(
          minSize: 48,
          onTap: () => CreatePlaylistDialog.show(context),
          backgroundColor: SonicTokens.surfaceContainer,
          child: const Icon(Icons.add_rounded, size: 26),
        ),
        const SizedBox(width: 8),
        CockpitTouchButton(
          minSize: 48,
          onTap: () => ImportUrlDialog.show(context),
          backgroundColor: SonicTokens.surfaceContainer,
          child: const Icon(Icons.link_rounded,
              color: SonicTokens.secondaryContainer, size: 24),
        ),
      ],
    );
  }
}

class _PlaylistsColumn extends ConsumerWidget {
  final List<HybridPlaylist> playlists;
  const _PlaylistsColumn({required this.playlists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (playlists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceCard,
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        ),
        child: Column(
          children: [
            const Icon(Icons.queue_music_rounded,
                size: 40, color: SonicTokens.textTertiary),
            const SizedBox(height: 10),
            const Text('No hybrid playlists yet'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => CreatePlaylistDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Hybrid Playlist'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: playlists.map((pl) {
        final covers = pl.coverArtUrls;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => PlaylistDetailScreen.open(context, pl),
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceCard,
                borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: Row(
                children: [
                  // 4-Grid Collage Thumbnail or fallback
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: covers.length >= 4
                          ? GridView.count(
                              crossAxisCount: 2,
                              physics: const NeverScrollableScrollPhysics(),
                              children: covers
                                  .map((u) => TrackArtwork(url: u, radius: 0))
                                  .toList(),
                            )
                          : TrackArtwork(
                              url: covers.isNotEmpty ? covers.first : '',
                              width: 64,
                              height: 64,
                              fallbackIcon: Icons.queue_music_rounded,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (pl.streamCount > 0)
                              SourceBadgeChip(
                                source: TrackSource.customStream,
                                customLabel: '🌐 ${pl.streamCount} Stream',
                              ),
                            if (pl.usbCount > 0)
                              SourceBadgeChip(
                                source: TrackSource.usb,
                                customLabel: '💾 ${pl.usbCount} USB FLAC',
                              ),
                            if (pl.localCount > 0)
                              SourceBadgeChip(
                                source: TrackSource.local,
                                customLabel: '📱 ${pl.localCount} Local',
                              ),
                            Text(
                              pl.formattedTotalDuration,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CockpitTouchButton(
                    onTap: pl.items.isNotEmpty
                        ? () => playTrackAndOpenMobile(
                              context,
                              ref,
                              pl.items.first,
                              queue: pl.items,
                              playlistName: pl.name,
                              playlistId: pl.id,
                            )
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: SonicTokens.surfaceHigh,
                    child: const Icon(Icons.play_arrow_rounded, size: 30),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final int likedCount;
  final int offlineCount;
  final VoidCallback onLikedTap;
  final VoidCallback onOfflineTap;

  const _QuickAccessGrid({
    required this.likedCount,
    required this.offlineCount,
    required this.onLikedTap,
    required this.onOfflineTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onLikedTap,
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: Container(
              constraints: const BoxConstraints(minHeight: 146),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceLowest,
                      borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: SonicTokens.primaryContainer, size: 24),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Liked Songs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '$likedCount Tracks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: SonicTokens.primaryTint,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onOfflineTap,
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: Container(
              constraints: const BoxConstraints(minHeight: 146),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceLowest,
                      borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                    ),
                    child: const Icon(Icons.download_for_offline_rounded,
                        color: SonicTokens.secondaryContainer, size: 24),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline Files',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '$offlineCount Tracks • 4G-Free',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: SonicTokens.secondaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsbDriveCard extends StatelessWidget {
  final List<StorageDeviceInfo> usbDevices;
  final VoidCallback onBrowse;

  const _UsbDriveCard({
    required this.usbDevices,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final activeUsb = usbDevices.isNotEmpty ? usbDevices.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceHigh,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(
          color: activeUsb != null
              ? SonicTokens.activeBorderCyan
              : SonicTokens.glassBorder,
        ),
        boxShadow: activeUsb != null ? SonicTokens.cyanGlow(opacity: 0.14) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceLowest,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
                child: const Icon(Icons.usb_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeUsb?.name ?? 'In-Car USB Drive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      activeUsb?.subtitle ?? 'Plug USB or select music folder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (activeUsb != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceLowest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: SonicTokens.activeBorderCyan),
                  ),
                  child: const Text(
                    'MOUNTED',
                    style: TextStyle(
                      color: SonicTokens.secondaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceLowest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              activeUsb != null
                  ? '● ${activeUsb.trackCount} Audio Tracks (Dashcam Filtered)'
                  : '● Ignores DCIM / DVR Dashcam Videos',
              style: const TextStyle(
                  color: SonicTokens.secondaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: activeUsb?.usageRatio ?? 0.35,
              minHeight: 7,
              backgroundColor: SonicTokens.surfaceLowest,
              color: SonicTokens.secondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBrowse,
              style: ElevatedButton.styleFrom(
                backgroundColor: SonicTokens.surfaceContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Browse Hardware Files',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded,
                      color: SonicTokens.secondaryContainer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneStorageCard extends StatelessWidget {
  final int localCount;
  final VoidCallback onPickFiles;

  const _PhoneStorageCard({
    required this.localCount,
    required this.onPickFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
                child: const Icon(Icons.folder_copy_rounded,
                    color: SonicTokens.primaryTint, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device & Files Storage',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('$localCount local media files ready',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPickFiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: SonicTokens.surfaceHigh,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Import Media Files (Audio / MP4 / TS)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.folder_open_rounded,
                      color: SonicTokens.primaryTint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiDropCard extends StatelessWidget {
  final bool isRunning;
  final String url;
  final VoidCallback onTap;

  const _WifiDropCard({
    required this.isRunning,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
                child: const Icon(Icons.wifi_tethering_rounded,
                    color: SonicTokens.tertiaryLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wi-Fi Drop Server',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      isRunning ? 'Active • $url' : 'Cockpit LAN Bridge (:8080)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRunning
                            ? SonicTokens.successGreen
                            : SonicTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: SonicTokens.surfaceHigh,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'QR Setup Key',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.qr_code_2_rounded,
                      color: SonicTokens.tertiaryLight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleDriveCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleDriveCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
                child: const Icon(Icons.cloud_done_rounded,
                    color: SonicTokens.successGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Drive Cloud',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Stream or download personal Drive audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: SonicTokens.surfaceHigh,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Connect Drive Link / Folder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.add_to_drive_rounded,
                      color: SonicTokens.successGreen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowedChannelsShelf extends StatelessWidget {
  final List<FollowedChannel> channels;

  const _FollowedChannelsShelf({required this.channels});

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceCard,
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          border: Border.all(color: SonicTokens.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SonicTokens.primaryContainer.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_border_rounded,
                  color: SonicTokens.primaryTint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocale.followedChannels(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: SonicTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocale.followActionHint(context),
                    style: const TextStyle(
                      fontSize: 11,
                      color: SonicTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocale.followedChannelsCount(channels.length, context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = channels[index];
              return InkWell(
                onTap: () => ChannelDetailScreen.open(
                  context,
                  channelId: c.channelId,
                  channelName: c.channelName,
                  avatarUrl: c.avatarUrl,
                  bannerUrl: c.bannerUrl,
                ),
                borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                child: Container(
                  width: 90,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceCard,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                    border: Border.all(color: SonicTokens.glassBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: SonicTokens.surfaceContainer,
                        backgroundImage:
                            (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                                ? NetworkImage(c.avatarUrl!)
                                : null,
                        child: (c.avatarUrl == null || c.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person_rounded,
                                color: SonicTokens.secondaryContainer)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SonicTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
