import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_models.dart';
import '../services/database_service.dart';
import '../services/parked_detector.dart';
import '../services/sonic_audio_engine.dart';
import '../services/storage_scanner.dart';
import '../services/stream_resolver.dart';
import '../services/wifi_transfer_server.dart';
import '../utils/url_parser.dart';

// --- Navigation Tab Index (0: Home, 1: Search, 2: Library / Mobile User, 3: Settings) ---
final activeTabProvider = StateProvider<int>((ref) => 0);
final userHubSubTabProvider = StateProvider<int>((ref) => 0);

// --- Mobile Header Search Focus Trigger & One-Time Resume Banner Visibility ---
final searchFocusTriggerProvider = StateProvider<int>((ref) => 0);
final resumeCardVisibleProvider = StateProvider<bool>((ref) => true);

// --- Audio Engine Stream & State ---
final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) async* {
  yield SonicAudioEngine.instance.snapshot;
  yield* SonicAudioEngine.instance.stream;
});

// --- Vehicle Motion / Parked Detection ---
final vehicleMotionProvider = StreamProvider<VehicleMotionState>((ref) async* {
  yield ParkedDetector.instance.current;
  yield* ParkedDetector.instance.stream;
});

// --- App Settings Notifier ---
class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final s = await DatabaseService.instance.loadSettings();
    if (!mounted) return;
    state = s;
    SonicAudioEngine.instance.updateSettings(s);
    StreamResolver.instance.setCustomInstance(
      s.customServerUrl,
      defaultRaw: s.syncedDefaultServers,
    );
    _ref.read(serverInstancesProvider.notifier).sync();
    if (StreamResolver.instance.hasCustomServer) {
      unawaited(_ref
          .read(serverInstancesProvider.notifier)
          .runPingTest(sortByLatency: s.autoSelectFastestServer));
      await _ref.read(homeFeedProvider.notifier).refresh();
    }
    await ParkedDetector.instance.startMonitoring(enabled: s.gpsParkDetection);
  }

  Future<void> update(AppSettings next) async {
    if (!mounted) return;
    state = next;
    await DatabaseService.instance.saveSettings(next);
    SonicAudioEngine.instance.updateSettings(next);
    StreamResolver.instance.setCustomInstance(
      next.customServerUrl,
      defaultRaw: next.syncedDefaultServers,
    );
    _ref.read(serverInstancesProvider.notifier).sync();
    await ParkedDetector.instance
        .startMonitoring(enabled: next.gpsParkDetection);
  }

  /// Silently loads default remote server config JSON, merges user links + deduplicated
  /// default links, pings mirrors, and refreshes the home feed.
  Future<List<ServerInstance>> syncWithDefaultServers({
    String? overrideUserUrl,
    bool? overrideAutoSelectFastest,
  }) async {
    final fetchedDefault =
        await StreamResolver.instance.fetchDefaultServerConfigRaw();
    if (!mounted) return const [];

    final latest = state;
    final userUrl = overrideUserUrl ?? latest.customServerUrl;
    final autoFastest =
        overrideAutoSelectFastest ?? latest.autoSelectFastestServer;
    final effectiveDefault = fetchedDefault.isNotEmpty
        ? fetchedDefault
        : latest.syncedDefaultServers;

    final next = latest.copyWith(
      customServerUrl: userUrl,
      syncedDefaultServers: effectiveDefault,
      autoSelectFastestServer: autoFastest,
    );
    await update(next);
    final measured = await _ref
        .read(serverInstancesProvider.notifier)
        .runPingTest(sortByLatency: autoFastest);
    await _ref.read(homeFeedProvider.notifier).refresh();
    return measured;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

// --- Server Latency Instances ---
class ServerInstancesNotifier extends StateNotifier<List<ServerInstance>> {
  ServerInstancesNotifier() : super(StreamResolver.instance.instances);

  void sync() {
    state = StreamResolver.instance.instances;
  }

  Future<List<ServerInstance>> runPingTest({bool sortByLatency = true}) async {
    final measured = await StreamResolver.instance
        .pingInstances(sortByLatency: sortByLatency);
    if (!mounted) return measured;
    state = measured;
    return measured;
  }
}

final serverInstancesProvider =
    StateNotifierProvider<ServerInstancesNotifier, List<ServerInstance>>((ref) {
  return ServerInstancesNotifier();
});

// --- Home Screen Data (Resume + Listen Again + 70/30 Blended Feed) ---
class HomeFeedState {
  final MediaTrack? resumeTrack;
  final List<MediaTrack> listenAgain;
  final List<MediaTrack> recommendations;
  final List<FollowedChannel> followedChannels;
  final String selectedFilter;
  final bool isLoading;

  const HomeFeedState({
    this.resumeTrack,
    this.listenAgain = const [],
    this.recommendations = const [],
    this.followedChannels = const [],
    this.selectedFilter = 'All Blended',
    this.isLoading = false,
  });

  HomeFeedState copyWith({
    MediaTrack? resumeTrack,
    bool clearResume = false,
    List<MediaTrack>? listenAgain,
    List<MediaTrack>? recommendations,
    List<FollowedChannel>? followedChannels,
    String? selectedFilter,
    bool? isLoading,
  }) {
    return HomeFeedState(
      resumeTrack: clearResume ? null : (resumeTrack ?? this.resumeTrack),
      listenAgain: listenAgain ?? this.listenAgain,
      recommendations: recommendations ?? this.recommendations,
      followedChannels: followedChannels ?? this.followedChannels,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeFeedNotifier extends StateNotifier<HomeFeedState> {
  HomeFeedNotifier() : super(const HomeFeedState(isLoading: true)) {
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    final resume = await DatabaseService.instance.getLatestUnfinishedTrack();
    final history = await DatabaseService.instance.getListenAgainTracks();
    final trending = await StreamResolver.instance.fetchTrendingMusic();
    final localUsb = await StorageScanner.instance.scanInternalDeviceMusic();
    final followed = await DatabaseService.instance.getFollowedChannels();
    if (!mounted) return;

    final followedNames = followed
        .map((c) => c.channelName.toLowerCase().trim())
        .where((n) => n.isNotEmpty)
        .toSet();

    // 70% Habit / Related + 30% Trending Blended Interleaving
    final habitSamples = history.map((t) {
      return t.copyWith(
        recommendationTag: 'Based on your recent listening',
      );
    });
    final blended = <MediaTrack>[];
    final habitList = habitSamples.toList();
    final trendList = trending.toList();

    // Prioritize tracks from followed channels at the front of the feed
    final followedPrioritized = <MediaTrack>[];
    final nonFollowedHabit = <MediaTrack>[];
    for (final t in habitList) {
      if (followedNames.contains(t.artist.toLowerCase().trim())) {
        followedPrioritized.add(t);
      } else {
        nonFollowedHabit.add(t);
      }
    }

    final nonFollowedTrend = <MediaTrack>[];
    for (final t in trendList) {
      if (followedNames.contains(t.artist.toLowerCase().trim())) {
        followedPrioritized.add(t);
      } else {
        nonFollowedTrend.add(t);
      }
    }

    // Add prioritized followed tracks first
    blended.addAll(followedPrioritized);

    int hIdx = 0;
    int tIdx = 0;
    while (hIdx < nonFollowedHabit.length || tIdx < nonFollowedTrend.length) {
      for (int i = 0; i < 2 && hIdx < nonFollowedHabit.length; i++) {
        blended.add(nonFollowedHabit[hIdx++]);
      }
      if (tIdx < nonFollowedTrend.length) {
        blended.add(nonFollowedTrend[tIdx++]);
      }
    }

    // Add scanned offline tracks
    for (final local in localUsb) {
      blended.add(local);
    }

    state = state.copyWith(
      resumeTrack: resume,
      listenAgain: history,
      recommendations: blended,
      followedChannels: followed,
      isLoading: false,
    );
  }

  void selectFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }
}

final homeFeedProvider =
    StateNotifierProvider<HomeFeedNotifier, HomeFeedState>((ref) {
  return HomeFeedNotifier();
});

// --- Library Data (Hybrid Playlists + USB Hardware Drives + Local Files) ---
class LibraryState {
  final List<HybridPlaylist> playlists;
  final List<MediaTrack> likedTracks;
  final List<MediaTrack> offlineTracks;
  final List<MediaTrack> localDeviceTracks;
  final List<StorageDeviceInfo> usbDevices;
  final List<FollowedChannel> followedChannels;
  final String sortBy;

  const LibraryState({
    this.playlists = const [],
    this.likedTracks = const [],
    this.offlineTracks = const [],
    this.localDeviceTracks = const [],
    this.usbDevices = const [],
    this.followedChannels = const [],
    this.sortBy = 'Recent',
  });

  LibraryState copyWith({
    List<HybridPlaylist>? playlists,
    List<MediaTrack>? likedTracks,
    List<MediaTrack>? offlineTracks,
    List<MediaTrack>? localDeviceTracks,
    List<StorageDeviceInfo>? usbDevices,
    List<FollowedChannel>? followedChannels,
    String? sortBy,
  }) {
    return LibraryState(
      playlists: playlists ?? this.playlists,
      likedTracks: likedTracks ?? this.likedTracks,
      offlineTracks: offlineTracks ?? this.offlineTracks,
      localDeviceTracks: localDeviceTracks ?? this.localDeviceTracks,
      usbDevices: usbDevices ?? this.usbDevices,
      followedChannels: followedChannels ?? this.followedChannels,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool isFollowed(String channelId, {String? channelName}) {
    final cleanId = channelId.trim().toLowerCase();
    final cleanName = channelName?.trim().toLowerCase();
    return followedChannels.any((c) =>
        (cleanId.isNotEmpty && c.channelId.toLowerCase() == cleanId) ||
        (cleanName != null &&
            cleanName.isNotEmpty &&
            c.channelName.toLowerCase() == cleanName));
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    refresh();
  }

  Future<void> refresh() async {
    final pls = await DatabaseService.instance.getPlaylists();
    final liked = await DatabaseService.instance.getLikedTracks();
    final offline = await DatabaseService.instance.getOfflineTracks();
    final followed = await DatabaseService.instance.getFollowedChannels();
    if (!mounted) return;
    state = state.copyWith(
      playlists: pls,
      likedTracks: liked,
      offlineTracks: offline,
      followedChannels: followed,
    );

    final deviceTracks =
        await StorageScanner.instance.scanInternalDeviceMusic();
    final usbDrives = await StorageScanner.instance.detectHardwareDrives();
    if (!mounted) return;

    state = state.copyWith(
      localDeviceTracks: deviceTracks,
      usbDevices: usbDrives,
    );
  }

  bool isFollowed(String channelId, {String? channelName}) {
    final cleanId = channelId.trim().toLowerCase();
    final cleanName = channelName?.trim().toLowerCase();
    return state.followedChannels.any((c) =>
        (cleanId.isNotEmpty && c.channelId.toLowerCase() == cleanId) ||
        (cleanName != null &&
            cleanName.isNotEmpty &&
            c.channelName.toLowerCase() == cleanName));
  }

  Future<bool> toggleFollowChannel(FollowedChannel channel) async {
    final currentlyFollowed = isFollowed(
      channel.channelId,
      channelName: channel.channelName,
    );
    if (currentlyFollowed) {
      await DatabaseService.instance.unfollowChannel(
        channel.channelId,
        channelName: channel.channelName,
      );
    } else {
      await DatabaseService.instance.followChannel(channel);
    }
    await refresh();
    return !currentlyFollowed;
  }

  Future<void> updateFollowedChannel(FollowedChannel channel) async {
    await DatabaseService.instance.followChannel(channel);
    await refresh();
  }

  Future<HybridPlaylist> createPlaylist(String name,
      {List<MediaTrack> initialTracks = const []}) async {
    final created = await DatabaseService.instance
        .createPlaylist(name, initialTracks: initialTracks);
    await refresh();
    return created;
  }

  Future<void> addTrackToPlaylist(String playlistId, MediaTrack track) async {
    await DatabaseService.instance.addTrackToPlaylist(playlistId, track);
    await refresh();
  }

  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackId) async {
    await DatabaseService.instance
        .removeTrackFromPlaylist(playlistId, trackId);
    await refresh();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await DatabaseService.instance.deletePlaylist(playlistId);
    await refresh();
  }

  void setSort(String sort) {
    final sorted = List<HybridPlaylist>.from(state.playlists);
    if (sort == 'Name A-Z') {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else if (sort == 'Most Tracks') {
      sorted.sort((a, b) => b.items.length.compareTo(a.items.length));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    state = state.copyWith(playlists: sorted, sortBy: sort);
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier();
});

// --- Search State ---
class SearchState {
  final String query;
  final String sourceFilter;
  final List<String> recentSearches;
  final List<MediaTrack> results;
  final bool isSearching;
  final bool isLoadingMore;
  final int nextPage;
  final String? nextToken;
  final bool hasMore;
  final bool isVoiceHudOpen;

  const SearchState({
    this.query = '',
    this.sourceFilter = 'All Sources',
    this.recentSearches = const [],
    this.results = const [],
    this.isSearching = false,
    this.isLoadingMore = false,
    this.nextPage = 1,
    this.nextToken,
    this.hasMore = false,
    this.isVoiceHudOpen = false,
  });

  SearchState copyWith({
    String? query,
    String? sourceFilter,
    List<String>? recentSearches,
    List<MediaTrack>? results,
    bool? isSearching,
    bool? isLoadingMore,
    int? nextPage,
    String? nextToken,
    bool clearNextToken = false,
    bool? hasMore,
    bool? isVoiceHudOpen,
  }) {
    return SearchState(
      query: query ?? this.query,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      recentSearches: recentSearches ?? this.recentSearches,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextPage: nextPage ?? this.nextPage,
      nextToken: clearNextToken ? null : (nextToken ?? this.nextToken),
      hasMore: hasMore ?? this.hasMore,
      isVoiceHudOpen: isVoiceHudOpen ?? this.isVoiceHudOpen,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState()) {
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final recent = await DatabaseService.instance.getRecentSearches();
    if (!mounted) return;
    state = state.copyWith(recentSearches: recent);
  }

  Future<void> executeSearch(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) {
      state = state.copyWith(
        query: '',
        results: [],
        isSearching: false,
        isLoadingMore: false,
        nextPage: 1,
        hasMore: false,
      );
      return;
    }

    // Check if user pasted a direct media URL or custom stream URL inside Search
    final urlMatch = UrlParser.parse(q);
    if (urlMatch != null) {
      state = state.copyWith(
        query: q,
        isSearching: true,
        isLoadingMore: false,
        hasMore: false,
      );
      if (urlMatch.type == MediaUrlType.directMedia ||
          urlMatch.type == MediaUrlType.streamItem) {
        final bundle = await StreamResolver.instance.resolveTrack(urlMatch.id);
        if (!mounted) return;
        if (bundle != null) {
          state = state.copyWith(results: [bundle.track], isSearching: false);
          await SonicAudioEngine.instance.playTrack(bundle.track,
              relatedForAutoQueue: bundle.relatedTracks);
          return;
        }
      } else {
        final pl = await StreamResolver.instance.fetchPlaylist(urlMatch.id);
        if (!mounted) return;
        if (pl != null && pl.tracks.isNotEmpty) {
          state = state.copyWith(results: pl.tracks, isSearching: false);
          return;
        }
      }
    }

    state = state.copyWith(
      query: q,
      isSearching: true,
      isLoadingMore: false,
      nextPage: 1,
      clearNextToken: true,
      hasMore: false,
    );
    await DatabaseService.instance.addRecentSearch(q);
    final recent = await DatabaseService.instance.getRecentSearches();
    if (!mounted) return;

    final lib = _ref.read(libraryProvider);
    final lower = q.toLowerCase();

    // Search offline local/USB files & offline Drive cache matching query
    final offlineMatches = [
      ...lib.localDeviceTracks,
      ...lib.offlineTracks,
      ...lib.likedTracks.where((t) => t.source.isOfflineCapable),
    ].where((t) =>
        t.title.toLowerCase().contains(lower) ||
        t.artist.toLowerCase().contains(lower));

    // Search remote source via user-configured Custom Server (50 items Page 1 batch)
    final page = await StreamResolver.instance.searchRemotePage(
      q,
      startPage: 1,
      targetCount: 50,
    );
    if (!mounted) return;

    final followed = await DatabaseService.instance.getFollowedChannels();
    final followedNames = followed
        .map((c) => c.channelName.toLowerCase().trim())
        .where((n) => n.isNotEmpty)
        .toSet();

    final allRaw = [...offlineMatches, ...page.tracks];
    final prioritizedFollowed = <MediaTrack>[];
    final otherResults = <MediaTrack>[];
    for (final t in allRaw) {
      if (followedNames.contains(t.artist.toLowerCase().trim())) {
        prioritizedFollowed.add(t);
      } else {
        otherResults.add(t);
      }
    }

    state = state.copyWith(
      recentSearches: recent,
      results: [...prioritizedFollowed, ...otherResults],
      isSearching: false,
      nextPage: page.nextPage,
      nextToken: page.nextToken,
      clearNextToken: page.nextToken == null,
      hasMore: page.hasMore,
    );
  }

  /// Background pagination when scrolling near the end of Search results.
  Future<void> loadMore() async {
    if (state.isSearching ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.query.isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);

    final page = await StreamResolver.instance.searchRemotePage(
      state.query,
      startPage: state.nextPage,
      nextToken: state.nextToken,
      targetCount: 50,
    );
    if (!mounted) return;

    final existingIds = state.results.map((e) => e.id).toSet();
    final uniqueNew = page.tracks
        .where((t) => !existingIds.contains(t.id))
        .toList();

    state = state.copyWith(
      results: [...state.results, ...uniqueNew],
      isLoadingMore: false,
      nextPage: page.nextPage,
      nextToken: page.nextToken,
      clearNextToken: page.nextToken == null,
      hasMore: page.hasMore && uniqueNew.isNotEmpty,
    );
  }

  void setSourceFilter(String filter) {
    state = state.copyWith(sourceFilter: filter);
  }

  void setVoiceHud(bool open) {
    state = state.copyWith(isVoiceHudOpen: open);
  }

  Future<void> removeRecent(String query) async {
    await DatabaseService.instance.removeRecentSearch(query);
    await _loadRecent();
  }

  Future<void> clearRecent() async {
    await DatabaseService.instance.clearRecentSearches();
    await _loadRecent();
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

// --- Clipboard Link Auto-Detection ---
class ClipboardBannerNotifier extends StateNotifier<MediaUrlMatch?> {
  ClipboardBannerNotifier() : super(null);
  String? _dismissedUrl;

  Future<void> checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text == _dismissedUrl) return;
      final match = UrlParser.parse(text);
      if (match != null) {
        state = match;
      }
    } catch (_) {}
  }

  void dismiss() {
    _dismissedUrl = state?.originalUrl;
    state = null;
  }
}

final clipboardBannerProvider =
    StateNotifierProvider<ClipboardBannerNotifier, MediaUrlMatch?>((ref) {
  return ClipboardBannerNotifier();
});

// --- Wi-Fi Transfer Server State ---
class WifiServerState {
  final bool isRunning;
  final String serverUrl;
  final List<MediaTrack> uploadedTracks;

  const WifiServerState({
    this.isRunning = false,
    this.serverUrl = 'http://127.0.0.1:8080',
    this.uploadedTracks = const [],
  });

  WifiServerState copyWith({
    bool? isRunning,
    String? serverUrl,
    List<MediaTrack>? uploadedTracks,
  }) {
    return WifiServerState(
      isRunning: isRunning ?? this.isRunning,
      serverUrl: serverUrl ?? this.serverUrl,
      uploadedTracks: uploadedTracks ?? this.uploadedTracks,
    );
  }
}

class WifiServerNotifier extends StateNotifier<WifiServerState> {
  final Ref _ref;

  WifiServerNotifier(this._ref) : super(const WifiServerState()) {
    WifiTransferServer.instance.onTrackUploaded.listen((track) {
      state = state.copyWith(
        uploadedTracks: [track, ...state.uploadedTracks],
      );
      _ref.read(libraryProvider.notifier).refresh();
    });
  }

  Future<void> toggle() async {
    if (state.isRunning) {
      await WifiTransferServer.instance.stop();
      state = state.copyWith(isRunning: false);
    } else {
      final url = await WifiTransferServer.instance.start();
      state = state.copyWith(isRunning: true, serverUrl: url);
    }
  }
}

final wifiServerProvider =
    StateNotifierProvider<WifiServerNotifier, WifiServerState>((ref) {
  return WifiServerNotifier(ref);
});

final channelDetailsProvider = FutureProvider.family<
    ChannelDetails?,
    ({String channelId, String? channelName})>((ref, arg) async {
  return StreamResolver.instance
      .fetchChannelDetails(arg.channelId, channelName: arg.channelName);
});
