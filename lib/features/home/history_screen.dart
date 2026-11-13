import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/sonic_tokens.dart';
import '../../shared/widgets/common_badges.dart';
import '../../shared/widgets/playback_launcher.dart';

class PlaybackHistoryScreen extends ConsumerStatefulWidget {
  const PlaybackHistoryScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlaybackHistoryScreen()),
    );
  }

  @override
  ConsumerState<PlaybackHistoryScreen> createState() =>
      _PlaybackHistoryScreenState();
}

class _PlaybackHistoryScreenState extends ConsumerState<PlaybackHistoryScreen> {
  bool _unfinishedOnly = false;
  List<MediaTrack> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DatabaseService.instance
        .getFullHistory(unfinishedOnly: _unfinishedOnly);
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      appBar: AppBar(
        backgroundColor: SonicTokens.surfaceLowest,
        title: const Text('Playback History & Resume'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await DatabaseService.instance.clearHistory();
              _load();
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: SonicTokens.errorRed),
            label: const Text('Clear All',
                style: TextStyle(color: SonicTokens.errorRed)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All History'),
                  selected: !_unfinishedOnly,
                  onSelected: (_) {
                    _unfinishedOnly = false;
                    _load();
                  },
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('Unfinished Sessions'),
                  selected: _unfinishedOnly,
                  onSelected: (_) {
                    _unfinishedOnly = true;
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text('No playback history recorded yet.',
                            style: TextStyle(color: SonicTokens.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final track = _items[i];
                          return ListTile(
                            tileColor: SonicTokens.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SonicTokens.radiusXl),
                              side: const BorderSide(
                                  color: SonicTokens.glassBorder),
                            ),
                            leading: TrackArtwork(
                              url: track.thumbnailUrl,
                              width: 60,
                              height: 60,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${track.artist} • Played ${track.playCount}x'),
                                const SizedBox(height: 4),
                                if (!track.isCompleted &&
                                    track.lastPositionMs > 0)
                                  LinearProgressIndicator(
                                    value: track.progressRatio,
                                    color: SonicTokens.primaryRed,
                                    backgroundColor:
                                        SonicTokens.surfaceHighest,
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded,
                                  size: 38, color: SonicTokens.primaryRed),
                              onPressed: () {
                                playTrackAndOpenMobile(
                                  context,
                                  ref,
                                  track,
                                  resumeAt: Duration(
                                      milliseconds: track.lastPositionMs),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
