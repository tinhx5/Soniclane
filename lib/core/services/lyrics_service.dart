import 'package:dio/dio.dart';
import '../models/media_models.dart';
import 'stream_resolver.dart';

class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

class LyricsBundle {
  final List<LyricLine> lines;
  final String? plainLyrics;
  final String source;

  const LyricsBundle({
    this.lines = const [],
    this.plainLyrics,
    required this.source,
  });

  bool get isSynced => lines.isNotEmpty;
  bool get hasAnyLyrics =>
      lines.isNotEmpty || (plainLyrics != null && plainLyrics!.trim().isNotEmpty);
}

/// Fetches time-synced LRC lyrics via LRCLIB with optional fallback to custom server captions.
class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
      headers: const {'User-Agent': 'SoniclaneCockpit/2.0'},
    ),
  );

  final Map<String, LyricsBundle?> _cache = {};

  Future<LyricsBundle?> fetchLyrics(MediaTrack track) async {
    if (StreamResolver.testOfflineMode) return null;
    if (_cache.containsKey(track.id)) return _cache[track.id];

    final cleaned = _cleanQueryTitle(track.title);
    final artist = _cleanArtist(track.artist);

    // 1. Try LRCLIB synced lyrics search
    final lrc = await _fetchFromLrclib(cleaned, artist);
    if (lrc != null && lrc.hasAnyLyrics) {
      _cache[track.id] = lrc;
      return lrc;
    }

    // 2. Fallback: User-configured custom media server timed captions
    if (track.source == TrackSource.customStream &&
        track.id.isNotEmpty &&
        StreamResolver.instance.hasCustomServer) {
      final captions = await _fetchFromCustomServerCaptions(track.id);
      if (captions != null && captions.hasAnyLyrics) {
        _cache[track.id] = captions;
        return captions;
      }
    }

    _cache[track.id] = null;
    return null;
  }

  Future<LyricsBundle?> _fetchFromLrclib(String title, String artist) async {
    if (title.isEmpty) return null;
    try {
      final q = artist.isNotEmpty ? '$title $artist' : title;
      final res = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': q},
      );
      if (res.statusCode == 200 && res.data is List) {
        final items = List<Map<String, dynamic>>.from(
          (res.data as List).whereType<Map>(),
        );
        for (final item in items) {
          final synced = item['syncedLyrics'] as String?;
          if (synced != null && synced.trim().isNotEmpty) {
            final parsed = parseLrc(synced);
            if (parsed.isNotEmpty) {
              return LyricsBundle(lines: parsed, source: 'LRCLIB');
            }
          }
        }
        for (final item in items) {
          final plain = item['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            return LyricsBundle(plainLyrics: plain.trim(), source: 'LRCLIB');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LyricsBundle?> _fetchFromCustomServerCaptions(String itemId) async {
    for (final inst in StreamResolver.instance.instances.take(2)) {
      try {
        final listRes = await _dio.get('${inst.url}/api/v1/captions/$itemId');
        if (listRes.statusCode != 200 || listRes.data is! Map) continue;
        final captions = ((listRes.data as Map)['captions'] as List?) ?? [];
        if (captions.isEmpty) continue;

        final preferred = captions.firstWhere(
          (c) {
            final lang = ((c['languageCode'] ?? c['label'] ?? '') as String)
                .toLowerCase();
            return lang.contains('vi') || lang.contains('en');
          },
          orElse: () => captions.first,
        );
        final relUrl = preferred['url'] as String?;
        if (relUrl == null || relUrl.isEmpty) continue;

        final fullUrl =
            relUrl.startsWith('http') ? relUrl : '${inst.url}$relUrl';
        final vttRes = await _dio.get<String>(fullUrl);
        final vtt = vttRes.data;
        if (vtt != null && vtt.isNotEmpty) {
          final lines = parseVtt(vtt);
          if (lines.isNotEmpty) {
            return LyricsBundle(lines: lines, source: 'Captions');
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static List<LyricLine> parseLrc(String raw) {
    final regex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final result = <LyricLine>[];

    for (final line in raw.split('\n')) {
      final matches = regex.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.replaceAll(regex, '').trim();
      if (text.isEmpty) continue;

      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '0') ?? 0;
        final fracRaw = (m.group(3) ?? '0').padRight(3, '0');
        final ms = int.tryParse(fracRaw.substring(0, 3)) ?? 0;
        result.add(
          LyricLine(
            time: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ),
        );
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  static List<LyricLine> parseVtt(String raw) {
    final timeRegex = RegExp(
      r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->',
    );
    final lines = raw.split('\n');
    final result = <LyricLine>[];
    Duration? currentTime;
    final buf = StringBuffer();

    void flush() {
      final t = currentTime;
      final text = buf
          .toString()
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (t != null && text.isNotEmpty) {
        if (result.isEmpty || result.last.text != text) {
          result.add(LyricLine(time: t, text: text));
        }
      }
      currentTime = null;
      buf.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      final m = timeRegex.firstMatch(line);
      if (m != null) {
        flush();
        final hr = int.tryParse(m.group(1) ?? '0') ?? 0;
        final min = int.tryParse(m.group(2) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(3) ?? '0') ?? 0;
        final ms = int.tryParse(m.group(4) ?? '0') ?? 0;
        currentTime =
            Duration(hours: hr, minutes: min, seconds: sec, milliseconds: ms);
      } else if (currentTime != null) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(line);
      }
    }
    flush();
    return result;
  }

  String _cleanQueryTitle(String title) {
    return title
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*(official|mv|video|lyric|audio|cover|remix|live|4k|hd)[^)]*\)', caseSensitive: false), ' ')
        .split('|')
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanArtist(String artist) {
    return artist
        .replaceAll(RegExp(r'\s*(official|music|vevo|channel)\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
