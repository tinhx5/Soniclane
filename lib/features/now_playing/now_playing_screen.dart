import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/services/offline_download_service.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/app_locale.dart';
import '../../shared/widgets/common_badges.dart';
import '../library/channel_detail_screen.dart';
import '../overlays/equalizer_modal.dart';
import '../overlays/playlist_modals.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  int _rightQueueTab = 0; // 0: PLAYLIST, 1: HABIT AI
  bool _isFullscreenOpen = false;
  bool _userDismissedFullscreenInLandscape = false;

  Future<void> _onToggleVideoMode(bool wantVideo, PlaybackSnapshot snap) async {
    if (wantVideo == snap.isVideoMode) return;
    if (wantVideo) {
      final settings = ref.read(settingsProvider);
      final motion = ref.read(vehicleMotionProvider).valueOrNull;
      if (settings.drivingVideoLockout &&
          motion != null &&
          motion.isMovingOverThreshold) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SonicTokens.warningAmber,
            content: Text(
              'Driving Lockout Active: Video disabled above 5 km/h for your safety.',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
        return;
      }
    }
    await SonicAudioEngine.instance.setVideoMode(wantVideo);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final settings = ref.watch(settingsProvider);
    final track = snap.currentTrack;

    final orientation = MediaQuery.orientationOf(context);
    final isMobile = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        MediaQuery.sizeOf(context).shortestSide < 600;

    if (orientation == Orientation.portrait) {
      _userDismissedFullscreenInLandscape = false;
    }

    // Auto-fullscreen when phone device rotates to landscape while in Video mode
    if (isMobile &&
        snap.isVideoMode &&
        orientation == Orientation.landscape &&
        !_isFullscreenOpen &&
        !_userDismissedFullscreenInLandscape) {
      final vc = SonicAudioEngine.instance.videoController;
      if (vc != null) {
        _isFullscreenOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _FullscreenVideoPage.open(context, vc);
          if (mounted) {
            setState(() {
              _isFullscreenOpen = false;
              if (MediaQuery.orientationOf(context) == Orientation.landscape) {
                _userDismissedFullscreenInLandscape = true;
              }
            });
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return _buildWidescreenCockpit(context, snap, settings, track);
            }
            return _buildMobilePlayer(context, snap, settings, track);
          },
        ),
      ),
    );
  }

  Widget _buildMobilePlayer(
    BuildContext context,
    PlaybackSnapshot snap,
    AppSettings settings,
    MediaTrack? track,
  ) {
    return Column(
      children: [
        // Top Header: Thu nhỏ | [ Audio | Video ] | User
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CockpitTouchButton(
                onTap: () => Navigator.of(context).pop(),
                backgroundColor: SonicTokens.surfaceCard,
                borderRadius: BorderRadius.circular(999),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              ),
              _AudioVideoTogglePill(
                isVideo: snap.isVideoMode,
                onChanged: (v) => _onToggleVideoMode(v, snap),
              ),
              InkWell(
                onTap: () {
                  ref.read(activeTabProvider.notifier).state = 2;
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SonicTokens.primaryContainer,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: SonicTokens.onPrimaryContainer, size: 22),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, inner) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, inner.maxHeight - 26),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MediaStageBox(
                            track: track,
                            isVideoMode: snap.isVideoMode,
                            isPlaying: snap.isPlaying,
                            position: snap.position,
                            aspectRatio: 16 / 9,
                            cleanMobileStage: true,
                          ),
                          const SizedBox(height: 18),
                          _CleanMobileTitleBlock(track: track),
                          const SizedBox(height: 14),
                          if (track != null)
                            _MobileActionStrip(
                              track: track,
                              snap: snap,
                            ),
                          if (track != null) _ActivePlaylistRow(snap: snap),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Column(
                        children: [
                          _CockpitScrubber(
                            position: snap.position,
                            duration: snap.duration,
                          ),
                          const SizedBox(height: 16),
                          _TransportCluster(
                            snap: snap,
                            centerPlaySize: SonicTokens.mobilePlaySize,
                            includeShuffleRepeat: false,
                          ),
                          const SizedBox(height: 8),
                        ],
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

  Widget _buildWidescreenCockpit(
    BuildContext context,
    PlaybackSnapshot snap,
    AppSettings settings,
    MediaTrack? track,
  ) {
    return Column(
      children: [
        // Top HUD Meta Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              CockpitTouchButton(
                onTap: () => Navigator.of(context).pop(),
                backgroundColor: SonicTokens.surfaceContainer,
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              ),
              const SizedBox(width: 14),
              _AudioVideoTogglePill(
                isVideo: snap.isVideoMode,
                onChanged: (v) => _onToggleVideoMode(v, snap),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceContainer,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 9, color: SonicTokens.secondaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      track?.qualityBadge ?? '96kHz / 24-bit FLAC',
                      style: const TextStyle(
                        color: SonicTokens.secondaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT COLUMN (~58%): Media Stage + Transport
                Expanded(
                  flex: 58,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MediaStageBox(
                          track: track,
                          isVideoMode: snap.isVideoMode,
                          isPlaying: snap.isPlaying,
                          position: snap.position,
                          aspectRatio: 16 / 9,
                          cleanMobileStage: false,
                        ),
                        const SizedBox(height: 16),
                        _TrackTitleRow(
                          track: track,
                          isLiked: snap.isLiked,
                          onLike: () =>
                              SonicAudioEngine.instance.toggleLikeCurrent(),
                          onAddPlaylist: track != null
                              ? () => AddToPlaylistSheet.show(context, track)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _CockpitScrubber(
                          position: snap.position,
                          duration: snap.duration,
                        ),
                        const SizedBox(height: 14),
                        _TransportCluster(
                          snap: snap,
                          centerPlaySize: SonicTokens.primaryPlaySize,
                        ),
                        const SizedBox(height: 16),
                        _AudioUtilityStrip(snap: snap),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // RIGHT COLUMN (~42%): Up Next Queue & Habit AI
                Expanded(
                  flex: 42,
                  child: _QueueSidePanel(
                    snap: snap,
                    settings: settings,
                    activeTab: _rightQueueTab,
                    onTabChanged: (t) => setState(() => _rightQueueTab = t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioVideoTogglePill extends StatelessWidget {
  final bool isVideo;
  final ValueChanged<bool> onChanged;

  const _AudioVideoTogglePill({
    required this.isVideo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceLowest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeChip(
            label: 'AUDIO',
            icon: Icons.audiotrack_rounded,
            active: !isVideo,
            activeColor: SonicTokens.secondaryContainer,
            onTap: () => onChanged(false),
          ),
          _ModeChip(
            label: 'VIDEO',
            icon: Icons.videocam_rounded,
            active: isVideo,
            activeColor: SonicTokens.primaryRed,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [BoxShadow(color: activeColor.withOpacity(0.35), blurRadius: 14)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active
                    ? SonicTokens.surfaceBase
                    : SonicTokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? SonicTokens.surfaceBase
                    : SonicTokens.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaStageBox extends StatelessWidget {
  final MediaTrack? track;
  final bool isVideoMode;
  final bool isPlaying;
  final Duration position;
  final double aspectRatio;
  final bool cleanMobileStage;

  const _MediaStageBox({
    required this.track,
    required this.isVideoMode,
    required this.isPlaying,
    required this.position,
    required this.aspectRatio,
    this.cleanMobileStage = true,
  });

  @override
  Widget build(BuildContext context) {
    final vc = SonicAudioEngine.instance.videoController;
    final artUrl = track?.thumbnailUrl ?? '';
    final hasPlayableVideo = track != null &&
        ((track!.videoStreamUrl != null && track!.videoStreamUrl!.isNotEmpty) ||
            track!.source == TrackSource.usb ||
            track!.source == TrackSource.local ||
            track!.source == TrackSource.googleDrive);
    final canRenderVideo = isVideoMode && vc != null && hasPlayableVideo;

    Widget stage = AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (canRenderVideo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: vc,
                      controls: NoVideoControls,
                      pauseUponEnteringBackgroundMode: false,
                      wakelock: false,
                    ),
                    ValueListenableBuilder<Rect?>(
                      valueListenable: vc.rect,
                      builder: (context, rect, _) {
                        final ready =
                            rect != null && rect.width > 1 && rect.height > 1;
                        if (ready) return const SizedBox.shrink();
                        return Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: SonicTokens.secondaryContainer,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Loading video stream...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: InkWell(
                onTap: () => _FullscreenVideoPage.open(context, vc),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ] else ...[
            TrackArtwork(
              url: artUrl,
              radius: SonicTokens.radiusXl,
              fallbackIcon: Icons.album_rounded,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.28),
                      Colors.black.withOpacity(0.62),
                    ],
                  ),
                ),
                child: track != null
                    ? _AudioWaveformAndLyricsOverlay(
                        track: track!,
                        isPlaying: isPlaying,
                        position: position,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
          if (!cleanMobileStage && track != null) ...[
            if (!isVideoMode)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceLowest.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle,
                          size: 8, color: SonicTokens.secondaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        track?.source == TrackSource.usb
                            ? 'LOSSLESS USB HI-RES'
                            : 'CABIN AUDIO',
                        style: const TextStyle(
                          color: SonicTokens.secondaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: SourceBadgeChip(source: track!.source),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: canRenderVideo ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: isVideoMode
            ? Border.all(color: Colors.white.withOpacity(0.12))
            : null,
        boxShadow: isVideoMode ? null : SonicTokens.cyanGlow(opacity: 0.18),
      ),
      child: stage,
    );
  }
}

class _FullscreenVideoPage extends ConsumerStatefulWidget {
  final VideoController controller;
  const _FullscreenVideoPage({required this.controller});

  static Future<void> open(BuildContext context, VideoController controller) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(controller: controller),
      ),
    );
  }

  @override
  ConsumerState<_FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends ConsumerState<_FullscreenVideoPage> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // After transition into landscape, allow sensor to detect portrait rotation
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final isMobile = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        MediaQuery.sizeOf(context).shortestSide < 600;

    // Auto-exit fullscreen when device rotates back to portrait
    if (isMobile && orientation == Orientation.portrait) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final snap = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final track = snap.currentTrack;
    final isPlaying = snap.isPlaying;
    final position = snap.position;
    final duration = snap.duration;

    final posMs = position.inMilliseconds.toDouble();
    final durMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final clampedPos = posMs.clamp(0.0, durMs);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Fullscreen Video
            Center(
              child: Video(
                controller: widget.controller,
                controls: NoVideoControls,
                pauseUponEnteringBackgroundMode: false,
                wakelock: false,
              ),
            ),

            // Animated Transparent Controls HUD
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Top Bar: Exit Fullscreen button & Title
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen_exit_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      track?.title ?? 'Soniclane Video',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                    if (track?.artist != null &&
                                        track!.artist.isNotEmpty)
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black87,
                                                blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Bar: Transparent Glass Controls Row (Doesn't obscure video)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Slider & Time Labels
                                Row(
                                  children: [
                                    Text(
                                      MediaTrack.formatSeconds(
                                          position.inSeconds),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                          ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                            overlayRadius: 14,
                                          ),
                                          activeTrackColor:
                                              SonicTokens.secondaryContainer,
                                          inactiveTrackColor:
                                              Colors.white.withOpacity(0.24),
                                          thumbColor: Colors.white,
                                          overlayColor: SonicTokens
                                              .secondaryContainer
                                              .withOpacity(0.2),
                                        ),
                                        child: Slider(
                                          value: clampedPos,
                                          min: 0.0,
                                          max: durMs,
                                          onChanged: (v) {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance.seekTo(
                                              Duration(
                                                  milliseconds: v.round()),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(
                                      MediaTrack.formatSeconds(
                                          duration.inSeconds),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Transparent Glass Controls Pill
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.18)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 10s Replay
                                        _FullscreenIconButton(
                                          icon: Icons.replay_10_rounded,
                                          size: 30,
                                          tooltip: 'Replay 10s',
                                          onTap: () {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance
                                                .seekRelative(
                                              const Duration(seconds: -10),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 18),
                                        // Previous Video
                                        _FullscreenIconButton(
                                          icon: Icons.skip_previous_rounded,
                                          size: 34,
                                          tooltip: 'Previous Video',
                                          onTap: () {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance
                                                .skipToPrevious();
                                          },
                                        ),
                                        const SizedBox(width: 18),
                                        // Play / Pause
                                        _FullscreenIconButton(
                                          icon: isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 42,
                                          isPrimary: true,
                                          tooltip:
                                              isPlaying ? 'Pause' : 'Play',
                                          onTap: () {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance
                                                .togglePlayPause();
                                          },
                                        ),
                                        const SizedBox(width: 18),
                                        // Next Video
                                        _FullscreenIconButton(
                                          icon: Icons.skip_next_rounded,
                                          size: 34,
                                          tooltip: 'Next Video',
                                          onTap: () {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance
                                                .skipToNext();
                                          },
                                        ),
                                        const SizedBox(width: 18),
                                        // 10s Forward
                                        _FullscreenIconButton(
                                          icon: Icons.forward_10_rounded,
                                          size: 30,
                                          tooltip: 'Forward 10s',
                                          onTap: () {
                                            _onUserInteraction();
                                            SonicAudioEngine.instance
                                                .seekRelative(
                                              const Duration(seconds: 10),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String tooltip;
  final bool isPrimary;

  const _FullscreenIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: isPrimary
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                )
              : null,
          child: Icon(
            icon,
            size: size,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioWaveformAndLyricsOverlay extends StatefulWidget {
  final MediaTrack track;
  final bool isPlaying;
  final Duration position;

  const _AudioWaveformAndLyricsOverlay({
    required this.track,
    required this.isPlaying,
    required this.position,
  });

  @override
  State<_AudioWaveformAndLyricsOverlay> createState() =>
      _AudioWaveformAndLyricsOverlayState();
}

class _AudioWaveformAndLyricsOverlayState
    extends State<_AudioWaveformAndLyricsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  LyricsBundle? _lyrics;
  String? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _waveCtrl.repeat();
    }
    _fetchLyricsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AudioWaveformAndLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveCtrl.repeat();
      } else {
        _waveCtrl.stop();
      }
    }
    if (widget.track.id != _loadedTrackId) {
      _fetchLyricsIfNeeded();
    }
  }

  Future<void> _fetchLyricsIfNeeded() async {
    final targetId = widget.track.id;
    _loadedTrackId = targetId;
    setState(() => _lyrics = null);
    final res = await LyricsService.instance.fetchLyrics(widget.track);
    if (!mounted || _loadedTrackId != targetId) return;
    setState(() => _lyrics = res);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  int _activeLyricIndex(List<LyricLine> lines, Duration pos) {
    int idx = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].time <= pos + const Duration(milliseconds: 250)) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _lyrics;
    final hasSynced = bundle != null && bundle.isSynced;

    if (hasSynced) {
      final lines = bundle.lines;
      final activeIdx = _activeLyricIndex(lines, widget.position);
      final prevLine = activeIdx > 0 ? lines[activeIdx - 1].text : null;
      final curLine = activeIdx >= 0
          ? lines[activeIdx].text
          : (lines.isNotEmpty ? lines.first.text : '');
      final nextLine =
          activeIdx + 1 < lines.length ? lines[activeIdx + 1].text : null;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (prevLine != null) ...[
                    Text(
                      prevLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    curLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                  if (nextLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      nextLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SonicTokens.secondaryLight.withOpacity(0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            _AnimatedWaveBars(
              controller: _waveCtrl,
              isPlaying: widget.isPlaying,
              height: 22,
              barCount: 22,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _AnimatedWaveBars(
          controller: _waveCtrl,
          isPlaying: widget.isPlaying,
          height: 54,
          barCount: 24,
        ),
      ),
    );
  }
}

class _AnimatedWaveBars extends StatelessWidget {
  final AnimationController controller;
  final bool isPlaying;
  final double height;
  final int barCount;

  const _AnimatedWaveBars({
    required this.controller,
    required this.isPlaying,
    required this.height,
    required this.barCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final phase = controller.value * 2 * math.pi;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final factor = isPlaying
                  ? 0.25 +
                      0.75 *
                          ((math.sin(phase + i * 0.55) +
                                  math.cos(phase * 1.3 - i * 0.35) +
                                  2) /
                              4)
                  : 0.18 + 0.14 * ((math.sin(i * 0.8) + 1) / 2);
              final barH = (height * factor).clamp(4.0, height);
              final isAccent = i % 5 == 2;
              return Container(
                width: 4,
                height: barH,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: (isAccent
                          ? SonicTokens.primaryContainer
                          : SonicTokens.secondaryContainer)
                      .withOpacity(0.92),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _CleanMobileTitleBlock extends ConsumerWidget {
  final MediaTrack? track;
  const _CleanMobileTitleBlock({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final artistName = track?.artist ?? 'Soniclane Cockpit';
    final hasArtist = track != null &&
        track!.artist.isNotEmpty &&
        track!.artist != 'Unknown Artist' &&
        track!.artist != 'Soniclane Cockpit';
    final targetChannelId =
        (track != null && track!.channelId != null && track!.channelId!.isNotEmpty)
            ? track!.channelId!
            : (track?.artist.trim() ?? '');
    final isFollowed = hasArtist &&
        library.isFollowed(targetChannelId, channelName: track!.artist);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track?.title ?? 'Select a Track to Drive',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: hasArtist
                    ? () => ChannelDetailScreen.open(
                          context,
                          channelId: targetChannelId,
                          channelName: track!.artist,
                          avatarUrl: track!.thumbnailUrl,
                        )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: hasArtist
                                  ? SonicTokens.textPrimary
                                  : SonicTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (hasArtist)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: SonicTokens.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
            if (hasArtist) ...[
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final nowFollowed = await ref
                      .read(libraryProvider.notifier)
                      .toggleFollowChannel(
                        FollowedChannel(
                          channelId: targetChannelId,
                          channelName: track!.artist,
                          avatarUrl: track!.thumbnailUrl,
                          followedAt: DateTime.now(),
                        ),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          nowFollowed
                              ? AppLocale.followedSuccess(track!.artist, context)
                              : AppLocale.unfollowedSuccess(track!.artist, context),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFollowed
                        ? SonicTokens.primaryRed.withOpacity(0.18)
                        : SonicTokens.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFollowed
                          ? SonicTokens.primaryRed
                          : SonicTokens.glassBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFollowed
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 13,
                        color: isFollowed
                            ? SonicTokens.primaryTint
                            : SonicTokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFollowed
                            ? AppLocale.following(context)
                            : AppLocale.follow(context),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFollowed
                              ? SonicTokens.primaryTint
                              : SonicTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _MobileActionStrip extends ConsumerWidget {
  final MediaTrack track;
  final PlaybackSnapshot snap;

  const _MobileActionStrip({
    required this.track,
    required this.snap,
  });

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  void _cycleSpeed(EqSettings eq) {
    final idx = _speeds.indexWhere((s) => (s - eq.playbackSpeed).abs() < 0.05);
    final nextSpeed = _speeds[(idx + 1) % _speeds.length];
    SonicAudioEngine.instance.updateEqSettings(
      eq.copyWith(playbackSpeed: nextSpeed),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final isCachedOffline = library.offlineTracks.any((t) => t.id == track.id) ||
        track.source.isOfflineCapable;
    final speed = snap.eqSettings.playbackSpeed;

    return StreamBuilder<DownloadStatus>(
      stream: OfflineDownloadService.instance.statusStream,
      initialData: OfflineDownloadService.instance.currentStatus,
      builder: (context, dlSnap) {
        final status = dlSnap.data ?? OfflineDownloadService.instance.currentStatus;
        final progress = status.progressByTrackId[track.id];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionIconBtn(
                tooltip: 'Like',
                icon: snap.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: snap.isLiked,
                activeColor: SonicTokens.primaryContainer,
                onTap: () => SonicAudioEngine.instance.toggleLikeCurrent(),
              ),
              _ActionIconBtn(
                tooltip: 'Add Playlist',
                icon: Icons.playlist_add_rounded,
                onTap: () => AddToPlaylistSheet.show(context, track),
              ),
              _ActionIconBtn(
                tooltip: 'Shuffle',
                icon: Icons.shuffle_rounded,
                active: snap.isShuffle,
                onTap: () => SonicAudioEngine.instance.toggleShuffle(),
              ),
              _ActionIconBtn(
                tooltip: 'Repeat',
                icon: Icons.repeat_rounded,
                active: snap.isRepeat,
                onTap: () => SonicAudioEngine.instance.toggleRepeat(),
              ),
              _ActionTextBtn(
                tooltip: 'Playback Speed',
                label:
                    '${speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed}x',
                active: (speed - 1.0).abs() > 0.05,
                onTap: () => _cycleSpeed(snap.eqSettings),
              ),
              if (progress != null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.5,
                        color: SonicTokens.secondaryContainer,
                      ),
                    ),
                  ),
                )
              else
                _ActionIconBtn(
                  tooltip: isCachedOffline
                      ? AppLocale.downloadedOffline(context)
                      : AppLocale.downloadOffline(context),
                  icon: isCachedOffline
                      ? Icons.offline_pin_rounded
                      : Icons.download_for_offline_outlined,
                  active: isCachedOffline,
                  activeColor: SonicTokens.successGreen,
                  onTap: isCachedOffline
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Đã có sẵn trên máy để nghe ngoại tuyến (0 data)'),
                            ),
                          );
                        }
                      : () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text(
                                  'Đang tải "${track.title}" về bộ nhớ máy...'),
                            ),
                          );
                          final ok = await OfflineDownloadService.instance
                              .downloadTrack(track);
                          await ref.read(libraryProvider.notifier).refresh();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Đã tải thành công "${track.title}" về máy!'
                                      : 'Không thể tải bài hát này về máy.',
                                ),
                              ),
                            );
                          }
                        },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionIconBtn({
    required this.tooltip,
    required this.icon,
    this.active = false,
    this.activeColor = SonicTokens.secondaryContainer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 24,
        color: active ? activeColor : SonicTokens.textSecondary,
      ),
    );
  }
}

class _ActionTextBtn extends StatelessWidget {
  final String tooltip;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionTextBtn({
    required this.tooltip,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active
                  ? SonicTokens.secondaryContainer
                  : SonicTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackTitleRow extends ConsumerWidget {
  final MediaTrack? track;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback? onAddPlaylist;

  const _TrackTitleRow({
    required this.track,
    required this.isLiked,
    required this.onLike,
    this.onAddPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final artistName = track?.artist ?? 'Soniclane Cockpit';
    final hasArtist = track != null &&
        track!.artist.isNotEmpty &&
        track!.artist != 'Unknown Artist' &&
        track!.artist != 'Soniclane Cockpit';
    final targetChannelId =
        (track != null && track!.channelId != null && track!.channelId!.isNotEmpty)
            ? track!.channelId!
            : (track?.artist.trim() ?? '');
    final isFollowed = hasArtist &&
        library.isFollowed(targetChannelId, channelName: track!.artist);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      track?.title ?? 'Select a Track to Drive',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: hasArtist
                          ? () => ChannelDetailScreen.open(
                                context,
                                channelId: targetChannelId,
                                channelName: track!.artist,
                                avatarUrl: track!.thumbnailUrl,
                              )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: hasArtist
                                        ? SonicTokens.textPrimary
                                        : SonicTokens.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (hasArtist)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: SonicTokens.textSecondary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (hasArtist) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final nowFollowed = await ref
                            .read(libraryProvider.notifier)
                            .toggleFollowChannel(
                              FollowedChannel(
                                channelId: targetChannelId,
                                channelName: track!.artist,
                                avatarUrl: track!.thumbnailUrl,
                                followedAt: DateTime.now(),
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 2),
                              content: Text(
                                nowFollowed
                                    ? AppLocale.followedSuccess(track!.artist, context)
                                    : AppLocale.unfollowedSuccess(track!.artist, context),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFollowed
                              ? SonicTokens.primaryRed.withOpacity(0.18)
                              : SonicTokens.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFollowed
                                ? SonicTokens.primaryRed
                                : SonicTokens.glassBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowed
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 13,
                              color: isFollowed
                                  ? SonicTokens.primaryTint
                                  : SonicTokens.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFollowed
                                  ? AppLocale.following(context)
                                  : AppLocale.follow(context),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFollowed
                                    ? SonicTokens.primaryTint
                                    : SonicTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SonicTokens.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      track?.qualityBadge ?? 'MASTER',
                      style: const TextStyle(
                        color: SonicTokens.primaryTint,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CockpitTouchButton(
          onTap: onLike,
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: Icon(
            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isLiked
                ? SonicTokens.primaryContainer
                : SonicTokens.textSecondary,
            size: 30,
          ),
        ),
        if (onAddPlaylist != null) ...[
          const SizedBox(width: 6),
          CockpitTouchButton(
            onTap: onAddPlaylist,
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: const Icon(Icons.playlist_add_rounded, size: 26),
          ),
        ],
      ],
    );
  }
}

class _CockpitScrubber extends StatelessWidget {
  final Duration position;
  final Duration duration;

  const _CockpitScrubber({
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final valMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);
    final remaining = (duration - position).isNegative
        ? Duration.zero
        : (duration - position);

    return Column(
      children: [
        Slider(
          value: valMs,
          min: 0,
          max: maxMs,
          onChanged: (v) {
            SonicAudioEngine.instance.seekTo(Duration(milliseconds: v.round()));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                MediaTrack.formatSeconds(position.inSeconds),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '-${MediaTrack.formatSeconds(remaining.inSeconds)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportCluster extends StatelessWidget {
  final PlaybackSnapshot snap;
  final double centerPlaySize;
  final bool includeShuffleRepeat;

  const _TransportCluster({
    required this.snap,
    required this.centerPlaySize,
    this.includeShuffleRepeat = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: includeShuffleRepeat
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.spaceEvenly,
      children: [
        if (includeShuffleRepeat)
          CockpitTouchButton(
            onTap: () => SonicAudioEngine.instance.toggleShuffle(),
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: Icon(
              Icons.shuffle_rounded,
              size: 26,
              color: snap.isShuffle
                  ? SonicTokens.secondaryContainer
                  : SonicTokens.textSecondary,
            ),
          ),
        CockpitTouchButton(
          onTap: () =>
              SonicAudioEngine.instance.seekRelative(const Duration(seconds: -10)),
          backgroundColor: SonicTokens.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          child: const Icon(Icons.replay_10_rounded, size: 28),
        ),
        CockpitTouchButton(
          onTap: () => SonicAudioEngine.instance.skipToPrevious(),
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: const Icon(Icons.skip_previous_rounded, size: 36),
        ),
        InkWell(
          onTap: () => SonicAudioEngine.instance.togglePlayPause(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: centerPlaySize,
            height: centerPlaySize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SonicTokens.primaryContainer,
                  SonicTokens.primaryRed,
                ],
              ),
              boxShadow: SonicTokens.crimsonGlow(opacity: 0.45),
            ),
            child: snap.isBuffering
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    ),
                  )
                : Icon(
                    snap.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
          ),
        ),
        CockpitTouchButton(
          onTap: () => SonicAudioEngine.instance.skipToNext(),
          backgroundColor: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: const Icon(Icons.skip_next_rounded, size: 36),
        ),
        CockpitTouchButton(
          onTap: () =>
              SonicAudioEngine.instance.seekRelative(const Duration(seconds: 10)),
          backgroundColor: SonicTokens.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          child: const Icon(Icons.forward_10_rounded, size: 28),
        ),
        if (includeShuffleRepeat)
          CockpitTouchButton(
            onTap: () => SonicAudioEngine.instance.toggleRepeat(),
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: Icon(
              Icons.repeat_rounded,
              size: 26,
              color: snap.isRepeat
                  ? SonicTokens.secondaryContainer
                  : SonicTokens.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _AudioUtilityStrip extends StatelessWidget {
  final PlaybackSnapshot snap;
  const _AudioUtilityStrip({required this.snap});

  @override
  Widget build(BuildContext context) {
    final eq = snap.eqSettings;
    final rem = snap.sleepTimerRemainingSec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceLow,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _UtilBtn(
            icon: Icons.speed_rounded,
            label: '${eq.playbackSpeed.toStringAsFixed(1)}x',
            onTap: () => EqualizerDspModal.show(context),
          ),
          _UtilBtn(
            icon: Icons.graphic_eq_rounded,
            label: eq.presetName,
            active: true,
            onTap: () => EqualizerDspModal.show(context),
          ),
          _UtilBtn(
            icon: Icons.bedtime_rounded,
            label: rem != null ? '${(rem / 60).ceil()}m' : 'Timer',
            active: rem != null,
            onTap: () => SleepTimerSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _UtilBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UtilBtn({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? SonicTokens.secondaryContainer : SonicTokens.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueSidePanel extends ConsumerWidget {
  final PlaybackSnapshot snap;
  final AppSettings settings;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _QueueSidePanel({
    required this.snap,
    required this.settings,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayList = activeTab == 0 ? snap.queue : snap.habitSuggestions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_play_rounded,
                  color: SonicTokens.secondaryContainer, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Up Next • Queue',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Text(
                '${snap.queue.length} tracks',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Playlist vs Habit AI Tabs
          Row(
            children: [
              Expanded(
                child: _TabPill(
                  label: 'PLAYLIST (${snap.queue.length})',
                  active: activeTab == 0,
                  onTap: () => onTabChanged(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabPill(
                  label: 'HABIT AI (${snap.habitSuggestions.length})',
                  active: activeTab == 1,
                  onTap: () => onTabChanged(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Auto-Flow Driving Habits Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SonicTokens.surfaceBase,
              borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 18, color: SonicTokens.secondaryContainer),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-Flow: Driving Habits',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Infinite related queue for steering wheel',
                          style: TextStyle(
                              color: SonicTokens.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: settings.autoFlowHabits,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(autoFlowHabits: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: displayList.isEmpty
                ? const Center(
                    child: Text(
                      'Queue will populate automatically when you play any song.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SonicTokens.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final item = displayList[i];
                      final isCurrent = snap.currentTrack?.id == item.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                          side: BorderSide(
                            color: isCurrent
                                ? SonicTokens.activeBorderCyan
                                : Colors.transparent,
                          ),
                        ),
                        tileColor: isCurrent
                            ? SonicTokens.surfaceElevated
                            : SonicTokens.surfaceContainer,
                        leading: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            color: isCurrent
                                ? SonicTokens.secondaryContainer
                                : SonicTokens.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? SonicTokens.secondaryLight
                                : SonicTokens.textPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SourceBadgeChip(
                              source: item.source,
                              customLabel: item.source.shortTag,
                            ),
                          ],
                        ),
                        trailing: Text(
                          item.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => SonicAudioEngine.instance.playTrack(
                          item,
                          queue: snap.queue,
                          playlistName: snap.activePlaylistName,
                          playlistId: snap.activePlaylistId,
                          isTempPlaylist: snap.isTempPlaylist,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SonicAudioEngine.instance.toggleShuffle();
                      SonicAudioEngine.instance.skipToNext();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SonicTokens.secondaryContainer,
                      foregroundColor: SonicTokens.surfaceBase,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('SMART SHUFFLE',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: snap.queue.isNotEmpty
                        ? () => CreatePlaylistDialog.show(context,
                            initialTracks: snap.queue)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: SonicTokens.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('SAVE MIX'),
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

class _ActivePlaylistRow extends ConsumerWidget {
  final PlaybackSnapshot snap;

  const _ActivePlaylistRow({required this.snap});

  bool get _isPlaylistPlayback {
    final name = snap.activePlaylistName;
    return snap.isTempPlaylist ||
        snap.activePlaylistId != null ||
        (name != null &&
            name.isNotEmpty &&
            name != 'Auto-Flow Cybermix');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isPlaylistPlayback) return const SizedBox.shrink();

    final library = ref.watch(libraryProvider);
    HybridPlaylist? savedPl;
    if (!snap.isTempPlaylist) {
      for (final p in library.playlists) {
        if ((snap.activePlaylistId != null && p.id == snap.activePlaylistId) ||
            (snap.activePlaylistName != null &&
                p.name == snap.activePlaylistName)) {
          savedPl = p;
          break;
        }
      }
    }

    final displayName = savedPl?.name ??
        snap.activePlaylistName ??
        SonicAudioEngine.kTempNowPlayingPlaylistName;
    final tracks =
        (savedPl != null && savedPl.items.isNotEmpty) ? savedPl.items : snap.queue;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        key: const Key('now_playing_active_playlist_row'),
        onTap: () => _PlaylistTracksSheet.show(
          context,
          initialPlaylistName: displayName,
          initialPlaylistId: savedPl?.id ?? snap.activePlaylistId,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Icon(
                Icons.queue_music_rounded,
                size: 18,
                color: SonicTokens.secondaryContainer,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SonicTokens.secondaryLight,
                  ),
                ),
              ),
              if (tracks.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  '• ${tracks.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SonicTokens.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: SonicTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTracksSheet extends ConsumerWidget {
  final String initialPlaylistName;
  final String? initialPlaylistId;

  const _PlaylistTracksSheet({
    required this.initialPlaylistName,
    this.initialPlaylistId,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialPlaylistName,
    String? initialPlaylistId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlaylistTracksSheet(
        initialPlaylistName: initialPlaylistName,
        initialPlaylistId: initialPlaylistId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final library = ref.watch(libraryProvider);

    HybridPlaylist? savedPl;
    if (!snap.isTempPlaylist) {
      final targetId = snap.activePlaylistId ?? initialPlaylistId;
      final targetName = snap.activePlaylistName ?? initialPlaylistName;
      for (final p in library.playlists) {
        if ((targetId != null && p.id == targetId) || p.name == targetName) {
          savedPl = p;
          break;
        }
      }
    }

    final displayName =
        savedPl?.name ?? snap.activePlaylistName ?? initialPlaylistName;
    final tracks =
        (savedPl != null && savedPl.items.isNotEmpty) ? savedPl.items : snap.queue;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.queue_music_rounded,
                      color: SonicTokens.secondaryContainer, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${tracks.length} tracks',
                    style: const TextStyle(
                      color: SonicTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tracks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No tracks in this playlist.',
                      style: TextStyle(color: SonicTokens.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final item = tracks[i];
                      final isCurrent = snap.currentTrack?.id == item.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                          side: BorderSide(
                            color: isCurrent
                                ? SonicTokens.activeBorderCyan
                                : SonicTokens.glassBorder,
                          ),
                        ),
                        tileColor: isCurrent
                            ? SonicTokens.surfaceContainer
                            : SonicTokens.surfaceCard,
                        leading: isCurrent
                            ? const Icon(Icons.graphic_eq_rounded,
                                color: SonicTokens.secondaryContainer, size: 20)
                            : Text(
                                '${i + 1}'.padLeft(2, '0'),
                                style: const TextStyle(
                                  color: SonicTokens.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? SonicTokens.secondaryLight
                                : SonicTokens.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item.durationSeconds > 0
                              ? '${item.artist} • ${item.formattedDuration}'
                              : item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await SonicAudioEngine.instance.playTrack(
                            item,
                            queue: tracks,
                            playlistName: displayName,
                            playlistId: savedPl?.id ?? snap.activePlaylistId,
                            isTempPlaylist: snap.isTempPlaylist,
                            keepVideoMode: snap.isVideoMode,
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? SonicTokens.surfaceElevated
              : SonicTokens.surfaceBase,
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          border: Border.all(
            color: active
                ? SonicTokens.activeBorderCyan
                : SonicTokens.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : SonicTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
