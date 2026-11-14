import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniclane/core/models/media_models.dart';
import 'package:soniclane/core/services/database_service.dart';
import 'package:soniclane/core/services/sonic_audio_engine.dart';
import 'package:soniclane/core/services/storage_scanner.dart';
import 'package:soniclane/core/services/stream_resolver.dart';
import 'package:soniclane/core/theme/app_theme.dart';
import 'package:soniclane/core/utils/url_parser.dart';
import 'package:soniclane/features/browser/web_browser_screen.dart';
import 'package:soniclane/features/now_playing/now_playing_screen.dart';
import 'package:soniclane/features/overlays/playlist_modals.dart';
import 'package:soniclane/shared/widgets/cockpit_shell.dart';
import 'package:soniclane/shared/widgets/sonic_logo.dart';

void main() {
  group('UrlParser Tests', () {
    test('parses direct MP3 and MP4 media URLs', () {
      final audio =
          UrlParser.parse('https://cdn.example.com/audio/night_drive.mp3');
      expect(audio, isNotNull);
      expect(audio!.type, MediaUrlType.directMedia);
      expect(audio.isDirectVideo, isFalse);

      final video =
          UrlParser.parse('https://cdn.example.com/video/dash.mp4?token=1');
      expect(video, isNotNull);
      expect(video!.type, MediaUrlType.directMedia);
      expect(video.isDirectVideo, isTrue);
    });

    test('parses custom media server item watch URL', () {
      final res =
          UrlParser.parse('https://media.example.com/watch?v=item_abc123');
      expect(res, isNotNull);
      expect(res!.type, MediaUrlType.streamItem);
      expect(res.id, 'item_abc123');
    });

    test('parses custom media server playlist URL', () {
      final res = UrlParser.parse(
          'https://media.example.com/playlist?list=PLrAXtmErZgOeiKm4sg');
      expect(res, isNotNull);
      expect(res!.type, MediaUrlType.streamPlaylist);
      expect(res.id, 'PLrAXtmErZgOeiKm4sg');
    });

    test('returns null on plain search text', () {
      expect(UrlParser.parse('Midnight Synthwave Instrumental'), isNull);
    });
  });

  group('StorageScanner Dashcam Filter Tests', () {
    test('scans audio files and excludes DCIM / DVR dashcam folders', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('soniclane_usb_test_');
      try {
        final musicSub = Directory(p.join(tempDir.path, 'HiRes'));
        final dcimDir = Directory(p.join(tempDir.path, 'DCIM'));
        final dvrDir = Directory(p.join(tempDir.path, 'DVR'));
        await musicSub.create(recursive: true);
        await dcimDir.create(recursive: true);
        await dvrDir.create(recursive: true);

        await File(p.join(musicSub.path, 'Nightcall.flac')).writeAsBytes([1]);
        await File(p.join(tempDir.path, 'RoadTrip.mp3')).writeAsBytes([1]);
        await File(p.join(dcimDir.path, 'front_cam.mp4')).writeAsBytes([1]);
        await File(p.join(dvrDir.path, 'rear_cam.mp3')).writeAsBytes([1]);

        final found = await StorageScanner.instance
            .scanDirectory(tempDir, source: TrackSource.usb);

        final titles = found.map((e) => e.title).toSet();
        expect(titles, containsAll(['Nightcall', 'RoadTrip']));
        expect(titles, isNot(contains('front_cam')));
        expect(titles, isNot(contains('rear_cam')));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('Media Models Tests', () {
    test('HybridPlaylist computes online + usb counts and duration', () {
      final pl = HybridPlaylist(
        id: 'pl1',
        name: 'Cybermix',
        createdAt: DateTime(2026, 11, 10),
        items: const [
          MediaTrack(
            id: 'stream1',
            title: 'Online Stream Track',
            artist: 'Remote',
            thumbnailUrl: '',
            durationSeconds: 180,
            source: TrackSource.customStream,
          ),
          MediaTrack(
            id: 'usb1',
            title: 'USB FLAC Track',
            artist: 'USB',
            thumbnailUrl: '',
            durationSeconds: 300,
            source: TrackSource.usb,
          ),
        ],
      );
      expect(pl.streamCount, 1);
      expect(pl.usbCount, 1);
      expect(pl.localCount, 0);
      expect(pl.totalDurationSeconds, 480);
      expect(pl.formattedTotalDuration, '8 min');
    });
  });

  group('Soniclane Cockpit UI Tests', () {
    late Directory testDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      StreamResolver.testOfflineMode = true;
      testDir = await Directory.systemTemp.createTemp('soniclane_widget_db_');
      DatabaseService.testDbDirectoryPath = testDir.path;
      StorageScanner.testDropDirectoryPath = testDir.path;
      await DatabaseService.instance.database;
      await DatabaseService.instance.recordPlayProgress(
        const MediaTrack(
          id: 'seed_resume_1',
          title: 'Local Drive Ambient Mix',
          artist: 'Soniclane',
          thumbnailUrl: '',
          durationSeconds: 320,
          source: TrackSource.local,
          localPath: '/tmp/ambient.mp3',
        ),
        95000,
      );
      await DatabaseService.instance.addRecentSearch('Night Ambient Mix');
      await SonicAudioEngine.instance.initialize(testMode: true);
    });

    tearDownAll(() async {
      await DatabaseService.instance.close();
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    testWidgets(
        'renders mobile portrait, widescreen desktop, Search, Library, Settings, WebBrowser, and Now Playing without Video Safety Popup',
        (tester) async {
      await tester.runAsync(() async {
        // 1. Mobile Portrait 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: AppTheme.darkCockpitTheme(useGoogleFonts: false),
              home: const CockpitShell(),
            ),
          ),
        );
        for (int i = 0; i < 15; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.textContaining('Resumes at').evaluate().isNotEmpty) break;
        }

        // Bottom 3-tab nav removed on Mobile Portrait; Header has Logo (Home), Search, User
        expect(find.byTooltip('Search'), findsOneWidget);
        expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
        expect(find.byType(SonicLogo), findsOneWidget);
        expect(find.textContaining('Resumes at'), findsOneWidget);

        // Mobile NowPlaying: open from docked Mini-Player & verify clean layout without bottom queue/tags
        await tester.tap(find.text('Cockpit Stream Ready'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pump();
        expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
        expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
        expect(find.text('LIVE CABIN AUDIO'), findsNothing);
        expect(find.text('Up Next • Queue'), findsNothing);
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pump();

        // Navigate to Search via Header Search icon on Mobile
        await tester.tap(find.byTooltip('Search'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pump();
        expect(find.text('Recent In-Cabin Searches'), findsOneWidget);
        expect(find.text('Driving Mood Channels'), findsOneWidget);

        // Tap Logo to return Home, then dismiss one-time Resume card
        await tester.tap(find.byType(SonicLogo));
        await tester.pump();
        expect(find.textContaining('Resumes at'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pump();
        expect(find.textContaining('Resumes at'), findsNothing);

        // Navigate to User Hub (Library + Settings) via Header User icon
        await tester.tap(find.byIcon(Icons.person_outline_rounded));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.text('Playlists'), findsOneWidget);
        expect(find.text('Liked Songs'), findsOneWidget);

        // Verify Settings tab inside User Hub includes Cabin Bass EQ & Sleep Timer
        await tester.tap(find.text('Settings'));
        await tester.pump();
        expect(find.text('Cabin Bass & 10-Band Equalizer'), findsOneWidget);
        expect(find.text('Cockpit Sleep Timer'), findsOneWidget);
        await tester.tap(find.text('Library'));
        await tester.pump();

        // 2. Switch to Widescreen / Windows Desktop 1280x800
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        expect(find.text('Browse Hardware Files'), findsOneWidget);
        expect(find.text('Connect Drive Link / Folder'), findsOneWidget);
        expect(find.text('SONICLANE'), findsOneWidget);
        expect(find.text('SETTINGS'), findsOneWidget);
        expect(find.text('Full Player ↗'), findsOneWidget);

        // Navigate to Settings via Rail
        await tester.tap(find.text('SETTINGS'));
        await tester.pump();
        expect(find.text('Cockpit Settings'), findsOneWidget);
        expect(find.text('IN-APP BROWSER & CUSTOM MEDIA SOURCE'), findsOneWidget);
        expect(find.text('In-App Web Browser'), findsOneWidget);
        expect(find.text('Auto-Select Fastest Server Mirror'), findsOneWidget);

        // Verify Check Connection and Auto-Select Mirror are interactive even with empty input
        await tester.tap(find.text('Check Connection'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.tap(find.text('Auto-Select Fastest Server Mirror'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Open In-App Web Browser from Settings & close it
        await tester.tap(find.text('In-App Web Browser'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byType(WebBrowserScreen), findsOneWidget);
        await tester.tap(find.byTooltip('Close Browser'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Open Full Player & verify tapping VIDEO switches directly without safety warning modal
        await tester.tap(find.text('Full Player ↗'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pump();

        expect(find.text('Up Next • Queue'), findsOneWidget);
        await tester.tap(find.text('VIDEO'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.textContaining('CẢNH BÁO AN TOÀN'), findsNothing);
        expect(SonicAudioEngine.instance.snapshot.isVideoMode, isTrue);

        // Switch back to AUDIO and dispose widget tree cleanly
        await tester.tap(find.text('AUDIO'));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await Future.delayed(const Duration(milliseconds: 200));
      });

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets(
        'AddToPlaylistSheet prioritizes opened playlist OR Nowplaying temp playlist from search',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final pl1 = await DatabaseService.instance.createPlaylist('Playlist Alpha');
        final pl2 = await DatabaseService.instance.createPlaylist('Playlist Beta');

        const seedTrack = MediaTrack(
          id: 'seed_1',
          title: 'Seed Track',
          artist: 'Artist 1',
          thumbnailUrl: '',
          durationSeconds: 180,
          source: TrackSource.local,
          localPath: '/tmp/seed_1.mp3',
        );
        const searchResultTrack = MediaTrack(
          id: 'search_pick_1',
          title: 'Search Pick One',
          artist: 'Search Artist',
          thumbnailUrl: '',
          durationSeconds: 190,
          source: TrackSource.local,
          localPath: '/tmp/search_pick_1.mp3',
        );

        // Case 1: Active opened playlist ("Playlist Beta") must be prioritized first
        await SonicAudioEngine.instance.playTrack(
          seedTrack,
          queue: [seedTrack],
          playlistName: pl2.name,
          playlistId: pl2.id,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: AppTheme.darkCockpitTheme(useGoogleFonts: false),
              home: const Scaffold(
                body: AddToPlaylistSheet(track: searchResultTrack),
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('add_to_nowplaying_tile')), findsNothing);
        expect(find.text('Playlist Beta'), findsOneWidget);
        expect(find.text('Playlist Alpha'), findsOneWidget);
        final betaTop = tester.getTopLeft(find.text('Playlist Beta')).dy;
        final alphaTop = tester.getTopLeft(find.text('Playlist Alpha')).dy;
        expect(betaTop, lessThan(alphaTop));
        expect(find.textContaining('OPEN NOW'), findsOneWidget);

        // Case 2: Standalone track from search -> Nowplaying temp playlist is first
        await SonicAudioEngine.instance.playTrack(seedTrack);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: AppTheme.darkCockpitTheme(useGoogleFonts: false),
              home: const Scaffold(
                body: AddToPlaylistSheet(
                  track: searchResultTrack,
                  preferNowPlaying: true,
                ),
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        final nowFinder = find.byKey(const Key('add_to_nowplaying_tile'));
        expect(nowFinder, findsOneWidget);
        final nowTop = tester.getTopLeft(nowFinder).dy;
        final alphaTop2 = tester.getTopLeft(find.text('Playlist Alpha')).dy;
        expect(nowTop, lessThan(alphaTop2));

        await tester.tap(nowFinder);
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        expect(SonicAudioEngine.instance.snapshot.isTempPlaylist, isTrue);
        expect(
          SonicAudioEngine.instance.snapshot.queue.map((t) => t.id).toList(),
          ['seed_1', 'search_pick_1'],
        );

        // Clean up test playlists
        await DatabaseService.instance.deletePlaylist(pl1.id);
        await DatabaseService.instance.deletePlaylist(pl2.id);
        await tester.pumpWidget(const SizedBox.shrink());
        await Future.delayed(const Duration(milliseconds: 150));
      });
    });

    testWidgets(
        'NowPlaying shows playlist header line & track sheet only for playlists, hidden for single tracks',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        const track1 = MediaTrack(
          id: 'np_row_1',
          title: 'Solo Highway Song',
          artist: 'Artist 1',
          thumbnailUrl: '',
          durationSeconds: 180,
          source: TrackSource.local,
          localPath: '/tmp/np_row_1.mp3',
        );
        const track2 = MediaTrack(
          id: 'np_row_2',
          title: 'Second Playlist Song',
          artist: 'Artist 2',
          thumbnailUrl: '',
          durationSeconds: 200,
          source: TrackSource.local,
          localPath: '/tmp/np_row_2.mp3',
        );

        // 1. Single track: playlist line must NOT be shown
        await SonicAudioEngine.instance.playTrack(track1);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              themeMode: ThemeMode.dark,
              darkTheme: AppTheme.darkCockpitTheme(useGoogleFonts: false),
              home: const NowPlayingScreen(),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byKey(const Key('now_playing_active_playlist_row')),
            findsNothing);

        // 2. Active Playlist: line renders with playlist name & icon; tap opens track list
        final mix = await DatabaseService.instance.createPlaylist(
          'Roadtrip Mix',
          initialTracks: const [track1, track2],
        );
        await SonicAudioEngine.instance.playTrack(
          track1,
          queue: const [track1, track2],
          playlistName: mix.name,
          playlistId: mix.id,
        );
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        final rowFinder =
            find.byKey(const Key('now_playing_active_playlist_row'));
        expect(rowFinder, findsOneWidget);
        expect(find.text('Roadtrip Mix'), findsOneWidget);

        await tester.tap(rowFinder);
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('Second Playlist Song'), findsOneWidget);

        await DatabaseService.instance.deletePlaylist(mix.id);
        await tester.pumpWidget(const SizedBox.shrink());
        await Future.delayed(const Duration(milliseconds: 150));
      });

      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}
