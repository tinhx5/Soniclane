import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/stream_resolver.dart';
import '../../core/services/voice_search_service.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';
import '../browser/web_browser_screen.dart';
import '../overlays/playlist_modals.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final shouldShow = pos.pixels > 350;
    if (shouldShow != _showBackToTop && mounted) {
      setState(() => _showBackToTop = shouldShow);
    }
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _scrollToTopAndFocus() {
    if (_scrollCtrl.hasClients && _scrollCtrl.offset > 0) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    _searchFocusNode.requestFocus();
  }

  static const _sourceFilters = [
    'All Sources',
    'Remote Stream',
    'In-Car USB',
    'Playlists & Mixes',
    'Local Audio',
  ];

  static const _moodChannels = [
    (
      title: 'Night Cruise Chill',
      subtitle: 'Downtempo & Ambient Beats',
      query: 'Ambient night cruise instrumental',
      color: Color(0xFF4C1D95),
      icon: Icons.nightlight_round,
    ),
    (
      title: 'High-Octane Remix',
      subtitle: 'EDM & Driving Synth 140+',
      query: 'High octane synthwave driving',
      color: Color(0xFF991B1B),
      icon: Icons.speed_rounded,
    ),
    (
      title: 'Acoustic Morning',
      subtitle: 'Acoustic & Coffee • 36 trk',
      query: 'Acoustic morning drive guitar',
      color: Color(0xFF92400E),
      icon: Icons.wb_sunny_rounded,
    ),
    (
      title: 'Cockpit Podcasts',
      subtitle: 'Tech & Auto Talks • Live',
      query: 'Vietnamese automotive tech podcast',
      color: Color(0xFF0E7490),
      icon: Icons.podcasts_rounded,
    ),
  ];

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runQuery(String q) {
    _searchCtrl.text = q;
    ref.read(searchProvider.notifier).executeSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final filteredResults = _filterBySource(search.results, search.sourceFilter);

    ref.listen<int>(searchFocusTriggerProvider, (prev, next) {
      if (prev != next && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToTopAndFocus();
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return Stack(
          children: [
            ListView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 16,
            16,
            isWide ? 24 : 16,
            108,
          ),
          children: [
            // Search Bar + Paste Link + Glowing Voice Mic
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: SonicTokens.minTouchTarget,
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceHigh,
                      borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                      border: Border.all(color: SonicTokens.glassBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: SonicTokens.secondaryContainer, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Search songs, artists, or paste link...',
                            ),
                            onSubmitted: _runQuery,
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty ||
                            search.query.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(searchProvider.notifier).executeSearch('');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CockpitTouchButton(
                  onTap: () => ImportUrlDialog.show(context),
                  backgroundColor: SonicTokens.surfaceHigh,
                  child: const Icon(Icons.link_rounded,
                      color: SonicTokens.secondaryLight, size: 24),
                ),
                const SizedBox(width: 8),
                CockpitTouchButton(
                  onTap: () async {
                    final opening = !search.isVoiceHudOpen;
                    ref.read(searchProvider.notifier).setVoiceHud(opening);
                    if (opening) {
                      await VoiceSearchService.instance.startListening(
                        onFinalResult: (spoken) {
                          ref.read(searchProvider.notifier).setVoiceHud(false);
                          _runQuery(spoken);
                        },
                      );
                    } else {
                      await VoiceSearchService.instance.stopListening();
                    }
                  },
                  backgroundColor: SonicTokens.secondaryContainer,
                  glow: SonicTokens.cyanGlow(opacity: 0.35),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.mic_rounded,
                            color: SonicTokens.surfaceBase, size: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Voice HUD Drawer with live Speech-to-Text
            if (search.isVoiceHudOpen) ...[
              const SizedBox(height: 14),
              StreamBuilder<VoiceHudState>(
                stream: VoiceSearchService.instance.stream,
                initialData: VoiceSearchService.instance.state,
                builder: (context, voiceSnap) {
                  final voice =
                      voiceSnap.data ?? VoiceSearchService.instance.state;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                      border: Border.all(color: SonicTokens.activeBorderCyan),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: voice.isListening
                                ? SonicTokens.primaryRed
                                : SonicTokens.secondaryContainer,
                          ),
                          child: const Icon(Icons.graphic_eq_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                voice.isListening
                                    ? 'LISTENING IN COCKPIT...'
                                    : 'VOICE COCKPIT READY',
                                style: const TextStyle(
                                  color: SonicTokens.secondaryContainer,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                voice.recognizedText.isNotEmpty
                                    ? '"${voice.recognizedText}"'
                                    : (voice.errorMessage ??
                                        'Speak a song title or tap a shortcut below'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            VoiceSearchService.instance.stopListening();
                            ref
                                .read(searchProvider.notifier)
                                .setVoiceHud(false);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),

            // Source Filter Chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sourceFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _sourceFilters[i];
                  final active = f == search.sourceFilter;
                  return InkWell(
                    onTap: () =>
                        ref.read(searchProvider.notifier).setSourceFilter(f),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color:
                              active ? Colors.white : SonicTokens.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Search Results State
            if (search.isSearching)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (search.query.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Results (${filteredResults.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(searchProvider.notifier).executeSearch('');
                    },
                    child: const Text('Back to Discovery'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredResults.isEmpty) ...[
                Builder(
                  builder: (context) {
                    final instances = ref.watch(serverInstancesProvider);
                    final activeInst =
                        instances.isNotEmpty ? instances.first : null;
                    final isHtmlSite = activeInst != null &&
                        !activeInst.isHealthy &&
                        activeInst.tier == 'HTML Website';

                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: SonicTokens.surfaceCard,
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusXl),
                          border: Border.all(color: SonicTokens.glassBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isHtmlSite
                                  ? '"${activeInst.name}" is an HTML website, not a JSON Media API'
                                  : (StreamResolver.instance.hasCustomServer
                                      ? 'No local or remote tracks matched "${search.query}".'
                                      : 'No local / USB tracks matched "${search.query}".'),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isHtmlSite
                                  ? 'In-App Search requires a compatible JSON Media API server (Open Media API v1 or Stream Index API).\nOr open ${activeInst.name} directly inside the In-App Web Browser.'
                                  : (StreamResolver.instance.hasCustomServer
                                      ? 'Try another search query or check your Custom Media Server status in Settings.'
                                      : 'To search online sources, paste a direct audio/video URL above or configure your Custom Media Server in Settings.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: SonicTokens.textSecondary,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (isHtmlSite)
                                  ElevatedButton.icon(
                                    onPressed: () => WebBrowserScreen.open(
                                      context,
                                      initialUrl: activeInst.url,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          SonicTokens.secondaryBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                        Icons.open_in_browser_rounded,
                                        size: 18),
                                    label: Text('Open ${activeInst.name}'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(userHubSubTabProvider.notifier)
                                        .state = 1;
                                    ref
                                        .read(activeTabProvider.notifier)
                                        .state = 3;
                                  },
                                  icon: const Icon(Icons.settings_rounded,
                                      size: 18),
                                  label:
                                      const Text('Configure Source in Settings'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]
              else ...[
                ...filteredResults.map((track) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      tileColor: SonicTokens.surfaceCard,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusXl),
                        side: const BorderSide(color: SonicTokens.glassBorder),
                      ),
                      leading: TrackArtwork(
                        url: track.thumbnailUrl,
                        width: 68,
                        height: 52,
                      ),
                      title: Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        track.durationSeconds > 0
                            ? '${track.artist} • ${track.formattedDuration}'
                            : track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        tooltip: 'Add to Playlist',
                        icon: const Icon(Icons.playlist_add_rounded,
                            color: SonicTokens.textSecondary),
                        onPressed: () => AddToPlaylistSheet.show(
                          context,
                          track,
                          preferNowPlaying: true,
                        ),
                      ),
                      onTap: () => playTrackAndOpenMobile(
                        context,
                        ref,
                        track,
                      ),
                    ),
                  );
                }),
                if (search.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
              ],
            ] else ...[
              // Recent In-Cabin Searches
              if (search.recentSearches.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded,
                              size: 18, color: SonicTokens.secondaryContainer),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Recent In-Cabin Searches',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(searchProvider.notifier).clearRecent(),
                      child: const Text(
                        'CLEAR ALL',
                        style: TextStyle(
                            color: SonicTokens.primaryTint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: search.recentSearches.map((q) {
                    return InputChip(
                      backgroundColor: SonicTokens.surfaceCard,
                      side: const BorderSide(color: SonicTokens.glassBorder),
                      avatar: const Icon(Icons.schedule_rounded,
                          size: 16, color: SonicTokens.textSecondary),
                      label: Text(q),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () =>
                          ref.read(searchProvider.notifier).removeRecent(q),
                      onPressed: () => _runQuery(q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Driving Mood Channels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded,
                            size: 18, color: SonicTokens.secondaryContainer),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Driving Mood Channels',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '4 TUNED MODES',
                    style: TextStyle(
                      color: SonicTokens.secondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.45 : 1.15,
                ),
                itemCount: _moodChannels.length,
                itemBuilder: (_, i) {
                  final ch = _moodChannels[i];
                  return InkWell(
                    onTap: () => _runQuery(ch.query),
                    borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusXl),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ch.color.withOpacity(0.85),
                            SonicTokens.surfaceCard,
                          ],
                        ),
                        border: Border.all(color: SonicTokens.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(ch.icon, color: Colors.white, size: 22),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                ch.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Voice HUD Shortcuts
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceCard,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                  border: Border.all(color: SonicTokens.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.mic_rounded,
                                  size: 16,
                                  color: SonicTokens.secondaryContainer),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'VOICE HUD SHORTCUTS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tap to Speak',
                          style: TextStyle(
                              fontSize: 12,
                              color: SonicTokens.secondaryLight,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _VoiceShortcutChip(
                          icon: Icons.play_arrow_rounded,
                          label: '"Synthwave Drive"',
                          onTap: () => _runQuery('Synthwave ambient drive'),
                        ),
                        _VoiceShortcutChip(
                          icon: Icons.shuffle_rounded,
                          label: '"Shuffle USB Drive"',
                          onTap: () {
                            final lib = ref.read(libraryProvider);
                              if (lib.localDeviceTracks.isNotEmpty) {
                                playTrackAndOpenMobile(
                                  context,
                                  ref,
                                  lib.localDeviceTracks.first,
                                  queue: lib.localDeviceTracks,
                                  playlistName: 'USB Shuffle',
                                );
                              } else {
                              _runQuery('Chill driving beats');
                            }
                          },
                        ),
                        _VoiceShortcutChip(
                          icon: Icons.trending_up_rounded,
                          label: '"Acoustic Morning"',
                          onTap: () => _runQuery('Acoustic guitar morning'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (_showBackToTop)
          Positioned(
            right: isWide ? 32 : 18,
            bottom: 116,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _scrollToTopAndFocus,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceHigh.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: SonicTokens.secondaryContainer.withOpacity(0.5),
                    ),
                    boxShadow: SonicTokens.cyanGlow(opacity: 0.25),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 18, color: SonicTokens.secondaryContainer),
                      SizedBox(width: 6),
                      Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
      },
    );
  }

  List<MediaTrack> _filterBySource(List<MediaTrack> list, String filter) {
    if (filter == 'All Sources') return list;
    if (filter == 'Remote Stream') {
      return list.where((t) => t.source == TrackSource.customStream).toList();
    }
    if (filter == 'In-Car USB') {
      return list.where((t) => t.source.isOfflineCapable).toList();
    }
    return list;
  }
}

class _VoiceShortcutChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _VoiceShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SonicTokens.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: SonicTokens.secondaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
