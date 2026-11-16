import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/services/voice_search_service.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/playlists_tab_screen.dart';
import '../../features/now_playing/now_playing_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/user/user_hub_screen.dart';
import 'common_badges.dart';
import 'sonic_logo.dart';

class CockpitShell extends ConsumerStatefulWidget {
  const CockpitShell({super.key});

  @override
  ConsumerState<CockpitShell> createState() => _CockpitShellState();
}

class _CockpitShellState extends ConsumerState<CockpitShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
        () => ref.read(clipboardBannerProvider.notifier).checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardBannerProvider.notifier).checkClipboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final snap = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final motion = ref.watch(vehicleMotionProvider).valueOrNull;

    final pages = [
      const HomeScreen(), // 0
      const SearchScreen(), // 1
      const LibraryScreen(), // 2
      const SettingsScreen(), // 3
      const PlaylistsTabScreen(), // 4
      const UserHubScreen(), // 5
    ];

    final safeDesktopIdx = activeTab >= pages.length ? 0 : activeTab;

    // Support Android Back navigation + Windows Desktop media transport shortcuts
    return PopScope(
      canPop: activeTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          SonicAudioEngine.instance.stop();
          return;
        }
        if (activeTab != 0) {
          ref.read(activeTabProvider.notifier).state = 0;
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
              SonicAudioEngine.instance.togglePlayPause(),
          const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
              SonicAudioEngine.instance.skipToNext(),
          const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
              SonicAudioEngine.instance.skipToPrevious(),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
            final isDesktopOrTablet = constraints.maxWidth >= 700;
            final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            final isDetailOpen = ref.watch(cockpitSplitDetailOpenProvider) &&
                snap.currentTrack != null;

            if (isDesktopOrTablet) {
              return Scaffold(
                backgroundColor: SonicTokens.surfaceBase,
                body: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: Row(
                    children: [
                      _LeftCockpitRail(
                        activeIndex: activeTab,
                        onSelect: (i) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          ref.read(activeTabProvider.notifier).state = i;
                          if (i == 1) {
                            ref.read(searchFocusTriggerProvider.notifier).state++;
                          }
                        },
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                _TopCockpitHeader(
                                  isParked: motion?.isParked ?? true,
                                  showLogoWordmark: true,
                                  isMobileMode: false,
                                  activeTab: activeTab,
                                  onHome: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    ref.read(activeTabProvider.notifier).state = 0;
                                  },
                                  onSearchTap: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    ref.read(activeTabProvider.notifier).state = 1;
                                    ref
                                        .read(searchFocusTriggerProvider.notifier)
                                        .state++;
                                  },
                                  onSettings: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    ref.read(activeTabProvider.notifier).state = 3;
                                  },
                                  onProfile: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    ref.read(activeTabProvider.notifier).state = 2;
                                  },
                                ),
                                Expanded(
                                  child: isDetailOpen
                                      ? Row(
                                          children: [
                                            // 50% Left Side: Cockpit Detail Player (Video/Audio, Scrubber, Controls)
                                            Expanded(
                                              flex: 1,
                                              child: CockpitDetailPane(
                                                snap: snap,
                                                onClose: () => ref
                                                    .read(
                                                        cockpitSplitDetailOpenProvider
                                                            .notifier)
                                                    .state = false,
                                                onOpenFullscreen: () =>
                                                    NowPlayingScreen.open(
                                                        context),
                                              ),
                                            ),
                                            // 50% Right Side: Playlist / Search / Home / Library Page
                                            Expanded(
                                              flex: 1,
                                              child: IndexedStack(
                                                index: safeDesktopIdx,
                                                children: pages,
                                              ),
                                            ),
                                          ],
                                        )
                                      : IndexedStack(
                                          index: safeDesktopIdx,
                                          children: pages,
                                        ),
                                ),
                              ],
                            ),
                            if (snap.statusBanner != null && !isKeyboardOpen)
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: (!isDetailOpen && snap.currentTrack != null)
                                    ? 96
                                    : 16,
                                child: _StatusAlertBanner(
                                  message: snap.statusBanner!,
                                  onTapSettings: () {
                                    SonicAudioEngine.instance.clearStatusBanner();
                                    ref.read(activeTabProvider.notifier).state = 3;
                                  },
                                  onClose: () => SonicAudioEngine.instance
                                      .clearStatusBanner(),
                                ),
                              ),
                            if (!isDetailOpen &&
                                snap.currentTrack != null &&
                                !isKeyboardOpen)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _DockedDesktopMiniPlayer(
                                  snap: snap,
                                  onOpenSplit: () => ref
                                      .read(
                                          cockpitSplitDetailOpenProvider.notifier)
                                      .state = true,
                                  onOpenFull: () =>
                                      NowPlayingScreen.open(context),
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

            // Mobile Portrait Layout (No 3-Tab Bottom Nav; Logo -> Home, Search & User in Header, Mini-Player docked at Bottom)
            const mobilePages = [
              HomeScreen(),
              SearchScreen(),
              UserHubScreen(),
            ];
            final mobileIdx = activeTab >= mobilePages.length ? 2 : activeTab;

            return Scaffold(
              backgroundColor: SonicTokens.surfaceBase,
              body: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _TopCockpitHeader(
                            isParked: motion?.isParked ?? true,
                            showLogoWordmark: true,
                            isMobileMode: true,
                            activeTab: mobileIdx,
                            onHome: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              ref.read(activeTabProvider.notifier).state = 0;
                            },
                            onSearchTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              ref.read(activeTabProvider.notifier).state = 1;
                              ref.read(searchFocusTriggerProvider.notifier).state++;
                            },
                            onSettings: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              ref.read(userHubSubTabProvider.notifier).state = 1;
                              ref.read(activeTabProvider.notifier).state = 2;
                            },
                            onProfile: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              ref.read(activeTabProvider.notifier).state = 2;
                            },
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: mobileIdx,
                              children: mobilePages,
                            ),
                          ),
                        ],
                      ),
                      if (snap.statusBanner != null && !isKeyboardOpen)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: (snap.currentTrack != null ? 92 : 16) +
                              MediaQuery.of(context).padding.bottom,
                          child: _StatusAlertBanner(
                            message: snap.statusBanner!,
                            onTapSettings: () {
                              SonicAudioEngine.instance.clearStatusBanner();
                              ref.read(userHubSubTabProvider.notifier).state = 1;
                              ref.read(activeTabProvider.notifier).state = 2;
                            },
                            onClose: () =>
                                SonicAudioEngine.instance.clearStatusBanner(),
                          ),
                        ),
                      // Docked Floating Mini-Player replacing Bottom Nav Bar (hidden if no track loaded OR keyboard open)
                      if (snap.currentTrack != null && !isKeyboardOpen)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12 + MediaQuery.of(context).padding.bottom,
                          child: _MobileFloatingMiniPlayer(
                            snap: snap,
                            onOpenFull: () => NowPlayingScreen.open(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _TopCockpitHeader extends ConsumerStatefulWidget {
  final bool isParked;
  final bool showLogoWordmark;
  final bool isMobileMode;
  final int activeTab;
  final VoidCallback onHome;
  final VoidCallback onSearchTap;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  const _TopCockpitHeader({
    required this.isParked,
    required this.showLogoWordmark,
    required this.isMobileMode,
    required this.activeTab,
    required this.onHome,
    required this.onSearchTap,
    required this.onSettings,
    required this.onProfile,
  });

  @override
  ConsumerState<_TopCockpitHeader> createState() => _TopCockpitHeaderState();
}

class _TopCockpitHeaderState extends ConsumerState<_TopCockpitHeader> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    if (widget.activeTab != 1) {
      ref.read(activeTabProvider.notifier).state = 1;
    }
    ref.read(searchProvider.notifier).executeSearch(query);
  }

  Future<void> _triggerVoiceSearch() async {
    ref.read(activeTabProvider.notifier).state = 1;
    final isVoiceOpen = ref.read(searchProvider).isVoiceHudOpen;
    final next = !isVoiceOpen;
    ref.read(searchProvider.notifier).setVoiceHud(next);
    if (next) {
      await VoiceSearchService.instance.startListening(
        onFinalResult: (spoken) {
          ref.read(searchProvider.notifier).setVoiceHud(false);
          _searchCtrl.text = spoken;
          ref.read(searchProvider.notifier).executeSearch(spoken);
        },
      );
    } else {
      await VoiceSearchService.instance.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobileMode) {
      // Mobile Portrait Header: Logo on left, Search and Profile on right
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceLowest.withOpacity(0.92),
          border: const Border(
            bottom: BorderSide(color: SonicTokens.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: widget.onHome,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: SonicLogo(size: 32, showWordmark: true),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Search',
              onPressed: widget.onSearchTap,
              icon: Icon(
                Icons.search_rounded,
                size: 26,
                color: widget.activeTab == 1
                    ? SonicTokens.secondaryContainer
                    : SonicTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.activeTab == 2
                      ? SonicTokens.secondaryBlue.withOpacity(0.28)
                      : SonicTokens.surfaceElevated,
                  border: Border.all(
                    color: widget.activeTab == 2
                        ? SonicTokens.secondaryContainer
                        : SonicTokens.glassBorder,
                  ),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: SonicTokens.primaryTint, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    // Landscape / Widescreen Cockpit Header:
    // No logo/name (in left rail), no status pills, center Search input bar, right Voice search mic button
    final searchQuery = ref.watch(searchProvider).query;
    if (_searchCtrl.text.isEmpty && searchQuery.isNotEmpty) {
      _searchCtrl.text = searchQuery;
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceLowest.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: SonicTokens.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Center Search Input
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.activeTab == 1
                      ? SonicTokens.activeBorderCyan
                      : SonicTokens.glassBorder,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: SonicTokens.secondaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Tìm kiếm bài hát, ca sĩ, danh sách phát...',
                        hintStyle: TextStyle(
                          color: SonicTokens.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                      onSubmitted: _triggerSearch,
                      onTap: () {
                        if (widget.activeTab != 1) {
                          ref.read(activeTabProvider.notifier).state = 1;
                        }
                      },
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: SonicTokens.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        _triggerSearch('');
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Far Right Voice Search Mic Button
          InkWell(
            onTap: _triggerVoiceSearch,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: SonicTokens.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
                boxShadow: SonicTokens.cyanGlow(opacity: 0.35),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: SonicTokens.surfaceBase,
                    size: 22,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tìm giọng nói',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SonicTokens.surfaceBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftCockpitRail extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const _LeftCockpitRail({
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SonicTokens.railWidth,
      decoration: const BoxDecoration(
        color: SonicTokens.surfaceLowest,
        border: Border(right: BorderSide(color: SonicTokens.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // 1. Logo và tên ở trên cùng (Bấm vào để về Trang chủ / Home)
          InkWell(
            onTap: () => onSelect(0),
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: Tooltip(
              message: 'Trang chủ (Home)',
              child: Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: activeIndex == 0 ? SonicTokens.surfaceHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                  border: activeIndex == 0
                      ? Border.all(color: SonicTokens.activeBorderCyan)
                      : null,
                  boxShadow: activeIndex == 0
                      ? SonicTokens.cyanGlow(opacity: 0.2)
                      : null,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SonicLogo(size: 40, showWordmark: false),
                    SizedBox(height: 6),
                    Text(
                      'SONICLANE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: SonicTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 2. Thư viện
          _RailItem(
            icon: Icons.video_library_rounded,
            label: 'LIBRARY',
            active: activeIndex == 2,
            onTap: () => onSelect(2),
          ),
          const SizedBox(height: 10),
          // 3. Playlist
          _RailItem(
            icon: Icons.queue_music_rounded,
            label: 'PLAYLIST',
            active: activeIndex == 4,
            onTap: () => onSelect(4),
          ),
          const SizedBox(height: 10),
          // 4. Setting (Cài đặt)
          _RailItem(
            icon: Icons.settings_rounded,
            label: 'SETTINGS',
            active: activeIndex == 3,
            onTap: () => onSelect(3),
          ),
          const Spacer(),
          // 5. Dưới cùng là icon User
          InkWell(
            onTap: () => onSelect(5),
            borderRadius: BorderRadius.circular(999),
            child: Tooltip(
              message: 'Driver Profile • Tài khoản',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeIndex == 5
                      ? SonicTokens.secondaryBlue.withOpacity(0.28)
                      : SonicTokens.surfaceElevated,
                  border: Border.all(
                    color: activeIndex == 5
                        ? SonicTokens.secondaryContainer
                        : SonicTokens.glassBorder,
                    width: activeIndex == 5 ? 2 : 1,
                  ),
                  boxShadow: activeIndex == 5
                      ? SonicTokens.cyanGlow(opacity: 0.25)
                      : null,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: SonicTokens.primaryTint,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
      child: Container(
        width: 66,
        height: 64,
        decoration: BoxDecoration(
          color: active ? SonicTokens.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          border: active
              ? Border.all(color: SonicTokens.activeBorderCyan)
              : null,
          boxShadow: active ? SonicTokens.cyanGlow(opacity: 0.2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: active
                  ? SonicTokens.secondaryContainer
                  : SonicTokens.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active
                    ? SonicTokens.secondaryContainer
                    : SonicTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileFloatingMiniPlayer extends StatelessWidget {
  final PlaybackSnapshot snap;
  final VoidCallback onOpenFull;

  const _MobileFloatingMiniPlayer({
    required this.snap,
    required this.onOpenFull,
  });

  @override
  Widget build(BuildContext context) {
    final track = snap.currentTrack;
    final artUrl = track?.thumbnailUrl ?? '';
    final maxMs = snap.duration.inMilliseconds > 0
        ? snap.duration.inMilliseconds.toDouble()
        : 1.0;
    final valMs = snap.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return GestureDetector(
      onTap: onOpenFull,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          SonicAudioEngine.instance.skipToNext();
        } else if ((details.primaryVelocity ?? 0) > 200) {
          SonicAudioEngine.instance.skipToPrevious();
        }
      },
      child: Container(
        height: 70,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SonicTokens.surfaceElevated.withOpacity(0.97),
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          border: Border.all(color: SonicTokens.activeBorderBlue),
          boxShadow: SonicTokens.blueGlow(opacity: 0.25),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    TrackArtwork(
                      url: artUrl,
                      width: 48,
                      height: 48,
                      fallbackIcon: Icons.album_rounded,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? 'Cockpit Stream Ready',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            track != null
                                ? track.artist
                                : 'Tap any track or paste link',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SonicTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => SonicAudioEngine.instance.skipToPrevious(),
                      icon: const Icon(Icons.skip_previous_rounded, size: 26),
                    ),
                    InkWell(
                      onTap: () => SonicAudioEngine.instance.togglePlayPause(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SonicTokens.primaryContainer,
                          boxShadow: SonicTokens.crimsonGlow(opacity: 0.4),
                        ),
                        child: Icon(
                          snap.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => SonicAudioEngine.instance.skipToNext(),
                      icon: const Icon(Icons.skip_next_rounded, size: 26),
                    ),
                  ],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: track == null ? 0 : valMs / maxMs,
              minHeight: 2.5,
              backgroundColor: SonicTokens.surfaceHighest,
              color: SonicTokens.primaryRed,
            ),
          ],
        ),
      ),
    );
  }
}

class _DockedDesktopMiniPlayer extends StatelessWidget {
  final PlaybackSnapshot snap;
  final VoidCallback onOpenFull;
  final VoidCallback? onOpenSplit;

  const _DockedDesktopMiniPlayer({
    required this.snap,
    required this.onOpenFull,
    this.onOpenSplit,
  });

  @override
  Widget build(BuildContext context) {
    final track = snap.currentTrack;
    final maxMs = snap.duration.inMilliseconds > 0
        ? snap.duration.inMilliseconds.toDouble()
        : 1.0;
    final valMs = snap.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: SonicTokens.surfaceLow,
        border: Border(top: BorderSide(color: SonicTokens.divider)),
      ),
      child: Row(
        children: [
          // Left: Track Info + Source Badge (Click to open split detail player)
          InkWell(
            onTap: onOpenSplit ?? onOpenFull,
            borderRadius: BorderRadius.circular(12),
            child: Tooltip(
              message: 'Mở chi tiết (Split View)',
              child: SizedBox(
                width: 280,
                child: Row(
                  children: [
                    TrackArtwork(
                      url: track?.thumbnailUrl ?? '',
                      width: 54,
                      height: 54,
                      fallbackIcon: Icons.album_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? 'Cockpit Stream Deck',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (track != null)
                                SourceBadgeChip(source: track.source),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  track?.artist ?? 'High-Fidelity Audio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: SonicTokens.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Center: Interactive Timeline Scrubber
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    MediaTrack.formatSeconds(snap.position.inSeconds),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: valMs,
                      min: 0,
                      max: maxMs,
                      onChanged: (v) => SonicAudioEngine.instance
                          .seekTo(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(
                    MediaTrack.formatSeconds(snap.duration.inSeconds),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          // Right: Controls + Full Player Button
          Row(
            children: [
              Tooltip(
                message: 'Previous (← / Media Prev)',
                child: CockpitTouchButton(
                  minSize: 48,
                  backgroundColor: Colors.transparent,
                  onTap: () => SonicAudioEngine.instance.skipToPrevious(),
                  child: const Icon(Icons.skip_previous_rounded, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: snap.isPlaying ? 'Pause (Space)' : 'Play (Space)',
                child: InkWell(
                  onTap: () => SonicAudioEngine.instance.togglePlayPause(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SonicTokens.primaryContainer,
                      boxShadow: SonicTokens.crimsonGlow(opacity: 0.4),
                    ),
                    child: Icon(
                      snap.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Next (→ / Media Next)',
                child: CockpitTouchButton(
                  minSize: 48,
                  backgroundColor: Colors.transparent,
                  onTap: () => SonicAudioEngine.instance.skipToNext(),
                  child: const Icon(Icons.skip_next_rounded, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 46,
                child: Tooltip(
                  message: 'Expand Full Cockpit Player (F)',
                  child: OutlinedButton.icon(
                    onPressed: onOpenFull,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: SonicTokens.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_full_rounded,
                        size: 16, color: SonicTokens.secondaryContainer),
                    label: const Text('Full Player ↗'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusAlertBanner extends StatelessWidget {
  final String message;
  final VoidCallback onTapSettings;
  final VoidCallback onClose;

  const _StatusAlertBanner({
    required this.message,
    required this.onTapSettings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapSettings,
        borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SonicTokens.surfaceElevated,
            borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
            border: Border.all(
              color: SonicTokens.warningAmber.withOpacity(0.65),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: SonicTokens.warningAmber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: SonicTokens.textSecondary),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
