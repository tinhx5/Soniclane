import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:soniclane/core/models/media_models.dart';
import 'package:soniclane/core/services/database_service.dart';
import 'package:soniclane/core/services/offline_download_service.dart';
import 'package:soniclane/core/services/storage_scanner.dart';
import 'package:soniclane/core/services/wifi_transfer_server.dart';

void main() {
  late Directory testDir;

  setUpAll(() async {
    testDir = await Directory.systemTemp.createTemp('soniclane_wifi_test_');
    DatabaseService.testDbDirectoryPath = testDir.path;
    StorageScanner.testDropDirectoryPath = testDir.path;
    await DatabaseService.instance.database;
  });

  tearDownAll(() async {
    await WifiTransferServer.instance.stop();
    await DatabaseService.instance.close();
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('WifiTransferServer Tests', () {
    test('serves web uploader and receives uploaded audio file', () async {
      final url = await WifiTransferServer.instance.start(port: 0);
      expect(WifiTransferServer.instance.isRunning, isTrue);

      // Connect via loopback using the bound port
      final parsed = Uri.parse(url);
      final localUri = Uri(scheme: 'http', host: '127.0.0.1', port: parsed.port);

      final client = HttpClient();
      try {
        final getReq = await client.getUrl(localUri.replace(path: '/'));
        final getRes = await getReq.close();
        final htmlBody = await utf8.decodeStream(getRes);
        expect(getRes.statusCode, 200);
        expect(htmlBody, contains('Sonic'));

        final uploadedFuture = WifiTransferServer.instance.onTrackUploaded.first;
        final postReq = await client.postUrl(localUri.replace(path: '/upload'));
        postReq.headers
            .set('x-filename', Uri.encodeComponent('TestDriveTrack.mp3'));
        postReq.add(utf8.encode('mock-mp3-bytes'));
        final postRes = await postReq.close();
        await postRes.drain<void>();
        expect(postRes.statusCode, 200);

        final track = await uploadedFuture;
        expect(track.title, 'TestDriveTrack');
        expect(
          File(p.join(testDir.path, 'TestDriveTrack.mp3')).existsSync(),
          isTrue,
        );
      } finally {
        client.close();
      }

      await WifiTransferServer.instance.stop();
      expect(WifiTransferServer.instance.isRunning, isFalse);
    });

    test('receives .mp4/.ts/.mov dashcam videos, rejects non-media, and rescans drop folder',
        () async {
      final url = await WifiTransferServer.instance.start(port: 0);
      final parsed = Uri.parse(url);
      final localUri = Uri(scheme: 'http', host: '127.0.0.1', port: parsed.port);

      final client = HttpClient();
      try {
        // Upload .mp4, .ts, .mov dashcam clips cleanly
        for (final ext in ['mp4', 'ts', 'mov']) {
          final uploadedFuture = WifiTransferServer.instance.onTrackUploaded.first;
          final postReq = await client.postUrl(localUri.replace(path: '/upload'));
          postReq.headers.set('x-filename', 'CAM_001.$ext');
          postReq.add(utf8.encode('mock-$ext-video-bytes'));
          final postRes = await postReq.close();
          await postRes.drain<void>();
          expect(postRes.statusCode, 200);

          final track = await uploadedFuture;
          expect(track.videoStreamUrl, startsWith('file://'));
          expect(track.videoStreamUrl, endsWith('CAM_001.$ext'));
          expect(track.videoHasAudio, isTrue);
          expect(track.qualityBadge, '${ext.toUpperCase()} Video');
        }

        // Reject unsupported file extensions cleanly (415)
        final badReq = await client.postUrl(localUri.replace(path: '/upload'));
        badReq.headers.set('x-filename', 'readme.txt');
        badReq.add(utf8.encode('hello'));
        final badRes = await badReq.close();
        await badRes.drain<void>();
        expect(badRes.statusCode, 415);

        // Verify drop folder rescan keeps uploaded dashcam videos
        final localScanned =
            await StorageScanner.instance.scanInternalDeviceMusic();
        final scannedTitles = localScanned.map((t) => t.qualityBadge).toSet();
        expect(scannedTitles, containsAll(['MP4 Video', 'TS Video', 'MOV Video']));

        // Verify explicit dashcam folder scan reads DCIM/DVR videos while default ignores
        final camCard = Directory(p.join(testDir.path, 'sd_card_test'));
        final dcim = Directory(p.join(camCard.path, 'DCIM'));
        await dcim.create(recursive: true);
        await File(p.join(dcim.path, 'FRONT_2026.ts')).writeAsBytes([1, 2, 3]);

        final filtered =
            await StorageScanner.instance.scanDirectory(camCard);
        expect(filtered, isEmpty);

        final explicit = await StorageScanner.instance.scanDirectory(
          camCard,
          includeVideos: true,
          includeDashcamFolders: true,
        );
        expect(explicit.length, 1);
        expect(explicit.first.videoStreamUrl, endsWith('FRONT_2026.ts'));
      } finally {
        client.close();
        await WifiTransferServer.instance.stop();
      }
    });
  });

  group('OfflineDownloadService Tests', () {
    test('downloads personal Drive audio locally and caches in SQLite',
        () async {
      // Spin up local mock media stream endpoint
      final server = await shelf_io.serve(
        (shelf.Request req) => shelf.Response.ok(
          utf8.encode('fake-m4a-audio-stream-bytes'),
          headers: {'content-type': 'audio/mp4'},
        ),
        InternetAddress.loopbackIPv4,
        0,
      );

      try {
        const track = MediaTrack(
          id: 'dl_track_1',
          title: 'Personal Drive Audio',
          artist: 'Soniclane',
          thumbnailUrl: '',
          durationSeconds: 180,
          source: TrackSource.googleDrive,
        );

        final ok = await OfflineDownloadService.instance.downloadTrack(
          track,
          customDirectUrl: 'http://127.0.0.1:${server.port}/audio.m4a',
        );
        expect(ok, isTrue);

        final cached =
            await DatabaseService.instance.getOfflineTrackById('dl_track_1');
        expect(cached, isNotNull);
        expect(File(cached!.localPath!).existsSync(), isTrue);

        // Remote customStream tracks save metadata only and are never downloaded offline
        const remoteStream = MediaTrack(
          id: 'remote_only_1',
          title: 'Remote Metadata Track',
          artist: 'Stream Host',
          thumbnailUrl: '',
          durationSeconds: 200,
          source: TrackSource.customStream,
          streamUrl: 'https://example.com/audio.mp3',
        );
        final remoteOk =
            await OfflineDownloadService.instance.downloadTrack(remoteStream);
        expect(remoteOk, isFalse);

        await DatabaseService.instance.deleteOfflineTrack('dl_track_1');
        expect(
            await DatabaseService.instance.getOfflineTrackById('dl_track_1'),
            isNull);
      } finally {
        await server.close(force: true);
      }
    });
  });
}
