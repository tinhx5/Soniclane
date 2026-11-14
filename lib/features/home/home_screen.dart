import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/stream_resolver.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../core/utils/url_parser.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../browser/web_browser_screen.dart';
import '../library/channel_detail_screen.dart';
import '../overlays/cloud_drive_modal.dart';
import '../overlays/playlist_modals.dart';
import '../overlays/wifi_transfer_modal.dart';
import 'history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static List<String> _getFilters([BuildContext? context]) => [
    'All Blended',
    '💾 In-Car USB',
    'Night Drives',
    'High-BPM Focus',
    'Lo-Fi Road',
    'Podcasts & Talk',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeFeedProvider);
    final library = ref.watch(libraryProvider);
    final clipLink = ref.watch(clipboardBannerProvider);
    final showResume = ref.watch(resumeCardVisibleProvider);
    final filters = _getFilters(context);

    final filteredRecs = _applyFilter(
      home.recommendations,
      library.localDeviceTracks,
      home.selectedFilter,
    );

    return RefreshIndicator(
      color: SonicTokens.secondaryContainer,
      onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 24 : 16,
              14,
              isWide ? 24 : 16,
              isWide ? 140 : 108,
            ),
            children: [
              // Dynamic Clipboard Auto-Detect Banner
              if (clipLink != null) ...[
                _ClipboardDetectedBanner(match: clipLink),
                const SizedBox(height: 16),
              ],

              if (isWide) ...[
                if (home.followedChannels.isNotEmpty) ...[
                  _HomeFollowedChannelsRail(channels: home.followedChannels),
                  const SizedBox(height: 12),
                ],
                _FilterChipsRow(
                  filters: filters,
                  selected: home.selectedFilter,
                  onSelected: (f) =>
                      ref.read(homeFeedProvider.notifier).selectFilter(f),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'Resume & Listen Again',
                  icon: Icons.history_rounded,
                  actionLabel: 'VIEW HISTORY',
                  onAction: () => PlaybackHistoryScreen.open(context),
                ),
                const SizedBox(height: 12),
                _TabletResumeAndHistoryRow(
                  resumeTrack: showResume ? home.resumeTrack : null,
                  listenAgain: home.listenAgain,
                ),
                const SizedBox(height: 26),
                const _SectionHeader(
                  title: 'Smart Recommendations',
                  icon: Icons.auto_awesome_rounded,
                  badgeLabel: 'Local Engine 70/30',
                ),
                const SizedBox(height: 14),
                if (home.isLoading && filteredRecs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filteredRecs.isEmpty)
                  _ByoSourceOnboardingCard(
                    hasCustomServer: StreamResolver.instance.hasCustomServer,
                  )
                else
                  _RecommendationsGrid(
                    tracks: filteredRecs,
                    columns: constraints.maxWidth >= 1150 ? 3 : 2,
                  ),
              ] else ...[
                // Mobile Portrait Layout (Resume only shown once per app launch)
                if (showResume && home.resumeTrack != null) ...[
                  _MobileResumeHeroCard(track: home.resumeTrack!),
                  const SizedBox(height: 22),
                ],
                _SectionHeader(
                  title: 'Listen Again',
                  actionLabel: 'VIEW ALL',
                  onAction: () => PlaybackHistoryScreen.open(context),
                ),
                const SizedBox(height: 10),
                _MobileListenAgainShelf(tracks: home.listenAgain),
                const SizedBox(height: 18),
                if (home.followedChannels.isNotEmpty) ...[
                  _HomeFollowedChannelsRail(channels: home.followedChannels),
                ],
                _FilterChipsRow(
                  filters: filters,
                  selected: home.selectedFilter,
                  onSelected: (f) =>
                      ref.read(homeFeedProvider.notifier).selectFilter(f),
                ),
                const SizedBox(height: 20),
                const _SectionHeader(
                  title: 'Smart Recommendations',
                  icon: Icons.auto_awesome_rounded,
                  badgeLabel: 'Local Engine',
                ),
                const SizedBox(height: 12),
                if (home.isLoading && filteredRecs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (filteredRecs.isEmpty)
                  _ByoSourceOnboardingCard(
                    hasCustomServer: StreamResolver.instance.hasCustomServer,
                  )
                else
                  ...filteredRecs.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FeedMediaCard(track: t),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<MediaTrack> _applyFilter(
    List<MediaTrack> recs,
    List<MediaTrack> localTracks,
    String filter,
  ) {
    if (filter == 'All Blended') return recs;
    if (filter.startsWith('⭐')) {
      final followedOnly = recs
          .where((t) => t.recommendationTag?.startsWith('⭐') ?? false)
          .toList();
      return followedOnly.isNotEmpty ? followedOnly : recs;
    }
    if (filter == '💾 In-Car USB') {
      final usbOnly =
          recs.where((t) => t.source.isOfflineCapable).toList();
      return usbOnly.isNotEmpty ? usbOnly : localTracks;
    }
    final keyword = filter.toLowerCase().split(' ').first;
    final filtered = recs
        .where((t) =>
            t.title.toLowerCase().contains(keyword) ||
            t.artist.toLowerCase().contains(keyword))
        .toList();
    return filtered.isNotEmpty ? filtered : recs;
  }
}

class _HomeFollowedChannelsRail extends StatelessWidget {
  final List<FollowedChannel> channels;

  const _HomeFollowedChannelsRail({required this.channels});

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: AppLocale.followedChannelsShelfTitle(context),
          icon: Icons.star_rounded,
          badgeLabel:
              AppLocale.isVietnamese(context) ? 'Cá nhân hóa' : 'Personalized',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SonicTokens.primaryRed,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: SonicTokens.surfaceContainer,
                          backgroundImage: (c.avatarUrl != null &&
                                  c.avatarUrl!.isNotEmpty)
                              ? NetworkImage(c.avatarUrl!)
                              : null,
                          child: (c.avatarUrl == null || c.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person_rounded,
                                  color: SonicTokens.secondaryContainer)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 5),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ClipboardDetectedBanner extends ConsumerWidget {
  final MediaUrlMatch match;
  const _ClipboardDetectedBanner({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.activeBorderCyan),
        boxShadow: SonicTokens.cyanGlow(opacity: 0.18),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded,
              color: SonicTokens.secondaryContainer, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.type == MediaUrlType.streamPlaylist
                      ? 'Playlist Link Detected in Clipboard'
                      : 'Media Link Detected in Clipboard',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: SonicTokens.secondaryLight,
                  ),
                ),
                Text(
                  match.originalUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              ref.read(clipboardBannerProvider.notifier).dismiss();
              if (match.type == MediaUrlType.directMedia ||
                  match.type == MediaUrlType.streamItem) {
                final bundle =
                    await StreamResolver.instance.resolveTrack(match.id);
                if (bundle != null && context.mounted) {
                  await playTrackAndOpenMobile(
                    context,
                    ref,
                    bundle.track,
                    relatedForAutoQueue: bundle.relatedTracks,
                  );
                }
              } else {
                final pl =
                    await StreamResolver.instance.fetchPlaylist(match.id);
                if (pl != null && pl.tracks.isNotEmpty && context.mounted) {
                  await playTrackAndOpenMobile(
                    context,
                    ref,
                    pl.tracks.first,
                    queue: pl.tracks,
                    playlistName: pl.title,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SonicTokens.secondaryBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Play Now'),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () =>
                ref.read(clipboardBannerProvider.notifier).dismiss(),
          ),
        ],
      ),
    );
  }
}

