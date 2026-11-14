import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/services/stream_resolver.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
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

    const pages = [
      HomeScreen(),
      SearchScreen(),
      LibraryScreen(),
      SettingsScreen(),
    ];

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

            if (isDesktopOrTablet) {
              return Scaffold(
                backgroundColor: SonicTokens.surfaceBase,
                body: Row(
                  children: [
                    _LeftCockpitRail(
                      activeIndex: activeTab,
                      onSelect: (i) {
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
                                onHome: () => ref
                                    .read(activeTabProvider.notifier)
                                    .state = 0,
                                onSearchTap: () {
                                  ref.read(activeTabProvider.notifier).state = 1;
                                  ref
                                      .read(searchFocusTriggerProvider.notifier)
                                      .state++;
                                },
                                onSettings: () => ref
                                    .read(activeTabProvider.notifier)
                                    .state = 3,
                                onProfile: () =>
                                    ref.read(activeTabProvider.notifier).state = 2,
                              ),
                              Expanded(
                                child: IndexedStack(
                                  index: activeTab,
                                  children: pages,
                                ),
                              ),
                            ],
                          ),
                          if (snap.statusBanner != null)
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 96,
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
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _DockedDesktopMiniPlayer(
                              snap: snap,
                              onOpenFull: () => NowPlayingScreen.open(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              body: SafeArea(
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
                          onHome: () =>
                              ref.read(activeTabProvider.notifier).state = 0,
                          onSearchTap: () {
                            ref.read(activeTabProvider.notifier).state = 1;
                            ref.read(searchFocusTriggerProvider.notifier).state++;
                          },
                          onSettings: () {
                            ref.read(userHubSubTabProvider.notifier).state = 1;
                            ref.read(activeTabProvider.notifier).state = 2;
                          },
                          onProfile: () =>
                              ref.read(activeTabProvider.notifier).state = 2,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: mobileIdx,
                            children: mobilePages,
                          ),
                        ),
                      ],
                    ),
                    if (snap.statusBanner != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 92 + MediaQuery.of(context).padding.bottom,
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
                    // Docked Floating Mini-Player replacing Bottom Nav Bar
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
            );
          },
        ),
      ),
      ),
    );
  }
}

class _TopCockpitHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final instances = ref.watch(serverInstancesProvider);
    final activeInst = instances.isNotEmpty
        ? instances.first
        : StreamResolver.instance.activeInstance;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 520;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceLowest.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: SonicTokens.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: SonicLogo(size: 34, showWordmark: showLogoWordmark),
            ),
          ),
          const Spacer(),
          if (!isCompact) ...[
            // Custom Media Server Status Pill
            InkWell(
              onTap: onSettings,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SonicTokens.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: activeInst == null
                          ? SonicTokens.secondaryContainer
                          : (activeInst.isHealthy
                              ? SonicTokens.successGreen
                              : SonicTokens.warningAmber),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeInst != null
                          ? (activeInst.isHealthy
                              ? '${activeInst.name} ${activeInst.latencyMs ?? 0}ms'
                              : '${activeInst.name} (${activeInst.tier})')
                          : 'Local & Cloud Ready',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SonicTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // P-Gear Video Ready Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isParked
                      ? SonicTokens.activeBorderCyan
                      : SonicTokens.warningAmber.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isParked
                        ? Icons.local_parking_rounded
                        : Icons.directions_car_rounded,
                    size: 15,
                    color: isParked
                        ? SonicTokens.secondaryContainer
                        : SonicTokens.warningAmber,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isParked ? 'P-GEAR • VIDEO READY' : 'IN MOTION • AUDIO SAFE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isParked
                          ? SonicTokens.secondaryLight
                          : SonicTokens.warningAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (isMobileMode) ...[
            IconButton(
              tooltip: 'Search',
              onPressed: onSearchTap,
              icon: Icon(
                Icons.search_rounded,
                size: 26,
                color: activeTab == 1
                    ? SonicTokens.secondaryContainer
                    : SonicTokens.textSecondary,
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined,
                  color: SonicTokens.textSecondary),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isMobileMode && activeTab == 2)
                    ? SonicTokens.secondaryBlue.withOpacity(0.28)
                    : SonicTokens.surfaceElevated,
                border: Border.all(
                  color: (isMobileMode && activeTab == 2)
                      ? SonicTokens.secondaryContainer
                      : SonicTokens.glassBorder,
                ),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: SonicTokens.primaryTint, size: 22),
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
          const SonicLogo(size: 44, showWordmark: false),
          const SizedBox(height: 6),
          const Text(
            'SONICLANE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: SonicTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _RailItem(
            icon: Icons.home_rounded,
            label: 'HOME',
            active: activeIndex == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(height: 10),
          _RailItem(
            icon: Icons.search_rounded,
            label: 'SEARCH',
            active: activeIndex == 1,
            onTap: () => onSelect(1),
          ),
          const SizedBox(height: 10),
          _RailItem(
            icon: Icons.video_library_rounded,
            label: 'LIBRARY',
            active: activeIndex == 2,
            onTap: () => onSelect(2),
          ),
          const Spacer(),
          _RailItem(
            icon: Icons.settings_rounded,
            label: 'SETTINGS',
            active: activeIndex == 3,
            onTap: () => onSelect(3),
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

  const _DockedDesktopMiniPlayer({
    required this.snap,
    required this.onOpenFull,
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
          // Left: Track Info + Source Badge
          SizedBox(
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
              CockpitTouchButton(
                minSize: 48,
                backgroundColor: Colors.transparent,
                onTap: () => SonicAudioEngine.instance.skipToPrevious(),
                child: const Icon(Icons.skip_previous_rounded, size: 28),
              ),
              const SizedBox(width: 8),
              InkWell(
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
              const SizedBox(width: 8),
              CockpitTouchButton(
                minSize: 48,
                backgroundColor: Colors.transparent,
                onTap: () => SonicAudioEngine.instance.skipToNext(),
                child: const Icon(Icons.skip_next_rounded, size: 28),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 46,
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
