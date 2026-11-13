import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:soniclane/core/models/media_models.dart';
import 'package:soniclane/core/providers/sonic_providers.dart';
import 'package:soniclane/core/services/cloud_drive_service.dart';
import 'package:soniclane/core/services/database_service.dart';
import 'package:soniclane/core/services/lyrics_service.dart';
import 'package:soniclane/core/services/sonic_audio_engine.dart';
import 'package:soniclane/core/services/storage_scanner.dart';
import 'package:soniclane/core/services/stream_resolver.dart';

void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    testDir = await Directory.systemTemp.createTemp('soniclane_services_test_');
    DatabaseService.testDbDirectoryPath = testDir.path;
    StorageScanner.testDropDirectoryPath = testDir.path;
    await DatabaseService.instance.database;
    await SonicAudioEngine.instance.initialize(testMode: true);
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('DatabaseService Hybrid Playlist & Resume Tests', () {
    test('persists unfinished resume track and hybrid playlist items', () async {
      const streamTrack = MediaTrack(
        id: 'test_stream_1',
        title: 'Test Remote Stream Track',
        artist: 'Creator',
        thumbnailUrl: '',
        durationSeconds: 300,
        source: TrackSource.customStream,
      );
      const usbTrack = MediaTrack(
        id: 'test_usb_1',
        title: 'Test USB FLAC',
        artist: 'USB Drive',
        thumbnailUrl: '',
        durationSeconds: 240,
        source: TrackSource.usb,
        localPath: '/nonexistent/sample.flac',
      );

      await DatabaseService.instance.recordPlayProgress(streamTrack, 95000);
      final latest = await DatabaseService.instance.getLatestUnfinishedTrack();
      expect(latest, isNotNull);
      expect(latest!.id, 'test_stream_1');
      expect(latest.lastPositionMs, 95000);

      final pl = await DatabaseService.instance.createPlaylist(
        'Test Hybrid Mix',
        initialTracks: [streamTrack, usbTrack],
      );
      expect(pl.streamCount, 1);
      expect(pl.usbCount, 1);

      final fetched = await DatabaseService.instance.getPlaylists();
      final matched = fetched.firstWhere((e) => e.id == pl.id);
      expect(matched.items.length, 2);
      // Local nonexistent path marks track unavailable gracefully
      expect(matched.items[1].isAvailable, isFalse);
    });
  });

  group('SonicAudioEngine Steering Wheel Queue Tests', () {
    test('skipToPrevious restarts if >3s and navigates back if <=3s', () async {
      const t1 = MediaTrack(
        id: 'q1',
        title: 'Track 1',
        artist: 'A1',
        thumbnailUrl: '',
        durationSeconds: 200,
        source: TrackSource.local,
        localPath: '/tmp/q1.mp3',
      );
      const t2 = MediaTrack(
        id: 'q2',
        title: 'Track 2',
        artist: 'A2',
        thumbnailUrl: '',
        durationSeconds: 200,
        source: TrackSource.local,
        localPath: '/tmp/q2.mp3',
      );

      await SonicAudioEngine.instance.playTrack(t1, queue: [t1, t2]);
      await SonicAudioEngine.instance.skipToNext();
      expect(SonicAudioEngine.instance.snapshot.currentTrack?.id, 'q2');

      // Simulate > 3s playback -> skipToPrevious seeks back to 0 on q2
      await SonicAudioEngine.instance.seekTo(const Duration(seconds: 12));
      await SonicAudioEngine.instance.skipToPrevious();
      expect(SonicAudioEngine.instance.snapshot.currentTrack?.id, 'q2');
      expect(SonicAudioEngine.instance.snapshot.position, Duration.zero);

      // Now at <= 3s -> skipToPrevious pops history back to q1
      await SonicAudioEngine.instance.skipToPrevious();
      expect(SonicAudioEngine.instance.snapshot.currentTrack?.id, 'q1');
    });
  });

  group('CloudDriveService Tests', () {
    test('extracts Google Drive file ID and folder ID cleanly', () {
      const fileUrl =
          'https://drive.google.com/file/d/1aBcDeFgHiJkLmNoPqRsTuVwXyZ123456/view?usp=sharing';
      const folderUrl =
          'https://drive.google.com/drive/folders/0B123456789abcdef?usp=drive_link';

      expect(CloudDriveService.instance.extractFileId(fileUrl),
          '1aBcDeFgHiJkLmNoPqRsTuVwXyZ123456');
      expect(CloudDriveService.instance.extractFolderId(folderUrl),
          '0B123456789abcdef');

      final track = CloudDriveService.instance.buildTrackFromShareUrl(
        shareUrl: fileUrl,
        customTitle: 'Drive Lossless Mix',
      );
      expect(track.source, TrackSource.googleDrive);
      expect(track.title, 'Drive Lossless Mix');
      expect(track.streamUrl,
          'https://drive.google.com/uc?export=download&id=1aBcDeFgHiJkLmNoPqRsTuVwXyZ123456');
    });
  });

  group('SonicAudioHandler Android Auto Browse & Play Tests', () {
    test('exposes browsable directories, playlist children, liked songs, and playFromMediaId',
        () async {
      final handler = SonicAudioHandler(SonicAudioEngine.instance);
      final rootChildren =
          await handler.getChildren(AudioService.browsableRootId);
      expect(
        rootChildren.map((e) => e.id).toList(),
        ['sonic_explore', 'sonic_playlists', 'sonic_liked', 'sonic_offline'],
      );
      expect(rootChildren.every((e) => e.playable == false), isTrue);

      const likedLocal = MediaTrack(
        id: 'aa_local_1',
        title: 'Android Auto Local Mix',
        artist: 'Cockpit USB',
        thumbnailUrl: '',
        durationSeconds: 185,
        source: TrackSource.usb,
        localPath: '/tmp/aa_local_1.flac',
      );
      await DatabaseService.instance.toggleLikeTrack(likedLocal);
      final pl = await DatabaseService.instance.createPlaylist(
        'Auto Browse Mix',
        initialTracks: [likedLocal],
      );

      final playlists = await handler.getChildren('sonic_playlists');
      expect(playlists.any((p) => p.id == 'pl_dir_${pl.id}'), isTrue);

      final plTracks = await handler.getChildren('pl_dir_${pl.id}');
      expect(plTracks.length, 1);
      expect(plTracks.first.id, 'pl_${pl.id}__aa_local_1');
      expect(plTracks.first.playable, isTrue);

      final liked = await handler.getChildren('sonic_liked');
      expect(liked.any((t) => t.id == 'aa_local_1'), isTrue);

      await handler.playFromMediaId('pl_${pl.id}__aa_local_1');
      expect(SonicAudioEngine.instance.snapshot.currentTrack?.id, 'aa_local_1');
      expect(SonicAudioEngine.instance.snapshot.activePlaylistName,
          'Auto Browse Mix');
    });
  });

  group('SonicAudioEngine Offline Fallback & Status Banner Tests', () {
    test('emits statusBanner when online stream resolution fails with no offline fallback',
        () async {
      StreamResolver.testOfflineMode = true;
      addTearDown(() => StreamResolver.testOfflineMode = false);

      const unreachableTrack = MediaTrack(
        id: 'offline_fail_stream_999',
        title: 'Unreachable Stream',
        artist: 'Network Test',
        thumbnailUrl: '',
        durationSeconds: 210,
        source: TrackSource.customStream,
      );

      await SonicAudioEngine.instance.playTrack(unreachableTrack);
      final snap = SonicAudioEngine.instance.snapshot;
      expect(snap.isBuffering, isFalse);
      expect(snap.statusBanner, isNotNull);
      expect(snap.statusBanner, contains('Stream unavailable'));
    });

    test('preserves Video Mode preference across newly selected tracks until switched back to Audio',
        () async {
      addTearDown(() => SonicAudioEngine.instance.setVideoMode(false));
      await SonicAudioEngine.instance.setVideoMode(true);
      expect(SonicAudioEngine.instance.preferredVideoMode, isTrue);

      const nextLocal = MediaTrack(
        id: 'vid_sticky_1',
        title: 'Sticky Video Track',
        artist: 'Test Artist',
        thumbnailUrl: '',
        durationSeconds: 180,
        source: TrackSource.local,
        localPath: '/tmp/vid_sticky_1.mp4',
      );
      await SonicAudioEngine.instance.playTrack(nextLocal);
      expect(SonicAudioEngine.instance.snapshot.isVideoMode, isTrue);

      await SonicAudioEngine.instance.setVideoMode(false);
      expect(SonicAudioEngine.instance.preferredVideoMode, isFalse);
      await SonicAudioEngine.instance.playTrack(nextLocal);
      expect(SonicAudioEngine.instance.snapshot.isVideoMode, isFalse);
    });
  });

  group('LyricsService LRC & VTT Parser Tests', () {
    test('parses LRC and WebVTT timestamps in sorted order', () {
      const lrc = '[00:12.50]First line\n[00:05.00]Intro line\n[01:02.120]Chorus';
      final parsedLrc = LyricsService.parseLrc(lrc);
      expect(parsedLrc.length, 3);
      expect(parsedLrc.first.text, 'Intro line');
      expect(parsedLrc.first.time, const Duration(seconds: 5));
      expect(parsedLrc.last.time, const Duration(minutes: 1, seconds: 2, milliseconds: 120));

      const vtt = 'WEBVTT\n\n00:00:04.500 --> 00:00:08.000\n<i>Highway</i> lights\n\n00:01:10.000 --> 00:01:14.000\nMidnight drive';
      final parsedVtt = LyricsService.parseVtt(vtt);
      expect(parsedVtt.length, 2);
      expect(parsedVtt.first.text, 'Highway lights');
      expect(parsedVtt.last.time, const Duration(minutes: 1, seconds: 10));
    });
  });

  group('StreamResolver Normalization, Health Check & Dual Protocol Tests', () {
    test('auto-adds https:// for public domains, http:// for local hosts, and parses JSON entries',
        () {
      expect(
        StreamResolver.formatNormalizedServerInput('media.example.com'),
        'https://media.example.com',
      );
      expect(
        StreamResolver.formatNormalizedServerInput('localhost:3000'),
        'http://localhost:3000',
      );
      expect(
        StreamResolver.formatNormalizedServerInput('192.168.1.50:8080/'),
        'http://192.168.1.50:8080',
      );
      expect(
        StreamResolver.formatNormalizedServerInput(
            'https://one.example.com/, two.example.com'),
        'https://one.example.com, https://two.example.com',
      );
      expect(
        StreamResolver.formatNormalizedServerInput(
            '{"servers": ["alpha.example.com", "127.0.0.1:8080"]}'),
        'https://alpha.example.com, http://127.0.0.1:8080',
      );
    });

    test('flags HTML websites instead of green health and searches JSON Media API v1 / Stream Index API + .json config URL',
        () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);
      StreamResolver.testOfflineMode = false;

      // 1. HTML portal mock (returns 200 HTML even on /api/v1/stats)
      final htmlServer = await shelf_io.serve(
        (shelf.Request req) => shelf.Response.ok(
          '<!doctype html><html><body>Web Portal</body></html>',
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
        InternetAddress.loopbackIPv4,
        0,
      );

      // 2. JSON Media API v1 mock (configured with domain:port only to test auto http://)
      final v1Server = await shelf_io.serve(
        (shelf.Request req) {
          if (req.url.path == 'api/v1/stats') {
            return shelf.Response.ok(
              jsonEncode({'software': {'name': 'open-media-v1'}}),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'api/v1/search') {
            return shelf.Response.ok(
              jsonEncode([
                {
                  'videoId': 'v1_track_1',
                  'title': 'Midnight Test Song',
                  'author': 'Test Artist',
                  'lengthSeconds': 215,
                  'viewCount': 5000,
                }
              ]),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'api/v1/videos/v1_track_1') {
            final isLocalProxy = req.url.queryParameters['local'] == 'true';
            if (!isLocalProxy) {
              // Simulate IP-locked direct CDN returning 403
              return shelf.Response.ok(
                jsonEncode({
                  'title': 'Midnight Test Song',
                  'author': 'Test Artist',
                  'lengthSeconds': 215,
                  'adaptiveFormats': [
                    {
                      'type': 'audio/mp4; codecs="mp4a.40.2"',
                      'bitrate': '128000',
                      'url':
                          'http://127.0.0.1:${req.requestedUri.port}/forbidden_audio.m4a',
                    }
                  ],
                  'formatStreams': [
                    {
                      'qualityLabel': '720p',
                      'url':
                          'http://127.0.0.1:${req.requestedUri.port}/forbidden_video.mp4',
                    }
                  ],
                }),
                headers: {'content-type': 'application/json'},
              );
            }
            // ?local=true proxy returns relative proxied URLs
            return shelf.Response.ok(
              jsonEncode({
                'title': 'Midnight Test Song',
                'author': 'Test Artist',
                'lengthSeconds': 215,
                'adaptiveFormats': [
                  {
                    'type': 'audio/mp4; codecs="mp4a.40.2"',
                    'bitrate': '128000',
                    'url': '/proxy_audio.m4a',
                  }
                ],
                'formatStreams': [
                  {
                    'qualityLabel': '720p',
                    'url': '/proxy_video.mp4',
                  }
                ],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'forbidden_audio.m4a' ||
              req.url.path == 'forbidden_video.mp4') {
            return shelf.Response(403, body: 'Forbidden');
          }
          if (req.url.path == 'proxy_audio.m4a') {
            return shelf.Response.ok(
              utf8.encode('fake-audio-bytes'),
              headers: {'content-type': 'audio/mp4'},
            );
          }
          if (req.url.path == 'proxy_video.mp4') {
            return shelf.Response.ok(
              utf8.encode('fake-video-bytes'),
              headers: {'content-type': 'video/mp4'},
            );
          }
          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      // 3. JSON Stream Index API mock + hosted .json config endpoint
      final indexServer = await shelf_io.serve(
        (shelf.Request req) {
          if (req.url.path == 'sources.json') {
            return shelf.Response.ok(
              jsonEncode({
                'servers': ['http://127.0.0.1:${v1Server.port}'],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'trending') {
            return shelf.Response.ok(
              jsonEncode([]),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'search') {
            return shelf.Response.ok(
              jsonEncode({
                'items': [
                  {
                    'url': '/watch?v=idx_track_1',
                    'title': 'Highway Stream Track',
                    'uploaderName': 'Stream Creator',
                    'duration': 195,
                    'views': 1200,
                  }
                ],
                'nextpage': null,
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      try {
        addTearDown(() => StreamResolver.instance.setCustomInstance(''));

        final expanded = await StreamResolver.instance.expandServerConfigInput(
            '127.0.0.1:${indexServer.port}/sources.json');
        expect(expanded, 'http://127.0.0.1:${v1Server.port}');

        StreamResolver.instance
            .setCustomInstance('127.0.0.1:${htmlServer.port}');
        final htmlProbe = await StreamResolver.instance.pingInstances();
        expect(htmlProbe.first.isHealthy, isFalse);
        expect(htmlProbe.first.tier, 'HTML Website');

        StreamResolver.instance
            .setCustomInstance('127.0.0.1:${v1Server.port}');
        final v1Probe = await StreamResolver.instance.pingInstances();
        expect(v1Probe.first.isHealthy, isTrue);
        expect(v1Probe.first.tier, 'JSON Media API (v1)');
        final v1Page =
            await StreamResolver.instance.searchRemotePage('Midnight');
        expect(v1Page.tracks.length, 1);
        expect(v1Page.tracks.first.id, 'v1_track_1');
        final v1Resolved =
            await StreamResolver.instance.resolveTrack('v1_track_1');
        expect(v1Resolved, isNotNull);
        expect(v1Resolved!.track.videoHasAudio, isTrue);
        expect(v1Resolved.track.streamUrl,
            'http://127.0.0.1:${v1Server.port}/proxy_audio.m4a');
        expect(v1Resolved.track.videoStreamUrl,
            'http://127.0.0.1:${v1Server.port}/proxy_video.mp4');

        StreamResolver.instance
            .setCustomInstance('127.0.0.1:${indexServer.port}');
        final idxProbe = await StreamResolver.instance.pingInstances();
        expect(idxProbe.first.isHealthy, isTrue);
        expect(idxProbe.first.tier, 'JSON Stream Index API');
        final idxPage =
            await StreamResolver.instance.searchRemotePage('Highway');
        expect(idxPage.tracks.length, 1);
        expect(idxPage.tracks.first.id, 'idx_track_1');
      } finally {
        await htmlServer.close(force: true);
        await v1Server.close(force: true);
        await indexServer.close(force: true);
      }
    });

    test('resolves adaptive H.264 video-only, live HLS, and direct audio-only fallback cleanly',
        () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);
      StreamResolver.testOfflineMode = false;

      final mockServer = await shelf_io.serve(
        (shelf.Request req) {
          if (req.url.path == 'api/v1/videos/adapt_track') {
            return shelf.Response.ok(
              jsonEncode({
                'title': 'Adaptive 720p Mix',
                'author': 'Studio Source',
                'lengthSeconds': 300,
                'adaptiveFormats': [
                  {
                    'type': 'audio/mp4; codecs="mp4a.40.2"',
                    'bitrate': '128000',
                    'url': '/ok_audio.m4a',
                  },
                  {
                    'type': 'video/mp4; codecs="avc1.4d401f"',
                    'qualityLabel': '720p',
                    'url': '/ok_video_only.mp4',
                  },
                ],
                'formatStreams': [
                  {'qualityLabel': '360p', 'url': '/dead_muxed.mp4'},
                ],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'api/v1/videos/live_track') {
            return shelf.Response.ok(
              jsonEncode({
                'title': '24/7 Chill Radio Live',
                'author': 'Live Channel',
                'liveNow': true,
                'hlsUrl': '/live/playlist.m3u8',
                'adaptiveFormats': [
                  {
                    'type': 'audio/mp4',
                    'bitrate': '128000',
                    'url': '/ok_audio.m4a'
                  },
                ],
                'formatStreams': [],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'api/v1/videos/audio_only_track') {
            final isProxy = req.url.queryParameters['local'] == 'true';
            return shelf.Response.ok(
              jsonEncode({
                'title': 'Audio Fallback Track',
                'author': 'Artist',
                'lengthSeconds': 180,
                'adaptiveFormats': [
                  {
                    'type': 'audio/mp4',
                    'bitrate': '128000',
                    'url': isProxy ? '/dead_muxed.mp4' : '/ok_audio.m4a',
                  },
                ],
                'formatStreams': [
                  {'qualityLabel': '360p', 'url': '/dead_muxed.mp4'},
                ],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == 'ok_audio.m4a' ||
              req.url.path == 'ok_video_only.mp4') {
            return shelf.Response.ok(
              utf8.encode('stream-ok'),
              headers: {'content-type': 'video/mp4'},
            );
          }
          if (req.url.path == 'live/playlist.m3u8') {
            return shelf.Response.ok(
              '#EXTM3U\n#EXTINF:10.0,\nseg0.ts\n',
              headers: {'content-type': 'application/vnd.apple.mpegurl'},
            );
          }
          return shelf.Response(403, body: 'Forbidden');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      try {
        addTearDown(() => StreamResolver.instance.setCustomInstance(''));
        StreamResolver.instance.setCustomInstance('127.0.0.1:${mockServer.port}');

        final adapt =
            await StreamResolver.instance.resolveTrack('adapt_track');
        expect(adapt, isNotNull);
        expect(adapt!.track.videoHasAudio, isFalse);
        expect(adapt.track.streamUrl,
            'http://127.0.0.1:${mockServer.port}/ok_audio.m4a');
        expect(adapt.track.videoStreamUrl,
            'http://127.0.0.1:${mockServer.port}/ok_video_only.mp4');

        final live = await StreamResolver.instance.resolveTrack('live_track');
        expect(live, isNotNull);
        expect(live!.track.videoHasAudio, isTrue);
        expect(live.track.videoStreamUrl,
            'http://127.0.0.1:${mockServer.port}/live/playlist.m3u8');

        final audioOnly =
            await StreamResolver.instance.resolveTrack('audio_only_track');
        expect(audioOnly, isNotNull);
        expect(audioOnly!.track.streamUrl,
            'http://127.0.0.1:${mockServer.port}/ok_audio.m4a');
        expect(audioOnly.track.videoStreamUrl, isNull);
        expect(audioOnly.track.videoHasAudio, isFalse);
      } finally {
        await mockServer.close(force: true);
      }
    });

    test('silently syncs default JSON config, supports .js JSON URL, and deduplicates user links',
        () async {
      final prevHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevHttpOverrides);
      StreamResolver.testOfflineMode = false;

      // Mirror 1: healthy but slower (30ms delay)
      final mirrorSlow = await shelf_io.serve(
        (shelf.Request req) async {
          await Future.delayed(const Duration(milliseconds: 30));
          if (req.url.path == 'api/v1/stats') {
            return shelf.Response.ok(jsonEncode({'ok': true}),
                headers: {'content-type': 'application/json'});
          }
          if (req.url.path == 'api/v1/search') {
            return shelf.Response.ok(jsonEncode([]),
                headers: {'content-type': 'application/json'});
          }
          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      // Mirror 2: healthy and fast (0ms delay)
      final mirrorFast = await shelf_io.serve(
        (shelf.Request req) {
          if (req.url.path == 'api/v1/stats') {
            return shelf.Response.ok(jsonEncode({'ok': true}),
                headers: {'content-type': 'application/json'});
          }
          if (req.url.path == 'api/v1/search') {
            return shelf.Response.ok(jsonEncode([]),
                headers: {'content-type': 'application/json'});
          }
          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      // Config host serving both soniclane.json and soniclane.js
      final configHost = await shelf_io.serve(
        (shelf.Request req) {
          if (req.url.path == 'mdsl/soniclane.json' ||
              req.url.path == 'mdsl/soniclane.js') {
            return shelf.Response.ok(
              jsonEncode({
                'schemaVersion': 1,
                'servers': [
                  'http://127.0.0.1:${mirrorSlow.port}',
                  'http://127.0.0.1:${mirrorFast.port}',
                ],
              }),
              headers: {'content-type': 'application/json'},
            );
          }
          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        StreamResolver.defaultServerConfigUrl =
            StreamResolver.kDefaultServerConfigUrl;
        StreamResolver.instance.setCustomInstance('');
      });

      try {
        StreamResolver.defaultServerConfigUrl =
            'http://127.0.0.1:${configHost.port}/mdsl/soniclane.json';

        // Also verifies .js JSON URL works in expandServerConfigInput
        final jsExpanded = await StreamResolver.instance.expandServerConfigInput(
            'http://127.0.0.1:${configHost.port}/mdsl/soniclane.js');
        expect(
          jsExpanded,
          'http://127.0.0.1:${mirrorSlow.port}, http://127.0.0.1:${mirrorFast.port}',
        );

        // User enters mirrorSlow (overlaps default) + a custom host
        final userUrl = '127.0.0.1:${mirrorSlow.port}, https://user-only.invalid';
        final mergedWithUser = await container
            .read(settingsProvider.notifier)
            .syncWithDefaultServers(
              overrideUserUrl: userUrl,
              overrideAutoSelectFastest: false,
            );

        // With autoSelectFastest = false: user entries stay first, duplicate mirrorSlow dropped from default
        expect(
          mergedWithUser.map((e) => e.url).toList(),
          [
            'http://127.0.0.1:${mirrorSlow.port}',
            'https://user-only.invalid',
            'http://127.0.0.1:${mirrorFast.port}',
          ],
        );

        // User input stays preserved in settings.customServerUrl (default cached separately)
        expect(container.read(settingsProvider).customServerUrl, userUrl);

        // Toggle Auto-Select Fastest Server Mirror ON -> re-syncs and moves healthy mirrorFast first
        final sortedFastest = await container
            .read(settingsProvider.notifier)
            .syncWithDefaultServers(overrideAutoSelectFastest: true);
        expect(sortedFastest.length, 3);
        expect(sortedFastest.first.isHealthy, isTrue);

        // Verify a server with 200 /stats but 401 /search is flagged Blocked (not green)
        final blockedSearch = await shelf_io.serve(
          (shelf.Request req) {
            if (req.url.path == 'api/v1/stats') {
              return shelf.Response.ok(jsonEncode({'ok': true}),
                  headers: {'content-type': 'application/json'});
            }
            if (req.url.path == 'api/v1/search') {
              return shelf.Response(401,
                  body: jsonEncode({'error': 'access_denied'}),
                  headers: {'content-type': 'application/json'});
            }
            return shelf.Response.notFound('Not found');
          },
          InternetAddress.loopbackIPv4,
          0,
        );
        try {
          StreamResolver.instance
              .setCustomInstance('127.0.0.1:${blockedSearch.port}');
          final probed = await StreamResolver.instance.pingInstances();
          expect(probed.first.isHealthy, isFalse);
          expect(probed.first.tier, 'Blocked / Anti-Bot');
        } finally {
          await blockedSearch.close(force: true);
        }
      } finally {
        await mirrorSlow.close(force: true);
        await mirrorFast.close(force: true);
        await configHost.close(force: true);
      }
    });

    test('Fast resolution: includeVideo=false skips video/proxy, parallel probes, cache & forceProxy',
        () async {
      StreamResolver.testOfflineMode = false;
      addTearDown(() => StreamResolver.instance.setCustomInstance(''));

      var metadataCalls = 0;
      var proxyMetadataCalls = 0;
      var videoProbeCalls = 0;

      late final HttpServer server;
      server = await shelf_io.serve(
        (shelf.Request req) async {
          final base = 'http://127.0.0.1:${server.port}';
          if (req.url.path == 'api/v1/videos/fast_track') {
            if (req.url.queryParameters['local'] == 'true') {
              proxyMetadataCalls++;
              return shelf.Response.ok(
                jsonEncode({
                  'title': 'Fast Proxy Track',
                  'author': 'Tester',
                  'lengthSeconds': 120,
                  'adaptiveFormats': [
                    {
                      'type': 'audio/mp4; codecs="mp4a.40.2"',
                      'bitrate': '128000',
                      'url': '$base/media/proxy_audio.m4a',
                    },
                  ],
                  'formatStreams': [
                    {
                      'qualityLabel': '720p',
                      'container': 'mp4',
                      'url': '$base/media/proxy_video.mp4',
                    },
                  ],
                }),
                headers: {'content-type': 'application/json'},
              );
            }
            metadataCalls++;
            return shelf.Response.ok(
              jsonEncode({
                'title': 'Fast Direct Track',
                'author': 'Tester',
                'lengthSeconds': 120,
                'adaptiveFormats': [
                  {
                    'type': 'audio/mp4; codecs="mp4a.40.2"',
                    'bitrate': '128000',
                    'url': '$base/media/good_audio.m4a',
                  },
                  {
                    'type': 'video/mp4; codecs="avc1.4d401f"',
                    'qualityLabel': '720p',
                    'url': '$base/media/good_adap_video.mp4',
                  },
                ],
                'formatStreams': [
                  {
                    'qualityLabel': '1080p',
                    'container': 'mp4',
                    'url': '$base/media/slow_403_video.mp4',
                  },
                  {
                    'qualityLabel': '720p',
                    'container': 'mp4',
                    'url': '$base/media/slow_fail_video.mp4',
                  },
                ],
              }),
              headers: {'content-type': 'application/json'},
            );
          }

          if (req.url.path == 'media/good_audio.m4a' ||
              req.url.path == 'media/proxy_audio.m4a' ||
              req.url.path == 'media/proxy_video.mp4') {
            return shelf.Response.ok('AUDIOBYTES',
                headers: {'content-type': 'audio/mp4'});
          }

          if (req.url.path.startsWith('media/slow_')) {
            videoProbeCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 900));
            return shelf.Response(403, body: 'Forbidden');
          }

          if (req.url.path == 'media/good_adap_video.mp4') {
            videoProbeCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 250));
            return shelf.Response.ok('VIDEOBYTES',
                headers: {'content-type': 'video/mp4'});
          }

          return shelf.Response.notFound('Not found');
        },
        InternetAddress.loopbackIPv4,
        0,
      );

      try {
        StreamResolver.instance.setCustomInstance('127.0.0.1:${server.port}');

        // 1. Audio-only resolve skips video probes and skips ?local=true retry.
        final audioOnly = await StreamResolver.instance.resolveTrack(
          'fast_track',
          includeVideo: false,
        );
        expect(audioOnly, isNotNull);
        expect(audioOnly!.track.streamUrl, contains('/media/good_audio.m4a'));
        expect(audioOnly.track.videoStreamUrl, isNull);
        expect(metadataCalls, 1);
        expect(proxyMetadataCalls, 0);
        expect(videoProbeCalls, 0);

        // 2. Repeated audio-only call hits bundle cache with zero HTTP calls.
        final audioCached = await StreamResolver.instance.resolveTrack(
          'fast_track',
          includeVideo: false,
        );
        expect(audioCached, isNotNull);
        expect(metadataCalls, 1);
        expect(videoProbeCalls, 0);

        // 3. Switching to Video reuses raw JSON metadata (still 1 metadata GET!)
        //    and parallel-probes muxed + adaptive candidates cleanly under 1.8s.
        final sw = Stopwatch()..start();
        final withVideo = await StreamResolver.instance.resolveTrack(
          'fast_track',
          includeVideo: true,
        );
        sw.stop();
        expect(withVideo, isNotNull);
        expect(withVideo!.track.videoStreamUrl,
            contains('/media/good_adap_video.mp4'));
        expect(withVideo.track.videoHasAudio, isFalse);
        expect(metadataCalls, 1);
        expect(videoProbeCalls, greaterThanOrEqualTo(2));
        expect(sw.elapsedMilliseconds, lessThan(2200));

        // 4. Subsequent Video OR Audio resolve hits bundle cache with 0 new probes.
        final prevVideoProbes = videoProbeCalls;
        final cachedVideo = await StreamResolver.instance.resolveTrack(
          'fast_track',
          includeVideo: true,
        );
        expect(cachedVideo!.track.videoStreamUrl,
            contains('/media/good_adap_video.mp4'));
        expect(videoProbeCalls, prevVideoProbes);

        // 5. forceProxy: true bypasses cache and queries ?local=true.
        final forced = await StreamResolver.instance.resolveTrack(
          'fast_track',
          forceProxy: true,
          includeVideo: true,
        );
        expect(forced, isNotNull);
        expect(proxyMetadataCalls, 1);
        expect(forced!.track.streamUrl, contains('/media/proxy_audio.m4a'));
        expect(forced.track.videoStreamUrl, contains('/media/proxy_video.mp4'));
      } finally {
        await server.close(force: true);
      }
    });

    test('Nowplaying temp playlist queues added tracks in chronological FIFO order',
        () async {
      const tA = MediaTrack(
        id: 'fifo_a',
        title: 'Search Song A',
        artist: 'Artist A',
        thumbnailUrl: '',
        durationSeconds: 180,
        source: TrackSource.local,
        localPath: '/tmp/fifo_a.mp3',
      );
      const tRel = MediaTrack(
        id: 'fifo_rel',
        title: 'Related Filler',
        artist: 'Auto',
        thumbnailUrl: '',
        durationSeconds: 180,
        source: TrackSource.local,
        localPath: '/tmp/fifo_rel.mp3',
      );
      const tB = MediaTrack(
        id: 'fifo_b',
        title: 'Added Song B',
        artist: 'Artist B',
        thumbnailUrl: '',
        durationSeconds: 200,
        source: TrackSource.local,
        localPath: '/tmp/fifo_b.mp3',
      );
      const tC = MediaTrack(
        id: 'fifo_c',
        title: 'Added Song C',
        artist: 'Artist C',
        thumbnailUrl: '',
        durationSeconds: 210,
        source: TrackSource.local,
        localPath: '/tmp/fifo_c.mp3',
      );
      const tD = MediaTrack(
        id: 'fifo_d',
        title: 'Added Song D',
        artist: 'Artist D',
        thumbnailUrl: '',
        durationSeconds: 220,
        source: TrackSource.local,
        localPath: '/tmp/fifo_d.mp3',
      );

      final engine = SonicAudioEngine.instance;
      if (!engine.snapshot.isShuffle) {
        await engine.toggleShuffle();
      }
      await engine.playTrack(tA, queue: [tA, tRel]);

      final resB = await engine.addToNowPlayingPlaylist(tB);
      expect(resB.added, isTrue);
      expect(resB.startedNow, isFalse);
      expect(resB.totalCount, 2);

      final resC = await engine.addToNowPlayingPlaylist(tC);
      expect(resC.added, isTrue);
      expect(resC.totalCount, 3);

      // Duplicate add is rejected cleanly without altering FIFO order
      final resDup = await engine.addToNowPlayingPlaylist(tB);
      expect(resDup.added, isFalse);
      expect(resDup.totalCount, 3);

      expect(engine.snapshot.isTempPlaylist, isTrue);
      expect(engine.snapshot.activePlaylistName,
          SonicAudioEngine.kTempNowPlayingPlaylistName);
      expect(engine.snapshot.isShuffle, isFalse);
      expect(engine.snapshot.queue.map((t) => t.id).toList(),
          ['fifo_a', 'fifo_b', 'fifo_c']);

      // Plays B first after A, then D added later plays after C
      await engine.skipToNext();
      expect(engine.snapshot.currentTrack?.id, 'fifo_b');

      await engine.addToNowPlayingPlaylist(tD);
      expect(engine.snapshot.queue.map((t) => t.id).toList(),
          ['fifo_a', 'fifo_b', 'fifo_c', 'fifo_d']);

      await engine.skipToNext();
      expect(engine.snapshot.currentTrack?.id, 'fifo_c');

      await engine.skipToNext();
      expect(engine.snapshot.currentTrack?.id, 'fifo_d');
    });
  });

  group('Followed Channels & Offline Downloads Service Tests', () {
    test('follows, verifies, and unfollows channels in DatabaseService', () async {
      final db = DatabaseService.instance;
      final testChannel = FollowedChannel(
        channelId: 'UC_test_retro_lab_123',
        channelName: 'RetroLab',
        avatarUrl: 'https://example.com/retrolab.jpg',
        trackCount: 42,
        followedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      // Initially not followed
      expect(await db.isChannelFollowed(testChannel.channelId), isFalse);
      expect(await db.isChannelFollowed('', channelName: 'RetroLab'), isFalse);

      // Follow
      await db.followChannel(FollowedChannel(
        channelId: testChannel.channelId,
        channelName: testChannel.channelName,
        avatarUrl: testChannel.avatarUrl,
        trackCount: testChannel.trackCount,
        followedAt: DateTime.now(),
      ));

      expect(await db.isChannelFollowed(testChannel.channelId), isTrue);
      expect(await db.isChannelFollowed('', channelName: 'retrolab'), isTrue);

      final channels = await db.getFollowedChannels();
      expect(channels.any((c) => c.channelId == testChannel.channelId), isTrue);
      expect(channels.firstWhere((c) => c.channelId == testChannel.channelId).channelName, 'RetroLab');

      // Unfollow
      await db.unfollowChannel(testChannel.channelId);
      expect(await db.isChannelFollowed(testChannel.channelId), isFalse);
    });

    test('StreamResolver fetchChannelDetails returns details in test offline mode', () async {
      final resolver = StreamResolver.instance;
      StreamResolver.testOfflineMode = true;

      final details = await resolver.fetchChannelDetails(
        'UC_offline_channel_999',
        channelName: 'Chill Acoustic Band',
      );

      expect(details, isNotNull);
      expect(details!.channelId, 'UC_offline_channel_999');
      expect(details.channelName, 'Chill Acoustic Band');
    });

    test('saves, reads, and deletes offline cached tracks in DatabaseService', () async {
      final db = DatabaseService.instance;
      const track = MediaTrack(
        id: 'track_offline_test_1',
        title: '50 Năm Về Sau',
        artist: 'Tuyển Chế',
        thumbnailUrl: '',
        durationSeconds: 240,
        source: TrackSource.customStream,
      );

      final dummyFile = File('${testDir.path}/track_offline_test_1.m4a');
      await dummyFile.writeAsString('dummy audio data');

      await db.saveOfflineTrack(track, dummyFile.path);

      final cached = await db.getOfflineTrackById(track.id);
      expect(cached, isNotNull);
      expect(cached!.id, track.id);
      expect(cached.title, '50 Năm Về Sau');
      expect(cached.localPath, dummyFile.path);

      final allOffline = await db.getOfflineTracks();
      expect(allOffline.any((t) => t.id == track.id), isTrue);

      // Delete removes record and file
      await db.deleteOfflineTrack(track.id);
      final afterDelete = await db.getOfflineTrackById(track.id);
      expect(afterDelete, isNull);
      expect(await dummyFile.exists(), isFalse);
    });
  });
}
