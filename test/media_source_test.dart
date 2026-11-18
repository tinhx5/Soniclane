import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniclane/core/models/media_models.dart';
import 'package:soniclane/core/services/media_source_service.dart';
import 'package:soniclane/features/overlays/add_source_modal.dart';

void main() {
  group('MediaSourceService Tests', () {
    test('normalizeUrl handles schemes and trailing slashes', () {
      final s = MediaSourceService.instance;
      expect(s.normalizeUrl('192.168.1.10:8080/'), 'http://192.168.1.10:8080');
      expect(s.normalizeUrl('https://my-server.com:8096/'), 'https://my-server.com:8096');
      expect(s.normalizeUrl('  http://example.com/  '), 'http://example.com');
      expect(s.normalizeUrl(''), '');
    });

    test('parseM3uContent correctly parses IPTV and Radio M3U lines', () {
      const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="vtv1" tvg-name="VTV1 HD" tvg-logo="https://example.com/vtv1.png" group-title="News",VTV1 Vietnam
https://stream.example.com/live/vtv1/index.m3u8
#EXTINF:240 tvg-id="chill1" tvg-logo="https://example.com/cover.jpg" group-title="Chillout",Late Night Lo-Fi
https://stream.example.com/audio/track1.mp3
''';

      final tracks = MediaSourceService.instance.parseM3uContent(sampleM3u);
      expect(tracks.length, 2);

      // Track 1: IPTV
      expect(tracks[0].title, 'VTV1 Vietnam');
      expect(tracks[0].artist, 'News');
      expect(tracks[0].thumbnailUrl, 'https://example.com/vtv1.png');
      expect(tracks[0].streamUrl, 'https://stream.example.com/live/vtv1/index.m3u8');
      expect(tracks[0].videoStreamUrl, 'https://stream.example.com/live/vtv1/index.m3u8');
      expect(tracks[0].source, TrackSource.m3u);

      // Track 2: Audio
      expect(tracks[1].title, 'Late Night Lo-Fi');
      expect(tracks[1].artist, 'Chillout');
      expect(tracks[1].durationSeconds, 240);
      expect(tracks[1].streamUrl, 'https://stream.example.com/audio/track1.mp3');
      expect(tracks[1].source, TrackSource.m3u);
    });

    test('MediaSourceConfig serializes and deserializes cleanly', () {
      final config = MediaSourceConfig(
        id: 'test_src_1',
        type: MediaSourceType.xtream,
        name: 'My Xtream TV',
        serverUrl: 'http://example.com:8080',
        username: 'user1',
        password: 'pass1',
        itemCount: 42,
        createdAt: DateTime.now(),
      );

      final json = config.toJson();
      final revived = MediaSourceConfig.fromJson(json);

      expect(revived.id, 'test_src_1');
      expect(revived.type, MediaSourceType.xtream);
      expect(revived.name, 'My Xtream TV');
      expect(revived.serverUrl, 'http://example.com:8080');
      expect(revived.username, 'user1');
      expect(revived.itemCount, 42);
    });

    test('TrackSource enum supports m3u, jellyfin, emby, xtream, plex', () {
      expect(TrackSource.fromString('m3u'), TrackSource.m3u);
      expect(TrackSource.fromString('jellyfin'), TrackSource.jellyfin);
      expect(TrackSource.fromString('emby'), TrackSource.emby);
      expect(TrackSource.fromString('xtream'), TrackSource.xtream);
      expect(TrackSource.fromString('plex'), TrackSource.plex);

      expect(TrackSource.m3u.shortTag, 'M3U');
      expect(TrackSource.jellyfin.shortTag, 'JELLYFIN');
      expect(TrackSource.emby.shortTag, 'EMBY');
      expect(TrackSource.xtream.shortTag, 'XTREAM');
      expect(TrackSource.plex.shortTag, 'PLEX');
    });
  });

  group('AddSourceModal UI Tests', () {
    testWidgets('renders Add a Source modal with 5 sources', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddSourceModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a Source'), findsOneWidget);
      expect(find.text('M3U'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
      expect(find.text('Emby'), findsOneWidget);
      expect(find.text('Xtream'), findsOneWidget);
      expect(find.text('Plex'), findsOneWidget);
      expect(find.text('Get Help'), findsOneWidget);
    });

    testWidgets('navigates to M3U connect view and back', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddSourceModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('M3U'));
      await tester.pumpAndSettle();

      expect(find.text('Paste a link or a whole config'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('What is a source?'), findsOneWidget);

      // Back
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Add a Source'), findsOneWidget);
    });

    testWidgets('navigates to Xtream connect view with required fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddSourceModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xtream'));
      await tester.pumpAndSettle();

      expect(find.text('Connect to Xtream'), findsOneWidget);
      expect(find.text('Server Address'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('http://example.com:8080'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });
  });
}
