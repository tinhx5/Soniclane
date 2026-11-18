import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/media_source_service.dart';
import '../../core/services/storage_scanner.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../overlays/add_source_modal.dart';
import '../overlays/cloud_drive_modal.dart';
import '../overlays/playlist_modals.dart';
import '../overlays/wifi_transfer_modal.dart';
import 'offline_downloads_screen.dart';
import 'channel_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'usb_browser_screen.dart';

class LibraryScreen extends ConsumerWidget {
  final bool embedded;
  const LibraryScreen({super.key, this.embedded = false});

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
              padding: EdgeInsets.fromLTRB(24, 16, 24, embedded ? 32 : 140),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Connected Storage & Wireless Sync',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => AddSourceModal.show(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 15, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Add Source',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _ConnectedStorageSection(
                              usbDevices: library.usbDevices,
                              localCount: library.localDeviceTracks.length,
                              isWifiRunning: wifi.isRunning,
                              wifiUrl: wifi.serverUrl,
                              onBrowseUsb: () => UsbBrowserScreen.open(
                                context,
                                initialFolderPath:
                                    library.usbDevices.isNotEmpty
                                        ? library.usbDevices.first.rootPath
                                        : null,
                              ),
                              onPickLocalFiles: () async {
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
                              onWifiTap: () =>
                                  WifiTransferModal.show(context),
                              onDriveTap: () => CloudDriveModal.show(context),
                              onAddSource: () => AddSourceModal.show(context),
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
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 14, 16, embedded ? 24 : 108),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Connected Storage & Wireless Sync',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => AddSourceModal.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 15, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Add Source',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ConnectedStorageSection(
                usbDevices: library.usbDevices,
                localCount: library.localDeviceTracks.length,
                isWifiRunning: wifi.isRunning,
                wifiUrl: wifi.serverUrl,
                onBrowseUsb: () => UsbBrowserScreen.open(
                  context,
                  initialFolderPath: library.usbDevices.isNotEmpty
                      ? library.usbDevices.first.rootPath
                      : null,
                ),
                onPickLocalFiles: () async {
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
                onWifiTap: () => WifiTransferModal.show(context),
                onDriveTap: () => CloudDriveModal.show(context),
                onAddSource: () => AddSourceModal.show(context),
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

class _ConnectedStorageSection extends StatelessWidget {
  final List<StorageDeviceInfo> usbDevices;
  final int localCount;
  final bool isWifiRunning;
  final String wifiUrl;
  final VoidCallback onBrowseUsb;
  final VoidCallback onPickLocalFiles;
  final VoidCallback onWifiTap;
  final VoidCallback onDriveTap;
  final VoidCallback? onAddSource;

  const _ConnectedStorageSection({
    required this.usbDevices,
    required this.localCount,
    required this.isWifiRunning,
    required this.wifiUrl,
    required this.onBrowseUsb,
    required this.onPickLocalFiles,
    required this.onWifiTap,
    required this.onDriveTap,
    this.onAddSource,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideRow = constraints.maxWidth >= 720;

        final cardUsb = _UsbDriveCard(
          usbDevices: usbDevices,
          onBrowse: onBrowseUsb,
        );
        final cardPhone = _PhoneStorageCard(
          localCount: localCount,
          onPickFiles: onPickLocalFiles,
        );
        final cardWifi = _WifiDropCard(
          isRunning: isWifiRunning,
          url: wifiUrl,
          onTap: onWifiTap,
        );
        final cardDrive = _GoogleDriveCard(
          onTap: onDriveTap,
        );
        final cardSource = _MediaServerCard(
          count: MediaSourceService.instance.sources.length,
          onAdd: onAddSource ?? () => AddSourceModal.show(context),
        );

        if (isWideRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cardUsb),
              const SizedBox(width: 10),
              Expanded(child: cardPhone),
              const SizedBox(width: 10),
              Expanded(child: cardWifi),
              const SizedBox(width: 10),
              Expanded(child: cardDrive),
              const SizedBox(width: 10),
              Expanded(child: cardSource),
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cardUsb),
                const SizedBox(width: 10),
                Expanded(child: cardPhone),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cardWifi),
                const SizedBox(width: 10),
                Expanded(child: cardDrive),
              ],
            ),
            const SizedBox(height: 10),
            cardSource,
          ],
        );
      },
    );
  }
}

class _MediaServerCard extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _MediaServerCard({
    required this.count,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          border: Border.all(
            color: count > 0 ? const Color(0xFF10B981) : SonicTokens.glassBorder,
          ),
          boxShadow: count > 0
              ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.12), blurRadius: 10)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                  ),
                  child: const Icon(Icons.dns_rounded,
                      color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Media Servers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count > 0 ? '$count sources connected' : 'M3U, Jellyfin, Emby, Xtream, Plex',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: SonicTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(SonicTokens.radiusSm),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'Add Source',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    return InkWell(
      onTap: onBrowse,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          border: Border.all(
            color: activeUsb != null
                ? SonicTokens.activeBorderCyan
                : SonicTokens.glassBorder,
          ),
          boxShadow: activeUsb != null
              ? SonicTokens.cyanGlow(opacity: 0.14)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceLowest,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                  ),
                  child: const Icon(Icons.usb_rounded,
                      color: SonicTokens.secondaryContainer, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeUsb?.name ?? 'In-Car USB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (activeUsb != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceLowest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SonicTokens.activeBorderCyan),
                    ),
                    child: const Text(
                      'READY',
                      style: TextStyle(
                        color: SonicTokens.secondaryContainer,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              activeUsb != null
                  ? '${activeUsb.trackCount} Tracks'
                  : 'Plug USB / select folder',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SonicTokens.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceContainer,
                borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Browse Hardware Files',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 13, color: SonicTokens.secondaryContainer),
                ],
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onPickFiles,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                  ),
                  child: const Icon(Icons.folder_copy_rounded,
                      color: SonicTokens.primaryTint, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Device Storage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$localCount local media files',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SonicTokens.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Import Media Files',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.folder_open_rounded,
                      size: 13, color: SonicTokens.primaryTint),
                ],
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded,
                      color: SonicTokens.tertiaryLight, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Wi-Fi Transfer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning
                        ? SonicTokens.successGreen
                        : SonicTokens.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isRunning ? 'Active • $url' : 'LAN Bridge (:8080)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isRunning
                    ? SonicTokens.successGreen
                    : SonicTokens.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'QR Setup Key',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.qr_code_2_rounded,
                      size: 13, color: SonicTokens.tertiaryLight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleDriveCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleDriveCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
                  ),
                  child: const Icon(Icons.cloud_done_rounded,
                      color: SonicTokens.successGreen, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Google Drive',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Stream or save offline audio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SonicTokens.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 28,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(SonicTokens.radiusMd),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Connect Drive Link / Folder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.add_to_drive_rounded,
                      size: 13, color: SonicTokens.successGreen),
                ],
              ),
            ),
          ],
        ),
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
