import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/media_models.dart';
import '../utils/url_parser.dart';

class ResolvedStreamBundle {
  final MediaTrack track;
  final List<MediaTrack> relatedTracks;
  final String resolvedByTier;
  final String? serverUrl;

  const ResolvedStreamBundle({
    required this.track,
    required this.relatedTracks,
    required this.resolvedByTier,
    this.serverUrl,
  });
}

/// User-configured Custom Media Server & Direct Stream URL Resolver (BYO Source).
///
/// Soniclane ships with NO hardcoded third-party streaming servers or API pools.
/// Supports:
/// 1. Direct media URLs (.mp3, .flac, .mp4, .m3u8, etc.)
/// 2. User-configured JSON Media API v1 servers (/api/v1/...)
/// 3. User-configured JSON Stream Index API servers (/search, /streams, /trending, /playlists)
class StreamResolver {
  StreamResolver._();
  static final StreamResolver instance = StreamResolver._();

  static const String kStreamUserAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const String kDefaultServerConfigUrl =
      'https://www.mobileapp.vn/mdsl/soniclane.json';

  static const String kFallbackDefaultServerConfigUrl =
      'https://www.mobileapp.vn/mdsl/soniclane.js';

  /// Overridable in tests to simulate fetching remote default config locally.
  static String defaultServerConfigUrl = kDefaultServerConfigUrl;

  /// Test-only flag to simulate zero network / no configured server in unit tests.
  static bool testOfflineMode = false;

