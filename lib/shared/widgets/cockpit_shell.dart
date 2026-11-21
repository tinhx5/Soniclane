import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/media_source_service.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/playlists_tab_screen.dart';
import '../../features/now_playing/now_playing_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/user/user_hub_screen.dart';
import '../../features/overlays/playlist_modals.dart';
import 'common_badges.dart';
import 'sonic_logo.dart';
import 'top_cockpit_header.dart';

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
    final userHubSubTab = ref.watch(userHubSubTabProvider);
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
            final shortestSide = MediaQuery.sizeOf(context).shortestSide;
            final isDesktopOrTablet =
                shortestSide >= 600 && constraints.maxWidth >= 700;
            final viewInset = MediaQuery.viewInsetsOf(context).bottom;
            final hasKeyboard = viewInset > 40 ||
                (WidgetsBinding.instance.platformDispatcher.views.isNotEmpty &&
                    WidgetsBinding.instance.platformDispatcher.views.first
                            .viewInsets.bottom >
                        40);
            final isTyping = FocusManager.instance.primaryFocus?.context?.widget
                is EditableText;
            final isKeyboardOpen = hasKeyboard || isTyping;
            final isDetailOpen = ref.watch(cockpitSplitDetailOpenProvider) &&
                snap.currentTrack != null;
            final isVideoFullscreen = ref.watch(cockpitVideoFullscreenProvider) &&
                isDetailOpen &&
                snap.isVideoMode;

            if (isDesktopOrTablet) {
              return Scaffold(
                backgroundColor: SonicTokens.surfaceBase,
                body: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: Row(
                    children: [
                      if (!isVideoFullscreen)
                        _LeftCockpitRail(
                        activeIndex: activeTab,
                        userHubSubTab: userHubSubTab,
                        onSelect: (i) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          ref.read(cockpitVideoFullscreenProvider.notifier).state = false;
                          if (i == 2) {
                            ref.read(userHubSubTabProvider.notifier).state = 0;
                            ref.read(activeTabProvider.notifier).state = 5;
                            ref
                                .read(cockpitSplitDetailOpenProvider.notifier)
                                .state = false;
                            return;
                          }
                          if (i == 3) {
                            ref.read(userHubSubTabProvider.notifier).state = 1;
                            ref.read(activeTabProvider.notifier).state = 5;
                            ref
                                .read(cockpitSplitDetailOpenProvider.notifier)
                                .state = false;
                            return;
                          }
                          if (i == 0) {
                            ref.read(homeVisitCountProvider.notifier).state++;
                            if (ref.read(homeVisitCountProvider) > 1) {
                              MediaSourceService.instance.dismissHomeAddSource();
                              ref.read(homeAddSourceVisibleProvider.notifier).state = false;
                            }
                          } else {
                            ref.read(homeVisitCountProvider.notifier).state++;
                          }
                          ref.read(activeTabProvider.notifier).state = i;
                          if (i == 5) {
                            ref
                                .read(cockpitSplitDetailOpenProvider.notifier)
                                .state = false;
                          }
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
                                if (!isVideoFullscreen && safeDesktopIdx != 5 && safeDesktopIdx != 3)
                                  TopCockpitHeader(
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
                                      ref.read(userHubSubTabProvider.notifier).state = 1;
                                      ref.read(activeTabProvider.notifier).state = 5;
                                    },
                                    onProfile: () {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                      ref.read(userHubSubTabProvider.notifier).state = 0;
                                      ref.read(activeTabProvider.notifier).state = 5;
                                    },
                                  ),
                                Expanded(
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    fit: StackFit.expand,
                                    children: [
                                      IndexedStack(
                                        index: safeDesktopIdx,
                                        children: pages,
                                      ),
                                      Positioned.fill(
                                        child: Visibility(
                                          visible: isDetailOpen,
                                          maintainState: true,
                                          child: Container(
                                            color: SonicTokens.surfaceBase,
                                            child: Row(
                                              children: [
                                                // Left Side: Cockpit Detail Player (Video/Audio, Scrubber, Controls)
                                                Expanded(
                                                  flex: 1,
                                                  child: CockpitDetailPane(
                                                    snap: snap,
                                                    isFullscreen: isVideoFullscreen,
                                                    onToggleFullscreen: () =>
                                                        ref
                                                            .read(cockpitVideoFullscreenProvider.notifier)
                                                            .state = !isVideoFullscreen,
                                                    onClose: () {
                                                      ref
                                                          .read(cockpitVideoFullscreenProvider.notifier)
                                                          .state = false;
                                                      ref
                                                          .read(cockpitSplitDetailOpenProvider.notifier)
                                                          .state = false;
                                                    },
                                                    onOpenFullscreen: () =>
                                                        ref
                                                            .read(cockpitVideoFullscreenProvider.notifier)
                                                            .state = !isVideoFullscreen,
                                                  ),
                                                ),
                                                // Right Side: Clean 1-Row Track List (Playlist / Search Results / Smart Recommendations)
                                                if (!isVideoFullscreen)
                                                  Expanded(
                                                    flex: 1,
                                                    child: Container(
                                                      decoration: const BoxDecoration(
                                                        border: Border(
                                                          left: BorderSide(
                                                            color: SonicTokens.divider,
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: CockpitSplitTrackList(
                                                        snap: snap,
                                                        activeTab: safeDesktopIdx,
                                                        onClose: () {
                                                          ref
                                                              .read(cockpitVideoFullscreenProvider.notifier)
                                                              .state = false;
                                                          ref
                                                              .read(cockpitSplitDetailOpenProvider.notifier)
                                                              .state = false;
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                ),
                              ),
                              ],
                            ),
                            if (snap.statusBanner != null && !isKeyboardOpen && !isVideoFullscreen)
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: (!isDetailOpen &&
                                        snap.currentTrack != null &&
                                        safeDesktopIdx != 5 &&
                                        safeDesktopIdx != 3)
                                    ? 96
                                    : 16,
                                child: _StatusAlertBanner(
                                  message: snap.statusBanner!,
                                  onTapSettings: () {
                                    SonicAudioEngine.instance.clearStatusBanner();
                                    ref.read(userHubSubTabProvider.notifier).state = 1;
                                    ref.read(activeTabProvider.notifier).state = 5;
                                  },
                                  onClose: () => SonicAudioEngine.instance
                                      .clearStatusBanner(),
                                ),
                              ),
                            if (!isDetailOpen &&
                                snap.currentTrack != null &&
                                !isKeyboardOpen &&
                                safeDesktopIdx != 5 &&
                                safeDesktopIdx != 3)
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
                                  onOpenFull: () {
                                    NowPlayingScreen.open(context);
                                    if (snap.isPlaying) {
                                      WebVideoManager.instance.controller?.runJavaScript(
                                          "try { window._slShouldPlay = true; var v = document.querySelector('video'); if (v && v.paused) v.play(); } catch(e){}");
                                      Future.delayed(const Duration(milliseconds: 260), () {
                                        WebVideoManager.instance.controller?.runJavaScript(
                                            "try { window._slShouldPlay = true; var v = document.querySelector('video'); if (v && v.paused) v.play(); } catch(e){}");
                                      });
                                    }
                                  },
                                  onClose: () {
                                    ref
                                        .read(
                                            cockpitSplitDetailOpenProvider.notifier)
                                        .state = false;
                                    SonicAudioEngine.instance.stop(dismiss: true);
                                  },
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
            final isMobileFullOpen =
                ref.watch(mobileFullPlayerOpenProvider) && snap.currentTrack != null;

            return Scaffold(
              backgroundColor: SonicTokens.surfaceBase,
              body: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Column(
                        children: [
                          if (mobileIdx != 2)
                            TopCockpitHeader(
                              isParked: motion?.isParked ?? true,
                              showLogoWordmark: true,
                              isMobileMode: true,
                              activeTab: mobileIdx,
                              onHome: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                ref.read(homeVisitCountProvider.notifier).state++;
                                if (ref.read(homeVisitCountProvider) > 1) {
                                  MediaSourceService.instance.dismissHomeAddSource();
                                  ref.read(homeAddSourceVisibleProvider.notifier).state = false;
                                }
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
                          bottom: ((snap.currentTrack != null && mobileIdx != 2)
                                  ? 92
                                  : 16) +
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
                      // Docked Floating Mini-Player replacing Bottom Nav Bar (hidden if no track loaded OR keyboard open OR in User Hub OR full player open)
                      if (snap.currentTrack != null &&
                          !isKeyboardOpen &&
                          mobileIdx != 2 &&
                          !isMobileFullOpen)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12 + MediaQuery.of(context).padding.bottom,
                          child: _MobileFloatingMiniPlayer(
                            snap: snap,
                            onOpenFull: () {
                              ref
                                  .read(mobileFullPlayerOpenProvider.notifier)
                                  .state = true;
                              if (snap.isPlaying) {
                                WebVideoManager.instance.controller?.runJavaScript(
                                    "try { window._slShouldPlay = true; var v = document.querySelector('video'); if (v && v.paused) v.play(); } catch(e){}");
                                Future.delayed(const Duration(milliseconds: 260), () {
                                  WebVideoManager.instance.controller?.runJavaScript(
                                      "try { window._slShouldPlay = true; var v = document.querySelector('video'); if (v && v.paused) v.play(); } catch(e){}");
                                });
                              }
                            },
                            onClose: () {
                              ref
                                  .read(mobileFullPlayerOpenProvider.notifier)
                                  .state = false;
                              SonicAudioEngine.instance.stop(dismiss: true);
                            },
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !isMobileFullOpen,
                          child: AnimatedSlide(
                            offset: isMobileFullOpen
                                ? Offset.zero
                                : const Offset(0, 1.0),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: PopScope(
                              canPop: !isMobileFullOpen,
                              onPopInvokedWithResult: (didPop, result) {
                                if (!didPop && isMobileFullOpen) {
                                  ref
                                      .read(mobileFullPlayerOpenProvider.notifier)
                                      .state = false;
                                }
                              },
                              child: const NowPlayingScreen(),
                            ),
                          ),
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

class _LeftCockpitRail extends StatelessWidget {
  final int activeIndex;
  final int userHubSubTab;
  final ValueChanged<int> onSelect;

  const _LeftCockpitRail({
    required this.activeIndex,
    required this.userHubSubTab,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // 1. Logo và tên ở trên cùng (Bấm vào để về Trang chủ / Home - không viền bao quanh)
          InkWell(
            onTap: () => onSelect(0),
            borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
            child: const Tooltip(
              message: 'Trang chủ (Home)',
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SonicLogo(size: 30, showWordmark: false),
                    SizedBox(height: 4),
                    Text(
                      'Soniclane',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: SonicTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 2. Thư viện
          _RailItem(
            icon: Icons.video_library_rounded,
            label: 'Library',
            active: activeIndex == 2 || (activeIndex == 5 && userHubSubTab == 0),
            onTap: () => onSelect(2),
          ),
          const SizedBox(height: 8),
          // 3. Playlist
          _RailItem(
            icon: Icons.queue_music_rounded,
            label: 'Playlist',
            active: activeIndex == 4,
            onTap: () => onSelect(4),
          ),
          const SizedBox(height: 8),
          // 4. Setting (Cài đặt)
          _RailItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            active: activeIndex == 3 || (activeIndex == 5 && userHubSubTab == 1),
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
                width: 38,
                height: 38,
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
                  size: 20,
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
        width: 58,
        height: 52,
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
              size: 20,
              color: active
                  ? SonicTokens.secondaryContainer
                  : SonicTokens.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
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
  final VoidCallback? onClose;

  const _MobileFloatingMiniPlayer({
    required this.snap,
    required this.onOpenFull,
    this.onClose,
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
                    IconButton(
                      tooltip: 'Đóng trình phát',
                      onPressed: () {
                        if (onClose != null) {
                          onClose!();
                        } else {
                          SonicAudioEngine.instance.stop(dismiss: true);
                        }
                      },
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: SonicTokens.textSecondary),
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
  final VoidCallback? onClose;

  const _DockedDesktopMiniPlayer({
    required this.snap,
    required this.onOpenFull,
    this.onOpenSplit,
    this.onClose,
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
          // Left: Track Info + Source Badge (Click to open full player)
          InkWell(
            onTap: onOpenFull,
            borderRadius: BorderRadius.circular(12),
            child: Tooltip(
              message: 'Mở toàn màn hình (Full Player)',
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
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Đóng trình phát',
                onPressed: onClose ??
                    () => SonicAudioEngine.instance.stop(dismiss: true),
                icon: const Icon(Icons.close_rounded,
                    size: 22, color: SonicTokens.textSecondary),
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

/// Clean 1-track-per-row companion list for split cockpit mode (tablet/landscape).
/// Displays playlist tracks, search results, or smart recommendations without any
/// bulky filter chips or "Resume & Listen Again" cards.
class CockpitSplitTrackList extends ConsumerWidget {
  final PlaybackSnapshot snap;
  final int activeTab;
  final VoidCallback onClose;

  const CockpitSplitTrackList({
    super.key,
    required this.snap,
    required this.activeTab,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchProvider);
    final home = ref.watch(homeFeedProvider);

    List<MediaTrack> tracks = [];
    String title = 'BÀI HÁT ĐỀ XUẤT';
    IconData icon = Icons.auto_awesome_rounded;

    final isSearchMode = activeTab == 1;

    if (isSearchMode) {
      tracks = search.results;
      title = search.isSearching ? 'ĐANG TÌM KIẾM...' : 'KẾT QUẢ TÌM KIẾM';
      icon = Icons.search_rounded;
    } else if (snap.queue.isNotEmpty) {
      tracks = snap.queue;
      title = (snap.activePlaylistName != null &&
              snap.activePlaylistName!.isNotEmpty)
          ? snap.activePlaylistName!.toUpperCase()
          : 'DANH SÁCH PHÁT';
      icon = Icons.queue_music_rounded;
    } else if (home.recommendations.isNotEmpty) {
      tracks = home.recommendations;
      title = 'GỢI Ý THÔNG MINH';
      icon = Icons.auto_awesome_rounded;
    } else if (snap.habitSuggestions.isNotEmpty) {
      tracks = snap.habitSuggestions;
      title = 'GỢI Ý THÔNG MINH';
      icon = Icons.auto_awesome_rounded;
    }

    final currentId = snap.currentTrack?.id;

    return Container(
      color: SonicTokens.surfaceBase,
      child: Column(
        children: [
          // Header Bar (height: 42)
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceLowest.withOpacity(0.92),
              border: const Border(
                bottom: BorderSide(color: SonicTokens.divider, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: SonicTokens.secondaryContainer),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: SonicTokens.secondaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                if (isSearchMode && search.isSearching) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SonicTokens.secondaryContainer,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SonicTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SonicTokens.glassBorder),
                    ),
                    child: Text(
                      '${tracks.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SonicTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Đóng danh sách chia đôi',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: SonicTokens.textSecondary),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          // Single-Track-Per-Row List
          Expanded(
            child: isSearchMode && search.isSearching
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: SonicTokens.secondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          search.query.isNotEmpty
                              ? 'Đang tìm kiếm "${search.query}"...'
                              : 'Đang tìm kiếm...',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SonicTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : (tracks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSearchMode
                                    ? Icons.search_off_rounded
                                    : Icons.queue_music_rounded,
                                size: 36,
                                color:
                                    SonicTokens.textTertiary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isSearchMode
                                    ? (search.query.isNotEmpty
                                        ? 'Không tìm thấy kết quả cho "${search.query}"'
                                        : 'Nhập từ khóa hoặc link để tìm kiếm')
                                    : 'Chưa có bài hát trong danh sách',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SonicTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final item = tracks[index];
                      final isCurrent = item.id == currentId;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? SonicTokens.secondaryBlue.withOpacity(0.18)
                              : SonicTokens.surfaceLowest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? SonicTokens.secondaryContainer.withOpacity(0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            await SonicAudioEngine.instance.playTrack(
                              item,
                              queue: tracks,
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                // Thumbnail (16:9 ratio, compact 50x32)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 50,
                                        height: 32,
                                        child: TrackArtwork(
                                          url: item.thumbnailUrl,
                                          width: 50,
                                          height: 32,
                                          fallbackIcon:
                                              Icons.music_note_rounded,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.45),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            snap.isPlaying
                                                ? Icons.graphic_eq_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 16,
                                            color: SonicTokens.secondaryContainer,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                // Title and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent
                                              ? SonicTokens.secondaryContainer
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.artist.isNotEmpty
                                            ? item.artist
                                            : 'Soniclane',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: SonicTokens.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Duration
                                if (item.durationSeconds > 0)
                                  Text(
                                    item.formattedDuration,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: SonicTokens.textTertiary,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                // Options Menu
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: SonicTokens.textSecondary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      AddToPlaylistSheet.show(context, item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )),
          ),
        ],
      ),
    );
  }
}
