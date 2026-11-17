import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../overlays/playlist_modals.dart';
import 'playlist_detail_screen.dart';

class PlaylistsTabScreen extends ConsumerWidget {
  const PlaylistsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlists = library.playlists;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final crossAxisCount = constraints.maxWidth >= 1200
              ? 4
              : (constraints.maxWidth >= 850 ? 3 : 2);

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  20,
                  isWide ? 24 : 16,
                  16,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.queue_music_rounded,
                        color: SonicTokens.secondaryContainer,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Danh sách phát',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              '${playlists.length} hybrid playlists • Online & USB FLAC',
                              style: const TextStyle(
                                fontSize: 13,
                                color: SonicTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => CreatePlaylistDialog.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SonicTokens.secondaryContainer,
                          foregroundColor: SonicTokens.surfaceBase,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Tạo mới',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (playlists.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: SonicTokens.surfaceCard,
                        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                        border: Border.all(color: SonicTokens.glassBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.queue_music_rounded,
                            size: 56,
                            color: SonicTokens.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có danh sách phát nào',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tạo playlist kết hợp giữa nhạc trực tuyến và nhạc USB FLAC ngoại tuyến.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: SonicTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => CreatePlaylistDialog.show(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SonicTokens.secondaryContainer,
                              foregroundColor: SonicTokens.surfaceBase,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Tạo Hybrid Playlist đầu tiên',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 24 : 16,
                    8,
                    isWide ? 24 : 16,
                    120,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.15,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pl = playlists[index];
                        return _PlaylistGridCard(playlist: pl);
                      },
                      childCount: playlists.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistGridCard extends ConsumerWidget {
  final HybridPlaylist playlist;

  const _PlaylistGridCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackCount = playlist.items.length;
    final firstThumb = playlist.items.isNotEmpty ? playlist.items.first.thumbnailUrl : '';

    return InkWell(
      onTap: () => PlaylistDetailScreen.open(context, playlist),
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        decoration: BoxDecoration(
          color: SonicTokens.surfaceCard,
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          border: Border.all(color: SonicTokens.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstThumb.isNotEmpty)
                    TrackArtwork(url: firstThumb, radius: 0)
                  else
                    Container(
                      color: SonicTokens.surfaceElevated,
                      child: const Center(
                        child: Icon(
                          Icons.queue_music_rounded,
                          size: 40,
                          color: SonicTokens.secondaryContainer,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: playlist.items.isEmpty
                          ? null
                          : () {
                              playTrackAndOpenMobile(
                                context,
                                ref,
                                playlist.items.first,
                                queue: playlist.items,
                                playlistName: playlist.name,
                                playlistId: playlist.id,
                              );
                            },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SonicTokens.secondaryBlue.withOpacity(0.92),
                          boxShadow: SonicTokens.blueGlow(),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$trackCount bài hát • ${playlist.streamCount} Online, ${playlist.usbCount} USB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SonicTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: SonicTokens.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => _showPlaylistMenu(context, ref, playlist),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistMenu(
    BuildContext context,
    WidgetRef ref,
    HybridPlaylist pl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded,
                  color: SonicTokens.secondaryContainer),
              title: const Text('Phát tất cả'),
              onTap: () {
                Navigator.pop(ctx);
                if (pl.items.isNotEmpty) {
                  playTrackAndOpenMobile(
                    context,
                    ref,
                    pl.items.first,
                    queue: pl.items,
                    playlistName: pl.name,
                    playlistId: pl.id,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: SonicTokens.primaryRed),
              title: const Text('Xóa danh sách phát',
                  style: TextStyle(color: SonicTokens.primaryRed)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(libraryProvider.notifier).deletePlaylist(pl.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
