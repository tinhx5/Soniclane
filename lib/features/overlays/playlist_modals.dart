import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/services/stream_resolver.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../core/utils/url_parser.dart';

class CreatePlaylistDialog extends ConsumerStatefulWidget {
  final List<MediaTrack> initialTracks;
  const CreatePlaylistDialog({super.key, this.initialTracks = const []});

  static Future<HybridPlaylist?> show(
    BuildContext context, {
    List<MediaTrack> initialTracks = const [],
  }) {
    return showDialog<HybridPlaylist>(
      context: context,
      builder: (_) => CreatePlaylistDialog(initialTracks: initialTracks),
    );
  }

  @override
  ConsumerState<CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<CreatePlaylistDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final created = await ref
        .read(libraryProvider.notifier)
        .createPlaylist(name, initialTracks: widget.initialTracks);
    if (mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SonicTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        side: const BorderSide(color: SonicTokens.activeBorderBlue),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Hybrid Playlist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Save remote stream metadata and mix with offline USB / local audio.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Night Highway Cybermix',
                prefixIcon: Icon(Icons.queue_music_rounded),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SonicTokens.secondaryBlue,
                        foregroundColor: SonicTokens.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                        ),
                      ),
                      child: const Text('Create'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddToPlaylistSheet extends ConsumerWidget {
  final MediaTrack track;
  final bool preferNowPlaying;
  final String? preferredPlaylistId;

  const AddToPlaylistSheet({
    super.key,
    required this.track,
    this.preferNowPlaying = false,
    this.preferredPlaylistId,
  });

  static Future<void> show(
    BuildContext context,
    MediaTrack track, {
    bool preferNowPlaying = false,
    String? preferredPlaylistId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddToPlaylistSheet(
        track: track,
        preferNowPlaying: preferNowPlaying,
        preferredPlaylistId: preferredPlaylistId,
      ),
    );
  }

  HybridPlaylist? _findActivePlaylist(
    List<HybridPlaylist> playlists,
    PlaybackSnapshot snap,
  ) {
    if (preferredPlaylistId != null) {
      for (final p in playlists) {
        if (p.id == preferredPlaylistId) return p;
      }
    }
    if (snap.isTempPlaylist) return null;
    for (final p in playlists) {
      if (snap.activePlaylistId != null && p.id == snap.activePlaylistId) {
        return p;
      }
      if (snap.activePlaylistName != null && p.name == snap.activePlaylistName) {
        return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final snap = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;

    final activePlaylist = _findActivePlaylist(library.playlists, snap);
    final hasActiveSavedPlaylist = activePlaylist != null ||
        preferredPlaylistId != null ||
        (!snap.isTempPlaylist && snap.activePlaylistId != null);
    final showNowPlayingFirst =
        !hasActiveSavedPlaylist && (preferNowPlaying || snap.currentTrack != null);

    final orderedPlaylists = List<HybridPlaylist>.from(library.playlists);
    if (activePlaylist != null) {
      orderedPlaylists.removeWhere((p) => p.id == activePlaylist.id);
      orderedPlaylists.insert(0, activePlaylist);
    }

    final totalCount = (showNowPlayingFirst ? 1 : 0) + orderedPlaylists.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add to Hybrid Playlist',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await CreatePlaylistDialog.show(context,
                        initialTracks: [track]);
                  },
                  icon: const Icon(Icons.add_circle_rounded,
                      color: SonicTokens.secondaryContainer, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (totalCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await CreatePlaylistDialog.show(context,
                        initialTracks: [track]);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create First Playlist'),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: totalCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    if (showNowPlayingFirst && i == 0) {
                      final nowSubtitle = snap.isTempPlaylist
                          ? '${snap.queue.length} tracks • Temp playlist (plays in order added)'
                          : (snap.currentTrack != null
                              ? 'Temp playlist • Plays next in order added'
                              : 'Temp playlist • Starts & plays in order added');
                      return ListTile(
                        key: const Key('add_to_nowplaying_tile'),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                          side: const BorderSide(
                            color: SonicTokens.activeBorderCyan,
                            width: 1.5,
                          ),
                        ),
                        tileColor: SonicTokens.surfaceCard,
                        minVerticalPadding: 14,
                        leading: const Icon(Icons.queue_music_rounded,
                            color: SonicTokens.secondaryContainer),
                        title: Row(
                          children: [
                            const Text(
                              SonicAudioEngine.kTempNowPlayingPlaylistName,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: SonicTokens.secondaryContainer
                                    .withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'TEMP PLAYLIST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SonicTokens.secondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(nowSubtitle),
                        onTap: () async {
                          final res = await SonicAudioEngine.instance
                              .addToNowPlayingPlaylist(track);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            final msg = res.startedNow
                                ? 'Playing "${track.title}" in Nowplaying'
                                : (res.added
                                    ? 'Added "${track.title}" to Nowplaying (#${res.totalCount} in queue)'
                                    : '"${track.title}" is already in Nowplaying');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: SonicTokens.surfaceElevated,
                              ),
                            );
                          }
                        },
                      );
                    }

                    final plIdx = i - (showNowPlayingFirst ? 1 : 0);
                    final pl = orderedPlaylists[plIdx];
                    final isActiveOpened = activePlaylist?.id == pl.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                        side: BorderSide(
                          color: isActiveOpened
                              ? SonicTokens.activeBorderCyan
                              : SonicTokens.glassBorder,
                          width: isActiveOpened ? 1.5 : 1.0,
                        ),
                      ),
                      tileColor: SonicTokens.surfaceCard,
                      minVerticalPadding: 14,
                      leading: const Icon(Icons.playlist_add_rounded,
                          color: SonicTokens.secondaryContainer),
                      title: Text(
                        pl.name,
                        style: TextStyle(
                          fontWeight: isActiveOpened
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        isActiveOpened
                            ? 'OPEN NOW • ${pl.items.length} tracks • 🌐 ${pl.streamCount} • 💾 ${pl.usbCount}'
                            : '${pl.items.length} tracks • 🌐 ${pl.streamCount} • 💾 ${pl.usbCount}',
                      ),
                      onTap: () async {
                        await ref
                            .read(libraryProvider.notifier)
                            .addTrackToPlaylist(pl.id, track);
                        SonicAudioEngine.instance.appendTrackIfActivePlaylist(
                            pl.id, pl.name, track);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Added "${track.title}" to ${pl.name}'),
                              backgroundColor: SonicTokens.surfaceElevated,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ImportUrlDialog extends ConsumerStatefulWidget {
  const ImportUrlDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ImportUrlDialog(),
    );
  }

  @override
  ConsumerState<ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends ConsumerState<ImportUrlDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillFromClipboard();
  }

  Future<void> _prefillFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && UrlParser.isMediaUrl(data!.text!)) {
      _controller.text = data.text!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _importAndPlay() async {
    final match = UrlParser.parse(_controller.text);
    if (match == null) {
      setState(() => _error =
          'Please paste a direct audio/video URL (.mp3, .mp4, .m3u8) or custom server media link.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (match.type == MediaUrlType.directMedia ||
        match.type == MediaUrlType.streamItem) {
      final bundle = await StreamResolver.instance.resolveTrack(match.id);
      if (bundle != null) {
        await SonicAudioEngine.instance.playTrack(
          bundle.track,
          relatedForAutoQueue: bundle.relatedTracks,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
    } else {
      final pl = await StreamResolver.instance.fetchPlaylist(match.id);
      if (pl != null && pl.tracks.isNotEmpty) {
        await ref
            .read(libraryProvider.notifier)
            .createPlaylist(pl.title, initialTracks: pl.tracks);
        await SonicAudioEngine.instance.playTrack(
          pl.tracks.first,
          queue: pl.tracks,
          playlistName: pl.title,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error =
            'Could not resolve stream. Configure Custom Media Server in Settings or use a direct media URL.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SonicTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        side: const BorderSide(color: SonicTokens.activeBorderCyan),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.link_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
                const SizedBox(width: 10),
                Text('Play or Import Media URL',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a direct .mp3/.mp4/.m3u8 link or a URL for your Custom Media Server.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'https://example.com/audio.mp3 or playlist?list=...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded,
                      color: SonicTokens.secondaryContainer),
                  onPressed: _prefillFromClipboard,
                ),
              ),
              onSubmitted: (_) => _importAndPlay(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: SonicTokens.errorRed, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _importAndPlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SonicTokens.primaryRed,
                        foregroundColor: SonicTokens.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                        ),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_loading ? 'Resolving...' : 'Play Now'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
