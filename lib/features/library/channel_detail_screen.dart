import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../overlays/playlist_modals.dart';
import 'playlist_detail_screen.dart';

class ChannelDetailScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;
  final String? initialAvatarUrl;
  final String? initialBannerUrl;

  const ChannelDetailScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    this.initialAvatarUrl,
    this.initialBannerUrl,
  });

  static Future<void> open(
    BuildContext context, {
    required String channelId,
    required String channelName,
    String? avatarUrl,
    String? bannerUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelDetailScreen(
          channelId: channelId,
          channelName: channelName,
          initialAvatarUrl: avatarUrl,
          initialBannerUrl: bannerUrl,
        ),
      ),
    );
  }

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final isFollowed = library.isFollowed(
      widget.channelId,
      channelName: widget.channelName,
    );

    final detailsAsync = ref.watch(
      channelDetailsProvider((
        channelId: widget.channelId,
        channelName: widget.channelName,
      )),
    );

    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      body: detailsAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            _buildAppBar(context, isFollowed, null),
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: SonicTokens.secondaryContainer,
                ),
              ),
            ),
          ],
        ),
        error: (err, _) => CustomScrollView(
          slivers: [
            _buildAppBar(context, isFollowed, null),
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 48, color: SonicTokens.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải dữ liệu kênh\n$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: SonicTokens.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(
                          channelDetailsProvider((
                            channelId: widget.channelId,
                            channelName: widget.channelName,
                          )),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        data: (details) {
          final tracks = details?.tracks ?? const [];
          final playlists = details?.playlists ?? const [];

          if (details != null &&
              details.channelId.startsWith('UC') &&
              isFollowed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final channels = ref.read(libraryProvider).followedChannels;
              final existing = channels.firstWhere(
                (c) =>
                    c.channelName.toLowerCase().trim() ==
                    details.channelName.toLowerCase().trim(),
                orElse: () => FollowedChannel(
                  channelId: details.channelId,
                  channelName: details.channelName,
                  avatarUrl: details.avatarUrl,
                  trackCount: details.tracks.length,
                  followedAt: DateTime.now(),
                ),
              );
              if (existing.channelId != details.channelId ||
                  (details.avatarUrl != null &&
                      details.avatarUrl!.isNotEmpty &&
                      existing.avatarUrl != details.avatarUrl)) {
                ref.read(libraryProvider.notifier).updateFollowedChannel(
                      existing.copyWith(
                        channelId: details.channelId,
                        avatarUrl: details.avatarUrl ?? existing.avatarUrl,
                        trackCount: details.tracks.length,
                      ),
                    );
              }
            });
          }

          if (playlists.isNotEmpty && _tabController == null) {
            _tabController = TabController(length: 2, vsync: this);
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, isFollowed, details),
              if (playlists.isNotEmpty && _tabController != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ChannelTabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      indicatorColor: SonicTokens.primaryRed,
                      indicatorWeight: 3,
                      labelColor: SonicTokens.textPrimary,
                      unselectedLabelColor: SonicTokens.textSecondary,
                      tabs: [
                        Tab(text: AppLocale.songsCount(tracks.length, context)),
                        Tab(text: AppLocale.playlistsCount(playlists.length, context)),
                      ],
                    ),
                  ),
                ),
              if (playlists.isNotEmpty && _tabController != null)
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTrackList(context, tracks),
                      _buildPlaylistList(context, playlists),
                    ],
                  ),
                )
              else
                _buildTrackSliverList(context, tracks),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    bool isFollowed,
    ChannelDetails? details,
  ) {
    final avatar = details?.avatarUrl ?? widget.initialAvatarUrl;
    final name = details?.channelName ?? widget.channelName;
    final subLabel = details?.subscriberCountLabel ??
        (details?.tracks.isNotEmpty == true
            ? AppLocale.songsCount(details!.tracks.length, context)
            : (AppLocale.isVietnamese(context) ? 'Kênh âm nhạc' : 'Artist Channel'));

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: SonicTokens.surfaceLowest,
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background stylized gradient or banner
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E2638),
                    SonicTokens.surfaceLowest,
                  ],
                ),
              ),
            ),
            // Channel Profile Information
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: SonicTokens.surfaceCard,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? const Icon(Icons.person_rounded,
                            size: 40, color: SonicTokens.secondaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SonicTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Follow / Unfollow Toggle Button
                            ElevatedButton.icon(
                              onPressed: () async {
                                final channelId = details?.channelId;
                                final effectiveId = (channelId != null && channelId.isNotEmpty)
                                    ? channelId
                                    : widget.channelId;
                                final nowFollowed = await ref
                                    .read(libraryProvider.notifier)
                                    .toggleFollowChannel(
                                      FollowedChannel(
                                        channelId: effectiveId,
                                        channelName: name,
                                        avatarUrl: avatar,
                                        trackCount: details?.tracks.length,
                                        followedAt: DateTime.now(),
                                      ),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                        nowFollowed
                                            ? AppLocale.followedSuccess(name, context)
                                            : AppLocale.unfollowedSuccess(name, context),
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowed
                                    ? SonicTokens.surfaceContainer
                                    : SonicTokens.primaryRed,
                                foregroundColor: isFollowed
                                    ? SonicTokens.secondaryContainer
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isFollowed
                                        ? SonicTokens.secondaryContainer
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              icon: Icon(
                                isFollowed
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isFollowed ? AppLocale.following(context) : AppLocale.follow(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Play All Button
                            if (details != null && details.tracks.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  playTrackAndOpenMobile(
                                    context,
                                    ref,
                                    details.tracks.first,
                                    queue: details.tracks,
                                    playlistName: name,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: SonicTokens.glassBorder),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: Text(AppLocale.playAll(context)),
                              ),
                          ],
                        ),
                      ],
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

  Widget _buildTrackSliverList(
      BuildContext context, List<MediaTrack> tracks) {
    if (tracks.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'Không tìm thấy bài hát nào của kênh này.',
            style: TextStyle(color: SonicTokens.textSecondary),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = tracks[index];
            return _TrackTile(track: track, queue: tracks);
          },
          childCount: tracks.length,
        ),
      ),
    );
  }

  Widget _buildTrackList(BuildContext context, List<MediaTrack> tracks) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy bài hát nào.',
          style: TextStyle(color: SonicTokens.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackTile(track: track, queue: tracks);
      },
    );
  }

  Widget _buildPlaylistList(
      BuildContext context, List<HybridPlaylist> playlists) {
    if (playlists.isEmpty) {
      return const Center(
        child: Text(
          'Kênh chưa tạo danh sách phát nào.',
          style: TextStyle(color: SonicTokens.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return ListTile(
          tileColor: SonicTokens.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
            side: const BorderSide(color: SonicTokens.glassBorder),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SonicTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.queue_music_rounded,
                color: SonicTokens.secondaryContainer),
          ),
          title: Text(
            pl.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Playlist • ${pl.items.length} bài',
            style: const TextStyle(
                color: SonicTokens.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: SonicTokens.textSecondary),
          onTap: () => PlaylistDetailScreen.open(context, pl),
        );
      },
    );
  }
}

class _TrackTile extends ConsumerWidget {
  final MediaTrack track;
  final List<MediaTrack> queue;

  const _TrackTile({required this.track, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: SonicTokens.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          side: const BorderSide(color: SonicTokens.glassBorder),
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
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            if (track.viewCountLabel != null) ...[
              Text(
                track.viewCountLabel!,
                style: const TextStyle(
                  color: SonicTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Text(' • ',
                  style: TextStyle(color: SonicTokens.textSecondary)),
            ],
            Text(
              track.formattedDuration,
              style: const TextStyle(
                color: SonicTokens.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded),
              tooltip: 'Thêm vào danh sách phát',
              onPressed: () => AddToPlaylistSheet.show(context, track),
            ),
            const Icon(Icons.play_arrow_rounded,
                color: SonicTokens.secondaryContainer),
          ],
        ),
        onTap: () => playTrackAndOpenMobile(
          context,
          ref,
          track,
          queue: queue,
          playlistName: track.artist,
        ),
      ),
    );
  }
}

class _ChannelTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _ChannelTabBarDelegate({required this.tabBar});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: SonicTokens.surfaceLowest,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _ChannelTabBarDelegate oldDelegate) {
    return false;
  }
}