class _MobileResumeHeroCard extends ConsumerWidget {
  final MediaTrack track;
  const _MobileResumeHeroCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onResume() => playTrackAndOpenMobile(
      context,
      ref,
      track,
      resumeAt: Duration(milliseconds: track.lastPositionMs),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
        boxShadow: SonicTokens.crimsonGlow(opacity: 0.14),
      ),
      child: Column(
        children: [
          // Tapping anywhere on the upper section immediately plays the track
          InkWell(
            onTap: onResume,
            borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        TrackArtwork(
                          url: track.thumbnailUrl,
                          width: 88,
                          height: 88,
                          radius: SonicTokens.radiusLg,
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SonicTokens.surfaceBase.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RESUME',
                              style: TextStyle(
                                color: SonicTokens.primaryTint,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: SonicTokens.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded,
                                          size: 13,
                                          color: SonicTokens.secondaryContainer),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'UNFINISHED SESSION',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: SonicTokens.secondaryLight,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: SonicTokens.textSecondary),
                                onPressed: () => ref
                                    .read(resumeCardVisibleProvider.notifier)
                                    .state = false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${track.artist} • ${track.qualityBadge}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 8, color: SonicTokens.primaryContainer),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Resumes at ${track.formattedResumePosition}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${track.formattedDuration} total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: track.progressRatio,
                    minHeight: 7,
                    backgroundColor: SonicTokens.surfaceHighest,
                    color: SonicTokens.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: SonicTokens.minTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: onResume,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SonicTokens.primaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text(
                      'Resume',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CockpitTouchButton(
                onTap: () => AddToPlaylistSheet.show(context, track),
                child: const Icon(Icons.bookmark_add_outlined),
              ),
              const SizedBox(width: 8),
              CockpitTouchButton(
                onTap: () => ImportUrlDialog.show(context),
                child: const Icon(Icons.link_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileListenAgainShelf extends ConsumerWidget {
  final List<MediaTrack> tracks;
  const _MobileListenAgainShelf({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = tracks[i];
          return InkWell(
            onTap: () => playTrackAndOpenMobile(context, ref, t),
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: Container(
              width: 152,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceCard,
                borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TrackArtwork(
                          url: t.thumbnailUrl,
                          radius: SonicTokens.radiusLg,
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: SonicTokens.surfaceBase.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.replay_rounded,
                                    size: 11,
                                    color: SonicTokens.primaryContainer),
                                const SizedBox(width: 3),
                                Text(
                                  '${t.playCount}x',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0
                                  ? SonicTokens.primaryContainer
                                  : SonicTokens.surfaceElevated,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabletResumeAndHistoryRow extends ConsumerWidget {
  final MediaTrack? resumeTrack;
  final List<MediaTrack> listenAgain;

  const _TabletResumeAndHistoryRow({
    required this.resumeTrack,
    required this.listenAgain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <Widget>[];

    if (resumeTrack != null) {
      final t = resumeTrack!;
      cards.add(
        Expanded(
          child: _ResumeTileCard(
            track: t,
            badgeText:
                'RESUME • ${t.formattedResumePosition} / ${t.formattedDuration}',
            badgeColor: SonicTokens.primaryContainer,
            showProgress: true,
            onTap: () => playTrackAndOpenMobile(
              context,
              ref,
              t,
              resumeAt: Duration(milliseconds: t.lastPositionMs),
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < 2; i++) {
      if (i < listenAgain.length) {
        final t = listenAgain[i];
        cards.add(const SizedBox(width: 16));
        cards.add(
          Expanded(
            child: _ResumeTileCard(
              track: t,
              badgeText: 'LISTENED ${t.playCount}X • RECENT',
              badgeColor: SonicTokens.secondaryContainer,
              onTap: () => playTrackAndOpenMobile(context, ref, t),
            ),
          ),
        );
      }
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Row(children: cards);
  }
}

class _ResumeTileCard extends StatelessWidget {
  final MediaTrack track;
  final String badgeText;
  final Color badgeColor;
  final bool showProgress;
  final VoidCallback onTap;

  const _ResumeTileCard({
    required this.track,
    required this.badgeText,
    required this.badgeColor,
    this.showProgress = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrackArtwork(url: track.thumbnailUrl, radius: 0),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: SonicTokens.surfaceBase,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badgeColor,
                        boxShadow: [
                          BoxShadow(
                              color: badgeColor.withOpacity(0.45),
                              blurRadius: 18)
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        track.formattedDuration,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showProgress)
              LinearProgressIndicator(
                value: track.progressRatio,
                minHeight: 4,
                backgroundColor: SonicTokens.surfaceHighest,
                color: SonicTokens.primaryRed,
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.artist} • ${track.qualityBadge}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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

class _RecommendationsGrid extends StatelessWidget {
  final List<MediaTrack> tracks;
  final int columns;

  const _RecommendationsGrid({
    required this.tracks,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.05,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, i) => _FeedMediaCard(track: tracks[i]),
    );
  }
}

class _FeedMediaCard extends ConsumerWidget {
  final MediaTrack track;
  const _FeedMediaCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => playTrackAndOpenMobile(context, ref, track),
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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrackArtwork(url: track.thumbnailUrl, radius: 0),
                  if (track.recommendationTag != null &&
                      !track.recommendationTag!.contains('Followed') &&
                      !track.recommendationTag!.contains('theo dõi') &&
                      !track.recommendationTag!.startsWith('⭐'))
                    Positioned(
                      top: 10,
                      left: 10,
                      child:
                          RecommendationTagBadge(tag: track.recommendationTag!),
                    ),
                  Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SonicTokens.secondaryBlue.withOpacity(0.92),
                        boxShadow: SonicTokens.blueGlow(),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        track.formattedDuration,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${track.artist}${track.viewCountLabel != null ? " • ${track.viewCountLabel}" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SourceBadgeChip(
                              source: track.source,
                              customLabel: track.qualityBadge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: SonicTokens.textSecondary),
                    onPressed: () => AddToPlaylistSheet.show(context, track),
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

class _FilterChipsRow extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChipsRow({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = filters[i];
          final active = f == selected;
          return InkWell(
            onTap: () => onSelected(f),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? SonicTokens.secondaryBlue
                    : SonicTokens.surfaceCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? SonicTokens.secondaryContainer
                      : SonicTokens.glassBorder,
                ),
                boxShadow: active ? SonicTokens.blueGlow(opacity: 0.28) : null,
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: active ? Colors.white : SonicTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? badgeLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.icon,
    this.badgeLabel,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: SonicTokens.secondaryContainer),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (badgeLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SonicTokens.glassBorder),
            ),
            child: Text(
              badgeLabel!,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SonicTokens.secondaryLight),
            ),
          ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Text(
              actionLabel!,
              style: const TextStyle(
                color: SonicTokens.secondaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            label: const Icon(Icons.chevron_right_rounded,
                size: 18, color: SonicTokens.secondaryContainer),
          ),
      ],
    );
  }
}

class _ByoSourceOnboardingCard extends ConsumerWidget {
  final bool hasCustomServer;

  const _ByoSourceOnboardingCard({required this.hasCustomServer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_music_rounded,
                  color: SonicTokens.secondaryContainer, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasCustomServer
                      ? 'No tracks returned from your media server yet'
                      : 'Add Your Own Media Sources',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasCustomServer
                ? 'Pull down to refresh, search for music, or import local USB & Cloud Drive files.'
                : 'Soniclane plays your own local / USB MP3 & FLAC files, personal Google Drive audio, Wi-Fi Drop uploads, direct stream URLs, or your own Custom Media Server.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(userHubSubTabProvider.notifier).state = 0;
                  ref.read(activeTabProvider.notifier).state = 2;
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SonicTokens.primaryRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.usb_rounded, size: 18),
                label: const Text('Local / USB'),
              ),
              OutlinedButton.icon(
                onPressed: () => CloudDriveModal.show(context),
                icon: const Icon(Icons.cloud_done_rounded, size: 18),
                label: const Text('Google Drive'),
              ),
              OutlinedButton.icon(
                onPressed: () => WifiTransferModal.show(context),
                icon: const Icon(Icons.wifi_rounded, size: 18),
                label: const Text('Wi-Fi Drop'),
              ),
              OutlinedButton.icon(
                onPressed: () => ImportUrlDialog.show(context),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Direct URL'),
              ),
              OutlinedButton.icon(
                onPressed: () => WebBrowserScreen.open(context),
                icon: const Icon(Icons.language_rounded, size: 18),
                label: const Text('Web Browser'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(userHubSubTabProvider.notifier).state = 1;
                  ref.read(activeTabProvider.notifier).state = 3;
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Custom Server'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
