import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../features/now_playing/now_playing_screen.dart';

/// Shared helper to play any track/playlist, dismiss one-time Resume banner,
/// and open the full Now Playing screen immediately on mobile portrait displays.
Future<void> playTrackAndOpenMobile(
  BuildContext context,
  WidgetRef ref,
  MediaTrack track, {
  List<MediaTrack>? queue,
  String? playlistName,
  String? playlistId,
  List<MediaTrack>? relatedForAutoQueue,
  Duration? resumeAt,
  bool? keepVideoMode,
}) async {
  ref.read(resumeCardVisibleProvider.notifier).state = false;
  final isMobile = MediaQuery.sizeOf(context).width < 700;

  if (isMobile) {
    NowPlayingScreen.open(context);
  }

  await SonicAudioEngine.instance.playTrack(
    track,
    queue: queue,
    playlistName: playlistName,
    playlistId: playlistId,
    relatedForAutoQueue: relatedForAutoQueue,
    resumeAt: resumeAt,
    keepVideoMode: keepVideoMode,
  );
}