  static const Duration _probeTimeout = Duration(milliseconds: 2200);
  static const Duration _cacheTtl = Duration(minutes: 3);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
      headers: const {'User-Agent': kStreamUserAgent},
    ),
  );

  List<ServerInstance> _configuredServers = [];
  List<ServerInstance> _measuredInstances = [];
  final Map<String, ({ResolvedStreamBundle bundle, DateTime cachedAt})>
      _bundleCache = {};
  final Map<String, ({Map<String, dynamic> data, DateTime cachedAt})>
      _rawV1Cache = {};
  final Set<String> _preferProxyServers = {};

  bool get hasCustomServer => _configuredServers.isNotEmpty;

  /// Normalizes one or more comma/newline-separated domains or URLs.
  /// Automatically prepends `https://` for public domains or `http://` for local IPs/localhost.
  static List<String> normalizeServerUrls(String raw) {
    final tokens = raw
        .split(RegExp(r'[\r\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final out = <String>[];
    for (final token in tokens) {
      var candidate = token;
      final lower = candidate.toLowerCase();
      if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
        if (candidate.contains(' ')) continue;
        final isLocal = _isLocalHostCandidate(lower);
        candidate = '${isLocal ? "http" : "https"}://$candidate';
      }
      while (candidate.endsWith('/')) {
        candidate = candidate.substring(0, candidate.length - 1);
      }
      final uri = Uri.tryParse(candidate);
      if (uri != null &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.host.isNotEmpty &&
          (uri.host.contains('.') ||
              uri.host == 'localhost' ||
              uri.hasPort)) {
        out.add(candidate);
      }
    }
    return out;
  }

  /// Extracts normalized server URLs from either raw JSON (`{"servers": [...]}`
  /// / `{"sources": [...]}` / `[...]`) or comma/newline-separated URLs/domains.
  static List<String> parseServerEntries(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final listRaw = decoded is List
            ? decoded
            : (decoded is Map
                ? (decoded['servers'] ?? decoded['sources'] ?? const [])
                : const []);
        if (listRaw is List) {
          return normalizeServerUrls(listRaw.whereType<String>().join('\n'));
        }
      } catch (_) {}
      return const [];
    }

    return normalizeServerUrls(trimmed);
  }

  /// Formats normalized URLs or pasted JSON entries back into a clean Settings string.
  static String formatNormalizedServerInput(String raw) {
    return parseServerEntries(raw).join(', ');
  }

  /// Merges [primary] and [fallback] server URLs, keeping [primary] order first
  /// and automatically dropping duplicates from [fallback].
  static List<String> mergeServerLists(
      List<String> primary, List<String> fallback) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in [...primary, ...fallback]) {
      final clean = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if (clean.isEmpty) continue;
      final key = clean.toLowerCase();
      if (seen.add(key)) {
        out.add(clean);
      }
    }
    return out;
  }

  /// Fetches and parses a remote JSON server list (`{"servers": [...]}` /
  /// `{"sources": [...]}` / `[...]`).
  Future<List<String>> _fetchConfigServerUrls(
    String configUrl, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (testOfflineMode || configUrl.trim().isEmpty) return const [];
    try {
      final res = await _dio.get(configUrl).timeout(timeout);
      if (res.statusCode == 200) {
        final data = res.data;
        if (data is String) {
          return parseServerEntries(data);
        } else if (data is List) {
          return normalizeServerUrls(data.whereType<String>().join('\n'));
        } else if (data is Map) {
          final rawList = data['servers'] ?? data['sources'];
          if (rawList is List) {
            return normalizeServerUrls(rawList.whereType<String>().join('\n'));
          }
        }
      }
    } catch (_) {}
    return const [];
  }

  /// Fetches the default remote server JSON feed silently (falls back to `.js` JSON
  /// endpoint if `.json` returns 404/empty).
  Future<String> fetchDefaultServerConfigRaw({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    var urls = await _fetchConfigServerUrls(
      defaultServerConfigUrl,
      timeout: timeout,
    );
    if (urls.isEmpty && defaultServerConfigUrl == kDefaultServerConfigUrl) {
      urls = await _fetchConfigServerUrls(
        kFallbackDefaultServerConfigUrl,
        timeout: timeout,
      );
    }
    if (urls.isEmpty &&
        defaultServerConfigUrl == kDefaultServerConfigUrl &&
        !testOfflineMode) {
      urls.add('https://yt.chocolatemoo53.com');
    }
    return urls.join(', ');
  }

  /// Expands user input in Settings: if a single `.json` / `.js` config URL is supplied,
  /// fetches it and returns its normalized server URL list.
  Future<String> expandServerConfigInput(String raw) async {
    final entries = parseServerEntries(raw);
    if (entries.length == 1) {
      final candidate = entries.first;
      final uri = Uri.tryParse(candidate);
      final lowerPath = uri?.path.toLowerCase() ?? '';
      if (uri != null &&
          (lowerPath.endsWith('.json') || lowerPath.endsWith('.js')) &&
          !testOfflineMode) {
        final extracted = await _fetchConfigServerUrls(candidate);
        if (extracted.isNotEmpty) {
          return extracted.join(', ');
        }
        return '';
      }
    }
    return entries.join(', ');
  }

  static bool _isLocalHostCandidate(String lowerHost) {
    final hostOnly = lowerHost.split('/').first.split(':').first;
    return hostOnly == 'localhost' ||
        hostOnly == '127.0.0.1' ||
        hostOnly.endsWith('.local') ||
        hostOnly.startsWith('10.') ||
        hostOnly.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(hostOnly);
  }

  /// Clears cached track resolution metadata/bundles, optionally for one ID/URL.
  void invalidateTrackCache([String? idOrUrl]) {
    if (idOrUrl == null || idOrUrl.trim().isEmpty) {
      _bundleCache.clear();
      _rawV1Cache.clear();
      return;
    }
    final key = idOrUrl.trim();
    _bundleCache.removeWhere((k, _) => k.startsWith('$key|'));
    _rawV1Cache.removeWhere((k, _) => k.contains('|$key|'));
  }

  /// Parses user-entered custom server URLs/domains and merges them with optional
  /// synced default URLs, prioritizing user entries and dropping duplicates from default.
  void setCustomInstance(String raw, {String defaultRaw = ''}) {
    final userEntries = parseServerEntries(raw);
    final defaultEntries = parseServerEntries(defaultRaw);
    final merged = mergeServerLists(userEntries, defaultEntries);
    final parsed = merged
        .map((url) => ServerInstance(
              url: url,
              name: Uri.parse(url).host,
              tier: 'Custom Server',
            ))
        .toList();

    _configuredServers = parsed;
    _measuredInstances = List<ServerInstance>.from(parsed);
    invalidateTrackCache();
    _preferProxyServers.clear();
  }

  List<ServerInstance> get instances =>
      _measuredInstances.isNotEmpty ? _measuredInstances : _configuredServers;

  ServerInstance? get activeInstance =>
      instances.isNotEmpty ? instances.first : null;

  /// Measures latency and verifies whether each configured server exposes a compatible
  /// JSON Media API rather than an HTML web page.
  Future<List<ServerInstance>> pingInstances({bool sortByLatency = true}) async {
    invalidateTrackCache();
    _preferProxyServers.clear();
    if (_configuredServers.isEmpty) {
      _measuredInstances = [];
      return [];
    }

    final results = await Future.wait(_configuredServers.map(_probeServerHealth));
    if (sortByLatency) {
      results.sort((a, b) {
        if (a.isHealthy != b.isHealthy) return a.isHealthy ? -1 : 1;
        return (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999);
      });
    }
    _measuredInstances = results;
    return results;
  }

  Future<ServerInstance> _probeServerHealth(ServerInstance inst) async {
    bool sawHtmlWebsite = false;
    final sw = Stopwatch()..start();

    // 1. Probe JSON Media API v1 (/api/v1/stats + search/anti-bot check)
    try {
      final res = await _dio
          .get('${inst.url}/api/v1/stats')
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        if (res.data is Map) {
          // Verify search endpoint isn't gated behind an HTML anti-bot challenge or 401/403
          try {
            final searchCheck = await _dio
                .get(
                  '${inst.url}/api/v1/search?q=music&page=1&type=video',
                  options: Options(validateStatus: (s) => s != null && s < 600),
                )
                .timeout(const Duration(seconds: 4));
            if (searchCheck.statusCode == 200 && searchCheck.data is List) {
              sw.stop();
              return inst.copyWith(
                tier: 'JSON Media API (v1)',
                latencyMs: sw.elapsedMilliseconds,
                isHealthy: true,
              );
            }
            sw.stop();
            return inst.copyWith(
              tier: _looksLikeHtmlResponse(searchCheck) ||
                      searchCheck.statusCode == 401 ||
                      searchCheck.statusCode == 403
                  ? 'Blocked / Anti-Bot'
                  : 'Search Disabled (${searchCheck.statusCode ?? "err"})',
              latencyMs: sw.elapsedMilliseconds,
              isHealthy: false,
            );
          } catch (_) {
            // If /stats answered JSON cleanly and search check timed out, still keep usable
          }
          sw.stop();
          return inst.copyWith(
            tier: 'JSON Media API (v1)',
            latencyMs: sw.elapsedMilliseconds,
            isHealthy: true,
          );
        }
        if (_looksLikeHtmlResponse(res)) {
          sawHtmlWebsite = true;
        }
      }
    } catch (_) {}

    // 2. Probe JSON Stream Index API (/trending?region=US)
    try {
      final res = await _dio
          .get('${inst.url}/trending?region=US')
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        if (res.data is List) {
          sw.stop();
          return inst.copyWith(
            tier: 'JSON Stream Index API',
            latencyMs: sw.elapsedMilliseconds,
            isHealthy: true,
          );
        }
        if (_looksLikeHtmlResponse(res)) {
          sawHtmlWebsite = true;
        }
      }
    } catch (_) {}

    // 3. Fallback: check root response to distinguish unreachable vs HTML website
    if (!sawHtmlWebsite) {
      try {
        final rootRes =
            await _dio.get(inst.url).timeout(const Duration(seconds: 4));
        if (_looksLikeHtmlResponse(rootRes)) {
          sawHtmlWebsite = true;
        }
      } catch (_) {}
    }

    sw.stop();
    if (sawHtmlWebsite) {
      return inst.copyWith(
        tier: 'HTML Website',
        latencyMs: sw.elapsedMilliseconds,
        isHealthy: false,
      );
    }

    return inst.copyWith(
      tier: 'Unreachable',
      latencyMs: 9999,
      isHealthy: false,
    );
  }

  bool _looksLikeHtmlResponse(Response res) {
    final ct = (res.headers.value('content-type') ?? '').toLowerCase();
    if (ct.contains('text/html') || ct.contains('application/xhtml')) {
      return true;
    }
    if (res.data is String) {
      final body = (res.data as String).trimLeft().toLowerCase();
      return body.startsWith('<!doctype html') || body.startsWith('<html');
    }
    return false;
  }

  void _promoteServer(ServerInstance inst) {
    final current = List<ServerInstance>.from(instances);
    final idx = current.indexWhere((e) => e.url == inst.url);
    if (idx > 0) {
      final moved = current.removeAt(idx).copyWith(isHealthy: true);
      current.insert(0, moved);
      _measuredInstances = current;
    }
  }

  List<ServerInstance> _orderedActiveServers({Set<String>? excludeServerUrls}) {
    final filtered = instances.where((inst) {
      if (inst.tier == 'HTML Website') return false;
      if (excludeServerUrls != null && excludeServerUrls.contains(inst.url)) {
        return false;
      }
      return true;
    }).toList();
    if (filtered.length <= 1) return filtered;

    int rank(ServerInstance inst) {
      if (inst.isHealthy) return 0;
      if (inst.tier == 'Custom Server' && inst.latencyMs == null) return 1;
      if (inst.tier == 'Unreachable') return 3;
      return 2;
    }

    filtered.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return (a.latencyMs ?? 5000).compareTo(b.latencyMs ?? 5000);
    });

    final reachable = filtered.where((e) => e.tier != 'Unreachable').toList();
    return reachable.isNotEmpty ? reachable : filtered;
  }

  /// Probes whether a resolved media URL responds with playable media bytes (not 403/404/HTML).
  Future<bool> _probeStreamPlayable(String url) async {
    if (testOfflineMode) return true;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final cancelToken = CancelToken();
    try {
      final res = await _dio
          .get<ResponseBody>(
            trimmed,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.stream,
              receiveTimeout: _probeTimeout,
              followRedirects: true,
              validateStatus: (s) => s != null && s < 500,
              headers: const {
                'Range': 'bytes=0-1023',
                'User-Agent': kStreamUserAgent,
              },
            ),
          )
          .timeout(_probeTimeout);

      final code = res.statusCode ?? 500;
      final ct = (res.headers.value('content-type') ?? '').toLowerCase();
      final ok = (code == 200 || code == 206) &&
          !ct.contains('text/html') &&
          !ct.contains('application/xhtml');
      if (!cancelToken.isCancelled) cancelToken.cancel('probe_done');
      return ok;
    } catch (_) {
      if (!cancelToken.isCancelled) cancelToken.cancel('probe_err');
      return false;
    }
  }

  /// Resolves a direct media URL OR an item ID against user-configured servers.
  /// Set [includeVideo] to `false` in Audio Mode to skip probing video streams.
  Future<ResolvedStreamBundle?> resolveTrack(
    String idOrUrl, {
    String preferredBitrate = '128k',
    String preferredVideoQuality = '720p',
    bool forceProxy = false,
    bool includeVideo = true,
    Set<String>? excludeServerUrls,
  }) async {
    final trimmed = idOrUrl.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct media URL (.mp3, .flac, .mp4, .m3u8, etc.) needs no custom API server
    final direct = UrlParser.parse(trimmed);
    if (direct != null && direct.type == MediaUrlType.directMedia) {
      final uri = Uri.parse(direct.originalUrl);
      final rawName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Direct Stream';
      final cleanTitle =
          rawName.isNotEmpty ? Uri.decodeComponent(rawName) : 'Direct Stream';
      return ResolvedStreamBundle(
        resolvedByTier: 'Direct Media URL',
        relatedTracks: const [],
        track: MediaTrack(
          id: direct.originalUrl,
          title: cleanTitle,
          artist: uri.host,
          thumbnailUrl: '',
          durationSeconds: 0,
          source: TrackSource.customStream,
          streamUrl: direct.originalUrl,
          videoStreamUrl: direct.isDirectVideo ? direct.originalUrl : null,
          videoHasAudio: direct.isDirectVideo,
          qualityBadge: direct.isDirectVideo ? 'DIRECT VIDEO' : 'DIRECT STREAM',
        ),
      );
    }

    if (testOfflineMode || _configuredServers.isEmpty) return null;

    final excluded = excludeServerUrls ?? const <String>{};
    if (!forceProxy) {
      final now = DateTime.now();
      final fullKey = '$trimmed|$preferredBitrate|$preferredVideoQuality|true';
      final targetKey =
          '$trimmed|$preferredBitrate|$preferredVideoQuality|$includeVideo';
      for (final key in includeVideo ? [fullKey] : [fullKey, targetKey]) {
        final cached = _bundleCache[key];
        if (cached != null &&
            now.difference(cached.cachedAt) < _cacheTtl &&
            (cached.bundle.serverUrl == null ||
                !excluded.contains(cached.bundle.serverUrl))) {
          return cached.bundle;
        }
      }
    } else {
      invalidateTrackCache(trimmed);
    }

    // 2. Query user-configured Custom Media Server(s) (Media API v1 -> Stream Index API)
    final servers = _orderedActiveServers(excludeServerUrls: excludeServerUrls);
    for (final inst in servers) {
      ResolvedStreamBundle? resolved;
      if (inst.tier != 'JSON Stream Index API') {
        resolved = await _resolveFromMediaApiV1(
          inst,
          trimmed,
          preferredBitrate,
          preferredVideoQuality,
          forceProxy: forceProxy,
          includeVideo: includeVideo,
        );
      }

      if (resolved == null && inst.tier != 'JSON Media API (v1)') {
        resolved = await _resolveFromStreamIndexApi(
          inst,
          trimmed,
          preferredBitrate,
          preferredVideoQuality,
          includeVideo: includeVideo,
        );
      }

      if (resolved != null) {
        _promoteServer(inst);
        _cacheResolvedBundle(
          trimmed,
          preferredBitrate,
          preferredVideoQuality,
          includeVideo,
          resolved,
        );
        return resolved;
      }
    }

    return null;
  }

  void _cacheResolvedBundle(
    String itemId,
    String preferredBitrate,
    String preferredVideoQuality,
    bool includeVideo,
    ResolvedStreamBundle bundle,
  ) {
    if (_bundleCache.length >= 24) {
      _bundleCache.clear();
    }
    final now = DateTime.now();
    _bundleCache['$itemId|$preferredBitrate|$preferredVideoQuality|$includeVideo'] =
        (bundle: bundle, cachedAt: now);
    if (!includeVideo &&
        bundle.track.videoStreamUrl != null &&
        bundle.track.videoStreamUrl!.isNotEmpty) {
      _bundleCache['$itemId|$preferredBitrate|$preferredVideoQuality|true'] =
          (bundle: bundle, cachedAt: now);
    }
  }

  /// Probes primary audio and top distinct video candidates concurrently.
  Future<({String? audioUrl, String? videoUrl, bool videoHasAudio})>
      _probeMediaCandidates({
    String? audioUrl,
    required bool includeVideo,
    List<({String url, bool hasAudio})> videoCandidates = const [],
    int maxVideoProbes = 4,
  }) async {
    final uniqueVideos = <({String url, bool hasAudio})>[];
    if (includeVideo) {
      final seen = <String>{};
      for (final c in videoCandidates) {
        if (c.url.isEmpty || !seen.add(c.url)) continue;
        uniqueVideos.add(c);
        if (uniqueVideos.length >= maxVideoProbes) break;
      }
    }

    final probeUrls = <String>[
      if (audioUrl != null && audioUrl.isNotEmpty) audioUrl,
      for (final v in uniqueVideos)
        if (v.url != audioUrl) v.url,
    ];
    if (probeUrls.isEmpty) {
      return (audioUrl: null, videoUrl: null, videoHasAudio: false);
    }

    final results = await Future.wait(probeUrls.map(_probeStreamPlayable));
    final playableByUrl = <String, bool>{
      for (var i = 0; i < probeUrls.length; i++) probeUrls[i]: results[i],
    };

    final verifiedAudio =
        (audioUrl != null && playableByUrl[audioUrl] == true) ? audioUrl : null;
    ({String? url, bool hasAudio}) pickedVideo = (url: null, hasAudio: false);
    for (final v in uniqueVideos) {
      if (playableByUrl[v.url] == true) {
        pickedVideo = (url: v.url, hasAudio: v.hasAudio);
        break;
      }
    }
    return (
      audioUrl: verifiedAudio,
      videoUrl: pickedVideo.url,
      videoHasAudio: pickedVideo.url != null && pickedVideo.hasAudio,
    );
  }

  Future<ResolvedStreamBundle?> _resolveFromMediaApiV1(
    ServerInstance inst,
    String itemId,
    String preferredBitrate,
    String preferredVideoQuality, {
    bool forceProxy = false,
    bool includeVideo = true,
  }) async {
    final attempts = forceProxy
        ? [true]
        : (_preferProxyServers.contains(inst.url) ? [true, false] : [false, true]);
    ResolvedStreamBundle? audioOnlyFallback;
    for (final useLocalProxy in attempts) {
      try {
        Map<String, dynamic>? data;
        final rawKey = '${inst.url}|$itemId|$useLocalProxy';
        if (!forceProxy) {
          final cachedRaw = _rawV1Cache[rawKey];
          if (cachedRaw != null &&
              DateTime.now().difference(cachedRaw.cachedAt) < _cacheTtl) {
            data = cachedRaw.data;
          }
        }
        if (data == null) {
          final suffix = useLocalProxy ? '?local=true' : '';
          final res = await _dio.get('${inst.url}/api/v1/videos/$itemId$suffix');
          if (res.statusCode != 200 || res.data is! Map) continue;
          data = Map<String, dynamic>.from(res.data as Map);
          if (_rawV1Cache.length >= 24) {
            _rawV1Cache.clear();
          }
          _rawV1Cache[rawKey] = (data: data, cachedAt: DateTime.now());
        }

        final adaptive = (data['adaptiveFormats'] as List?) ?? [];
        final formatStreams = (data['formatStreams'] as List?) ?? [];
        final isLiveNow = data['liveNow'] == true;
        final rawHls = (data['hlsUrl'] as String?) ?? '';
        final hlsUrl =
            rawHls.isNotEmpty ? _normalizeMediaUrl(inst.url, rawHls) : null;

        final audioUrl =
            _pickAudioFormat(inst.url, adaptive, preferredBitrate);

        final videoCandidates = <({String url, bool hasAudio})>[];
        // For live broadcasts, HLS manifests are much more reliable than noclen adaptive segments.
        if (isLiveNow && hlsUrl != null) {
          videoCandidates.add((url: hlsUrl, hasAudio: true));
        }
        for (final u in _orderedVideoUrls(
            inst.url, formatStreams, preferredVideoQuality, 'qualityLabel')) {
          videoCandidates.add((url: u, hasAudio: true));
        }
        if (includeVideo) {
          final allMp4 = adaptive
              .where((f) => ((f['type'] as String?) ?? '').contains('video/mp4'))
              .toList();
          final h264 = allMp4
              .where((f) => ((f['type'] as String?) ?? '').contains('avc1'))
              .toList();
          final adaptivePool = h264.isNotEmpty ? h264 : allMp4;
          for (final u in _orderedVideoUrls(
              inst.url, adaptivePool, preferredVideoQuality, 'qualityLabel')) {
            videoCandidates.add((url: u, hasAudio: false));
          }
        }
        if (!isLiveNow && hlsUrl != null) {
          videoCandidates.add((url: hlsUrl, hasAudio: true));
        }

        if (audioUrl == null && videoCandidates.isEmpty) continue;

        final fallbackAudio = videoCandidates
            .where((v) => v.hasAudio)
            .map((v) => v.url)
            .firstOrNull;
        final primaryAudio =
            (isLiveNow && hlsUrl != null) ? hlsUrl : (audioUrl ?? fallbackAudio);

        final probed = await _probeMediaCandidates(
          audioUrl: primaryAudio,
          includeVideo: includeVideo,
          videoCandidates: videoCandidates,
        );

        var verifiedAudioUrl = probed.audioUrl;
        final pickedVideoUrl = probed.videoUrl;
        final pickedVideoHasAudio = probed.videoHasAudio;

        if (verifiedAudioUrl == null && pickedVideoUrl == null) {
          continue;
        }
        if (verifiedAudioUrl == null && pickedVideoHasAudio) {
          verifiedAudioUrl = pickedVideoUrl;
        } else if (verifiedAudioUrl == null && pickedVideoUrl != null) {
          // Adaptive video-only with broken audio: retry with ?local=true if direct
          if (!useLocalProxy) continue;
          verifiedAudioUrl = pickedVideoUrl;
        }

        if (useLocalProxy) {
          _preferProxyServers.add(inst.url);
        }

        final thumb = _pickThumbnailUrl(inst.url, data['videoThumbnails']);
        final related = _parseMediaApiV1Related(
          inst.url,
          (data['recommendedVideos'] as List?) ?? [],
        );

        final bundle = ResolvedStreamBundle(
          resolvedByTier:
              '${useLocalProxy ? "Proxy" : "Direct"} (${inst.name})',
          serverUrl: inst.url,
          relatedTracks: related,
          track: MediaTrack(
            id: itemId,
            title: (data['title'] as String?) ?? 'Remote Stream',
            artist: (data['author'] as String?) ?? 'Remote Source',
            channelId: (data['authorId'] as String?) ??
                (data['authorUrl'] as String?)?.replaceAll('/channel/', ''),
            thumbnailUrl: thumb,
            durationSeconds: (data['lengthSeconds'] as int?) ?? 0,
            source: TrackSource.customStream,
            streamUrl: verifiedAudioUrl ?? pickedVideoUrl,
            videoStreamUrl: pickedVideoUrl,
            videoHasAudio: pickedVideoUrl != null && pickedVideoHasAudio,
            qualityBadge: '$preferredBitrate Stream',
          ),
        );

        if (includeVideo &&
            pickedVideoUrl == null &&
            videoCandidates.isNotEmpty &&
            !useLocalProxy) {
          // Keep working audio bundle in case ?local=true proxy is disabled on this server
          audioOnlyFallback ??= bundle;
          continue;
        }
        return bundle;
      } catch (_) {}
    }
    return audioOnlyFallback;
  }

  Future<ResolvedStreamBundle?> _resolveFromStreamIndexApi(
    ServerInstance inst,
    String itemId,
    String preferredBitrate,
    String preferredVideoQuality, {
    bool includeVideo = true,
  }) async {
    try {
      final res = await _dio.get('${inst.url}/streams/$itemId');
      if (res.statusCode == 200 && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final audioStreams = (data['audioStreams'] as List?) ?? [];
        final videoStreams = (data['videoStreams'] as List?) ?? [];
        final rawHls = (data['hls'] as String?) ?? '';
        final hlsUrl =
            rawHls.isNotEmpty ? _normalizeMediaUrl(inst.url, rawHls) : null;

        final audioUrl = _pickAudioFormat(
          inst.url,
          audioStreams,
          preferredBitrate,
          mimeKey: 'mimeType',
        );
        final muxedMatches = videoStreams
            .whereType<Map>()
            .where((v) =>
                v['videoOnly'] != true &&
                ((v['mimeType'] as String?) ?? '').contains('video/mp4'))
            .toList();

        final videoCandidates = <({String url, bool hasAudio})>[];
        for (final u in _orderedVideoUrls(
            inst.url, muxedMatches, preferredVideoQuality, 'quality')) {
          videoCandidates.add((url: u, hasAudio: true));
        }
        if (includeVideo) {
          final h264Only = videoStreams
              .whereType<Map>()
              .where((v) =>
                  ((v['mimeType'] as String?) ?? '').contains('video/mp4'))
              .toList();
          for (final u in _orderedVideoUrls(
              inst.url, h264Only, preferredVideoQuality, 'quality')) {
            videoCandidates.add((url: u, hasAudio: false));
          }
        }
        if (hlsUrl != null) {
          videoCandidates.add((url: hlsUrl, hasAudio: true));
        }

        if (audioUrl == null && videoCandidates.isEmpty) return null;

        final fallbackAudio = videoCandidates
            .where((v) => v.hasAudio)
            .map((v) => v.url)
            .firstOrNull;
        final probed = await _probeMediaCandidates(
          audioUrl: audioUrl ?? fallbackAudio,
          includeVideo: includeVideo,
          videoCandidates: videoCandidates,
        );
        final verifiedAudioUrl = probed.audioUrl;
        final pickedVideoUrl = probed.videoUrl;
        final pickedVideoHasAudio = probed.videoHasAudio;
        if (verifiedAudioUrl == null && pickedVideoUrl == null) return null;

        final related = _parseStreamIndexItems(
          inst.url,
          (data['relatedStreams'] as List?) ?? [],
          badge: 'STREAM',
          tag: 'AUTO QUEUE',
        );

        return ResolvedStreamBundle(
          resolvedByTier: 'Custom Server (${inst.name})',
          serverUrl: inst.url,
          relatedTracks: related,
          track: MediaTrack(
            id: itemId,
            title: (data['title'] as String?) ?? 'Remote Stream',
            artist: (data['uploader'] as String?) ?? 'Remote Source',
            channelId:
                (data['uploaderUrl'] as String?)?.replaceAll('/channel/', ''),
            thumbnailUrl: _normalizeMediaUrl(
                inst.url, data['thumbnailUrl'] as String? ?? ''),
            durationSeconds: (data['duration'] as int?) ?? 0,
            source: TrackSource.customStream,
            streamUrl: verifiedAudioUrl ?? pickedVideoUrl,
            videoStreamUrl: pickedVideoUrl,
            videoHasAudio: pickedVideoUrl != null && pickedVideoHasAudio,
            qualityBadge: '$preferredBitrate Stream',
          ),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fetches trending items only when the user has configured a Custom Media Server.
  Future<List<MediaTrack>> fetchTrendingMusic({String region = 'VN'}) async {
    if (testOfflineMode || _configuredServers.isEmpty) return const [];
    for (final inst in _orderedActiveServers()) {
      // Try Media API v1 trending
      if (inst.tier != 'JSON Stream Index API') {
        try {
          final res = await _dio
              .get('${inst.url}/api/v1/trending?type=music&region=$region');
          if (res.statusCode == 200 && res.data is List) {
            final list = res.data as List;
            final parsed = list.take(16).map((item) {
              final vid = item['videoId'] as String? ?? '';
              return MediaTrack(
                id: vid,
                title: item['title'] as String? ?? 'Remote Track',
                artist: item['author'] as String? ?? 'Artist',
                thumbnailUrl:
                    _pickThumbnailUrl(inst.url, item['videoThumbnails']),
                durationSeconds: item['lengthSeconds'] as int? ?? 240,
                source: TrackSource.customStream,
                qualityBadge: '1080p',
                recommendationTag: 'CUSTOM SERVER FEED',
                viewCountLabel: _formatViews(item['viewCount'] as int? ?? 0),
              );
            }).where((t) => t.id.isNotEmpty).toList();
            if (parsed.isNotEmpty) return parsed;
          }
        } catch (_) {}
      }

      // Try Stream Index API trending
      if (inst.tier != 'JSON Media API (v1)') {
        try {
          final res = await _dio.get('${inst.url}/trending?region=$region');
          if (res.statusCode == 200 && res.data is List) {
            final parsed = _parseStreamIndexItems(
              inst.url,
              (res.data as List).take(16).toList(),
              badge: '1080p',
              tag: 'CUSTOM SERVER FEED',
            );
            if (parsed.isNotEmpty) return parsed;
          }
        } catch (_) {}
      }
    }
    return const [];
  }

  /// Paginated remote search against user-configured Custom Media Server(s).
  /// Supports JSON Media API v1 (`/api/v1/search`) and JSON Stream Index API (`/search`).
  /// Returns up to `targetCount` (default 50) items per UI page.
  Future<({List<MediaTrack> tracks, int nextPage, String? nextToken, bool hasMore})>
      searchRemotePage(
    String query, {
    int startPage = 1,
    String? nextToken,
    int targetCount = 50,
  }) async {
    if (query.trim().isEmpty || testOfflineMode || _configuredServers.isEmpty) {
      return (
        tracks: <MediaTrack>[],
        nextPage: startPage,
        nextToken: null,
        hasMore: false,
      );
    }
    final encoded = Uri.encodeQueryComponent(query.trim());

    for (final inst in _orderedActiveServers()) {
      if (nextToken == null && inst.tier != 'JSON Stream Index API') {
        final v1Result =
            await _searchMediaApiV1(inst, encoded, startPage, targetCount);
        if (v1Result != null && v1Result.tracks.isNotEmpty) {
          _promoteServer(inst);
          return v1Result;
        }
      }

      if (inst.tier != 'JSON Media API (v1)') {
        final indexResult = await _searchStreamIndexApi(
            inst, encoded, startPage, nextToken, targetCount);
        if (indexResult != null && indexResult.tracks.isNotEmpty) {
          _promoteServer(inst);
          return indexResult;
        }
      }
    }

    return (
      tracks: <MediaTrack>[],
      nextPage: startPage,
      nextToken: null,
      hasMore: false,
    );
  }

  Future<({List<MediaTrack> tracks, int nextPage, String? nextToken, bool hasMore})?>
      _searchMediaApiV1(
    ServerInstance inst,
    String encodedQuery,
    int startPage,
    int targetCount,
  ) async {
    try {
      final pageIndices = [startPage, startPage + 1, startPage + 2];
      final responses = await Future.wait(
        pageIndices.map((p) => _dio
            .get('${inst.url}/api/v1/search?q=$encodedQuery&page=$p&type=video')
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), statusCode: 500))),
      );

      final combined = <MediaTrack>[];
      final seenIds = <String>{};
      int pagesSucceeded = 0;
      int lastBatchSize = 0;

      for (final res in responses) {
        if (res.statusCode == 200 && res.data is List) {
          pagesSucceeded++;
          final rawList = res.data as List;
          lastBatchSize = rawList.length;
          for (final item in rawList) {
            if (item is! Map) continue;
            final vid = (item['videoId'] as String?) ?? '';
            if (vid.isEmpty || !seenIds.add(vid)) continue;
            combined.add(
              MediaTrack(
                id: vid,
                title: (item['title'] as String?) ?? 'Remote Track',
                artist: (item['author'] as String?) ?? 'Remote Source',
                channelId: (item['authorId'] as String?) ??
                    (item['authorUrl'] as String?)?.replaceAll('/channel/', ''),
                thumbnailUrl:
                    _pickThumbnailUrl(inst.url, item['videoThumbnails']),
                durationSeconds: (item['lengthSeconds'] as int?) ?? 210,
                source: TrackSource.customStream,
                qualityBadge: '128k Stream',
                viewCountLabel:
                    _formatViews((item['viewCount'] as int?) ?? 0),
              ),
            );
            if (combined.length >= targetCount) break;
          }
        }
        if (combined.length >= targetCount) break;
      }

      if (combined.isNotEmpty) {
        return (
          tracks: combined,
          nextPage: startPage + pagesSucceeded,
          nextToken: null,
          hasMore: pagesSucceeded > 0 && lastBatchSize >= 18,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<({List<MediaTrack> tracks, int nextPage, String? nextToken, bool hasMore})?>
      _searchStreamIndexApi(
    ServerInstance inst,
    String encodedQuery,
    int startPage,
    String? nextToken,
    int targetCount,
  ) async {
    try {
      final combined = <MediaTrack>[];
      final seenIds = <String>{};
      String? token = nextToken;
      int rounds = 0;

      while (combined.length < targetCount && rounds < 3) {
        rounds++;
        final url = token == null
            ? '${inst.url}/search?q=$encodedQuery&filter=videos'
            : '${inst.url}/nextpage/search?nextpage=${Uri.encodeQueryComponent(token)}&q=$encodedQuery&filter=videos';
        final res = await _dio.get(url);
        if (res.statusCode != 200 || res.data is! Map) break;
        final map = Map<String, dynamic>.from(res.data as Map);
        final items = _parseStreamIndexItems(
          inst.url,
          (map['items'] as List?) ?? [],
          badge: '128k Stream',
        );
        for (final t in items) {
          if (seenIds.add(t.id)) {
            combined.add(t);
            if (combined.length >= targetCount) break;
          }
        }
        token = map['nextpage'] as String?;
        if (token == null || token.isEmpty || items.isEmpty) {
          token = null;
          break;
        }
      }

      if (combined.isNotEmpty) {
        return (
          tracks: combined,
          nextPage: startPage + 1,
          nextToken: token,
          hasMore: token != null && token.isNotEmpty,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Convenience single-page remote search (up to 50 tracks).
  Future<List<MediaTrack>> searchRemote(String query) async {
    final page = await searchRemotePage(query);
    return page.tracks;
  }

  /// Fetches metadata entries for a playlist from the user-configured Custom Media Server.
  Future<({String title, List<MediaTrack> tracks})?> fetchPlaylist(
      String playlistId) async {
    if (testOfflineMode || _configuredServers.isEmpty) return null;
    for (final inst in instances) {
      if (inst.tier == 'HTML Website') continue;
      // Media API v1 playlist
      try {
        final res = await _dio.get('${inst.url}/api/v1/playlists/$playlistId');
        if (res.statusCode == 200 && res.data is Map) {
          final data = Map<String, dynamic>.from(res.data as Map);
          final videos = (data['videos'] as List?) ?? [];
          final tracks = videos.map((v) {
            final vid = v['videoId'] as String? ?? '';
            return MediaTrack(
              id: vid,
              title: v['title'] as String? ?? 'Track',
              artist: v['author'] as String? ?? 'Artist',
              thumbnailUrl: _pickThumbnailUrl(inst.url, v['videoThumbnails']),
              durationSeconds: v['lengthSeconds'] as int? ?? 220,
              source: TrackSource.customStream,
              qualityBadge: '128k Stream',
            );
          }).where((t) => t.id.isNotEmpty).toList();
          if (tracks.isNotEmpty) {
            return (
              title: (data['title'] as String?) ?? 'Imported Playlist',
              tracks: tracks,
            );
          }
        }
      } catch (_) {}

      // Stream Index API playlist
      try {
        final res = await _dio.get('${inst.url}/playlists/$playlistId');
        if (res.statusCode == 200 && res.data is Map) {
          final data = Map<String, dynamic>.from(res.data as Map);
          final tracks = _parseStreamIndexItems(
            inst.url,
            (data['relatedStreams'] as List?) ?? [],
            badge: '128k Stream',
          );
          if (tracks.isNotEmpty) {
            return (
              title: (data['name'] as String?) ?? 'Imported Playlist',
              tracks: tracks,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetches channel profile, tracks and playlists from user-configured Custom Media Server.
  Future<ChannelDetails?> fetchChannelDetails(
    String channelId, {
    String? channelName,
  }) async {
    final cleanId = channelId.trim();
    final nameFallback = (channelName != null && channelName.trim().isNotEmpty)
        ? channelName.trim()
        : (cleanId.startsWith('UC') ? 'Artist Channel' : cleanId);

    if (testOfflineMode || _configuredServers.isEmpty) {
      return ChannelDetails(
        channelId: cleanId,
        channelName: nameFallback,
      );
    }

    final hasDirectUcId = cleanId.isNotEmpty && cleanId.startsWith('UC');

    for (final inst in instances) {
      if (inst.tier == 'HTML Website') continue;

      // 1. Direct lookup if we have a real UC channel ID
      if (hasDirectUcId) {
        // Try Media API v1 channel (/api/v1/channels/$cleanId)
        try {
          final res = await _dio.get('${inst.url}/api/v1/channels/$cleanId');
          if (res.statusCode == 200 && res.data is Map) {
            final data = Map<String, dynamic>.from(res.data as Map);
            final authorName = (data['author'] as String?) ?? nameFallback;
            final avatarUrl =
                _pickThumbnailUrl(inst.url, data['authorThumbnails']);
            final bannerUrl =
                _pickThumbnailUrl(inst.url, data['authorBanners']);
            final subCount = data['subCount'] as int?;

            final videos = (data['latestVideos'] as List?) ?? [];
            final tracks = videos.map((v) {
              final vid = v['videoId'] as String? ?? '';
              return MediaTrack(
                id: vid,
                title: v['title'] as String? ?? 'Track',
                artist: authorName,
                channelId: cleanId,
                thumbnailUrl: _pickThumbnailUrl(inst.url, v['videoThumbnails']),
                durationSeconds: v['lengthSeconds'] as int? ?? 220,
                source: TrackSource.customStream,
                qualityBadge: '128k Stream',
                viewCountLabel: v['viewCount'] != null
                    ? _formatViews(v['viewCount'] as int)
                    : null,
              );
            }).where((t) => t.id.isNotEmpty).toList();

            final plList = <HybridPlaylist>[];
            try {
              final plRes = await _dio
                  .get('${inst.url}/api/v1/channels/playlists/$cleanId');
              if (plRes.statusCode == 200 && plRes.data is Map) {
                final plData = (plRes.data['playlists'] as List?) ?? [];
                for (final pItem in plData) {
                  if (pItem is Map) {
                    final pid = (pItem['playlistId'] as String?) ?? '';
                    final pTitle = (pItem['title'] as String?) ?? 'Playlist';
                    if (pid.isNotEmpty) {
                      plList.add(HybridPlaylist(
                        id: pid,
                        name: pTitle,
                        createdAt: DateTime.now(),
                        items: const [],
                      ));
                    }
                  }
                }
              }
            } catch (_) {}

            return ChannelDetails(
              channelId: cleanId,
              channelName: authorName,
              avatarUrl: avatarUrl,
              bannerUrl: bannerUrl,
              subscriberCountLabel: subCount != null
                  ? '${_formatViews(subCount)} subscribers'
                  : null,
              tracks: tracks,
              playlists: plList,
            );
          }
        } catch (_) {}

        // Try Stream Index API channel (/channel/$cleanId)
        try {
          final res = await _dio.get('${inst.url}/channel/$cleanId');
          if (res.statusCode == 200 && res.data is Map) {
            final data = Map<String, dynamic>.from(res.data as Map);
            final authorName = (data['name'] as String?) ?? nameFallback;
            final avatarUrl = _normalizeMediaUrl(
                inst.url, (data['avatarUrl'] as String?) ?? '');
            final bannerUrl = _normalizeMediaUrl(
                inst.url, (data['bannerUrl'] as String?) ?? '');
            final subs = data['subscriberCount'] as int?;

            final tracks = _parseStreamIndexItems(
              inst.url,
              (data['relatedStreams'] as List?) ?? [],
              badge: '128k Stream',
            );

            return ChannelDetails(
              channelId: cleanId,
              channelName: authorName,
              avatarUrl: avatarUrl,
              bannerUrl: bannerUrl,
              subscriberCountLabel:
                  subs != null ? '${_formatViews(subs)} subscribers' : null,
              tracks: tracks,
            );
          }
        } catch (_) {}
      }

      // 2. Search for the CHANNEL entity directly by name
      if (nameFallback.isNotEmpty) {
        // Media API v1 channel search
        try {
          final res = await _dio.get(
              '${inst.url}/api/v1/search?q=${Uri.encodeQueryComponent(nameFallback)}&type=channel');
          if (res.statusCode == 200 &&
              res.data is List &&
              (res.data as List).isNotEmpty) {
            final list = res.data as List;
            dynamic bestMatch;
            for (final item in list) {
              if (item is Map) {
                final author = (item['author'] as String?) ?? '';
                if (author.toLowerCase().trim() ==
                    nameFallback.toLowerCase().trim()) {
                  bestMatch = item;
                  break;
                }
              }
            }
            bestMatch ??= list.first;
            if (bestMatch is Map) {
              final realId = (bestMatch['authorId'] as String?) ?? '';
              if (realId.isNotEmpty && realId != cleanId) {
                final details = await fetchChannelDetails(realId,
                    channelName: nameFallback);
                if (details != null && details.tracks.isNotEmpty) {
                  return details;
                }
              }
            }
          }
        } catch (_) {}

        // Stream Index API channel search
        try {
          final res = await _dio.get(
              '${inst.url}/search?q=${Uri.encodeQueryComponent(nameFallback)}&filter=channels');
          if (res.statusCode == 200 && res.data is Map) {
            final items = (res.data['items'] as List?) ?? [];
            if (items.isNotEmpty) {
              dynamic bestMatch;
              for (final item in items) {
                if (item is Map) {
                  final name = (item['name'] as String?) ?? '';
                  if (name.toLowerCase().trim() ==
                      nameFallback.toLowerCase().trim()) {
                    bestMatch = item;
                    break;
                  }
                }
              }
              bestMatch ??= items.first;
              if (bestMatch is Map) {
                final rawUrl = (bestMatch['url'] as String?) ?? '';
                final realId = rawUrl.replaceAll('/channel/', '').trim();
                if (realId.isNotEmpty && realId != cleanId) {
                  final details = await fetchChannelDetails(realId,
                      channelName: nameFallback);
                  if (details != null && details.tracks.isNotEmpty) {
                    return details;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback: Search for videos by artist name, strictly preserving channelName
      // and filtering out unrelated uploader videos!
      try {
        final query = nameFallback;
        if (query.isNotEmpty) {
          final searchRes = await searchRemotePage(query, targetCount: 40);
          final tracks = searchRes.tracks;
          if (tracks.isNotEmpty) {
            final lowerTarget = nameFallback.toLowerCase().trim();

            // Prioritize videos where the uploader/artist actually matches our channel name
            final exactArtistTracks = tracks
                .where((t) => t.artist.toLowerCase().trim() == lowerTarget)
                .toList();

            final partialArtistTracks = tracks
                .where((t) => t.artist.toLowerCase().contains(lowerTarget))
                .toList();

            final filteredTracks = exactArtistTracks.isNotEmpty
                ? exactArtistTracks
                : (partialArtistTracks.isNotEmpty
                    ? partialArtistTracks
                    : tracks);

            final firstThumb = filteredTracks.first.thumbnailUrl;
            return ChannelDetails(
              channelId: cleanId.isNotEmpty ? cleanId : query,
              channelName: nameFallback, // NEVER overwrite with another uploader!
              avatarUrl: firstThumb,
              tracks: filteredTracks,
            );
          }
        }
      } catch (_) {}
    }

    return ChannelDetails(
      channelId: cleanId,
      channelName: nameFallback,
    );
  }

  String _pickThumbnailUrl(String baseUrl, dynamic thumbsRaw) {
    if (thumbsRaw is List && thumbsRaw.isNotEmpty) {
      for (final t in thumbsRaw) {
        if (t is Map) {
          final url = t['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return _normalizeMediaUrl(baseUrl, url);
          }
        }
      }
    }
    return '';
  }

  String _normalizeMediaUrl(String baseUrl, String rawUrl) {
    final u = rawUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '$baseUrl$u';
    return '$baseUrl/$u';
  }

  String _extractIdFromPath(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    final parsed = Uri.tryParse(
        rawUrl.startsWith('http') ? rawUrl : 'https://x.local$rawUrl');
    final v = parsed?.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    return rawUrl.replaceFirst('/watch?v=', '').split('&').first;
  }

  String? _pickAudioFormat(
    String baseUrl,
    List adaptive,
    String preferredBitrate, {
    String mimeKey = 'type',
  }) {
    var audios = adaptive
        .where((f) => ((f[mimeKey] as String?) ?? '').contains('audio/mp4'))
        .toList();
    if (audios.isEmpty) {
      audios = adaptive
          .where((f) => ((f[mimeKey] as String?) ?? '').contains('audio/webm'))
          .toList();
    }
    if (audios.isEmpty) return null;
    audios.sort((a, b) {
      final bA = int.tryParse('${a['bitrate'] ?? 0}') ?? 0;
      final bB = int.tryParse('${b['bitrate'] ?? 0}') ?? 0;
      return preferredBitrate == '256k' ? bB.compareTo(bA) : bA.compareTo(bB);
    });
    String? raw;
    if (preferredBitrate == '128k') {
      final mid = audios.firstWhere(
        (a) => (int.tryParse('${a['bitrate'] ?? 0}') ?? 0) >= 96000,
        orElse: () => audios.last,
      );
      raw = mid['url'] as String?;
    } else {
      raw = audios.first['url'] as String?;
    }
    return raw != null && raw.isNotEmpty
        ? _normalizeMediaUrl(baseUrl, raw)
        : null;
  }

  List<String> _orderedVideoUrls(
    String baseUrl,
    List pool,
    String preferredQuality,
    String qualityKey,
  ) {
    if (pool.isEmpty) return const [];
    final out = <String>[];
    for (final matchFirst in [true, false]) {
      for (final v in pool) {
        if (v is! Map) continue;
        final q = (v[qualityKey] as String?) ?? '';
        final isPreferred = q.contains(preferredQuality);
        if (isPreferred != matchFirst) continue;
        final raw = v['url'] as String?;
        if (raw != null && raw.isNotEmpty) {
          out.add(_normalizeMediaUrl(baseUrl, raw));
        }
      }
    }
    return out;
  }

  List<MediaTrack> _parseMediaApiV1Related(String baseUrl, List items) {
    return items.take(10).map((item) {
      final vid = item['videoId'] as String? ?? '';
      return MediaTrack(
        id: vid,
        title: item['title'] as String? ?? 'Related Track',
        artist: item['author'] as String? ?? 'Artist',
        thumbnailUrl: _pickThumbnailUrl(baseUrl, item['videoThumbnails']),
        durationSeconds: item['lengthSeconds'] as int? ?? 240,
        source: TrackSource.customStream,
        qualityBadge: 'STREAM',
        recommendationTag: 'AUTO QUEUE',
      );
    }).where((e) => e.id.isNotEmpty).toList();
  }

  List<MediaTrack> _parseStreamIndexItems(
    String baseUrl,
    List items, {
    String badge = 'STREAM',
    String? tag,
  }) {
    return items.whereType<Map>().map((item) {
      final rawUrl = (item['url'] as String?) ?? '';
      final vid = _extractIdFromPath(rawUrl);
      final views = item['views'] as int?;
      return MediaTrack(
        id: vid,
        title: (item['title'] as String?) ?? 'Remote Track',
        artist: (item['uploaderName'] as String?) ?? 'Remote Source',
        channelId: ((item['uploaderUrl'] as String?) ??
                (item['uploader'] as String?))
            ?.replaceAll('/channel/', ''),
        thumbnailUrl:
            _normalizeMediaUrl(baseUrl, (item['thumbnail'] as String?) ?? ''),
        durationSeconds: (item['duration'] as int?) ?? 210,
        source: TrackSource.customStream,
        qualityBadge: badge,
        recommendationTag: tag,
        viewCountLabel: views != null ? _formatViews(views) : null,
      );
    }).where((e) => e.id.isNotEmpty).toList();
  }

  static String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    }
    if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(0)}K views';
    }
    return '$views views';
  }
}
