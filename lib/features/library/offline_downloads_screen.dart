import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';

class OfflineDownloadsScreen extends ConsumerWidget {
  const OfflineDownloadsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OfflineDownloadsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final allOffline = [
      ...library.offlineTracks,
      ...library.localDeviceTracks,
    ];

    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      appBar: AppBar(
        backgroundColor: SonicTokens.surfaceLowest,
        title: const Text('Nhạc ngoại tuyến & Tải về'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(libraryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: allOffline.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocale.isVietnamese(context)
                      ? 'Chưa có bài hát ngoại tuyến nào được lưu.\nBấm nút "Tải về ngoại tuyến" khi đang phát để nghe không tốn 4G/5G, hoặc import nhạc từ USB / bộ nhớ máy.'
                      : 'No offline tracks saved yet.\nTap "Download Offline" while playing to listen without mobile data, or import music from USB / device storage.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SonicTokens.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: SonicTokens.minTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: () => playTrackAndOpenMobile(
                      context,
                      ref,
                      allOffline.first,
                      queue: allOffline,
                      playlistName: '4G-Free Offline Mix',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SonicTokens.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      'Play All Offline (${allOffline.length} Tracks)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...allOffline.map((t) {
                  final isCachedDownload =
                      library.offlineTracks.any((c) => c.id == t.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: SonicTokens.surfaceCard,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                        side: const BorderSide(color: SonicTokens.glassBorder),
                      ),
                      leading: TrackArtwork(
                        url: t.thumbnailUrl,
                        width: 52,
                        height: 52,
                      ),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SourceBadgeChip(
                            source: TrackSource.local,
                            customLabel:
                                isCachedDownload ? '📥 Cached' : t.qualityBadge,
                          ),
                        ],
                      ),
                      trailing: isCachedDownload
                          ? IconButton(
                              tooltip: 'Remove cached file',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: SonicTokens.errorRed),
                              onPressed: () async {
                                await DatabaseService.instance
                                    .deleteOfflineTrack(t.id);
                                await ref
                                    .read(libraryProvider.notifier)
                                    .refresh();
                              },
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      onTap: () => playTrackAndOpenMobile(
                        context,
                        ref,
                        t,
                        queue: allOffline,
                        playlistName: 'Offline Mix',
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
