import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/media_models.dart';
import 'storage_scanner.dart';

/// Embedded LAN HTTP server (port 8080) allowing users to drag-and-drop
/// MP3 / FLAC / WAV / M4A files from any laptop or phone browser over Wi-Fi.
class WifiTransferServer {
  WifiTransferServer._();
  static final WifiTransferServer instance = WifiTransferServer._();

  HttpServer? _server;
  String _serverUrl = 'http://127.0.0.1:8080';
  final _uploadedController = StreamController<MediaTrack>.broadcast();

  bool get isRunning => _server != null;
  String get serverUrl => _serverUrl;
  Stream<MediaTrack> get onTrackUploaded => _uploadedController.stream;

  Future<String> start({int port = 8080}) async {
    if (_server != null) return _serverUrl;

    final ip = await _resolveLanIp();
    final router = Router();

    router.get('/', (Request req) {
      return Response.ok(
        _uploadPageHtml,
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    });

    router.post('/upload', (Request req) async {
      final rawName = req.headers['x-filename'] ??
          'track_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final safeName = Uri.decodeComponent(rawName)
          .replaceAll(RegExp(r'[^a-zA-Z0-9._\-\s\u00C0-\u1EF9]'), '_');
      if (!StorageScanner.isSupportedMediaPath(safeName)) {
        return Response(
          415,
          body: '{"error":"unsupported_media_type","file":"$safeName"}',
          headers: {'Content-Type': 'application/json'},
        );
      }

      final targetDir = await StorageScanner.instance.getInternalDropDirectory();
      final outFile = File(p.join(targetDir.path, safeName));
      final sink = outFile.openWrite();
      try {
        await for (final chunk in req.read()) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final isVideo = StorageScanner.isVideoPath(outFile.path);
      final track = StorageScanner.buildLocalMediaTrack(
        outFile.path,
        source: TrackSource.local,
        idPrefix: 'wifi_',
        artistOverride:
            isVideo ? 'Wi-Fi Dashcam / Video' : 'Wi-Fi Drop Transfer',
      );
      _uploadedController.add(track);
      return Response.ok(
        '{"status":"ok","file":"$safeName","isVideo":$isVideo}',
        headers: {'Content-Type': 'application/json'},
      );
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _serverUrl = 'http://$ip:${_server!.port}';
    return _serverUrl;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> _resolveLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static const String _uploadPageHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Soniclane Cockpit • Wi-Fi Drop</title>
<style>
  body { background:#0D0F12; color:#fff; font-family:system-ui,sans-serif; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }
  .card { background:#1A1D24; border:1px solid #3B82F644; border-radius:18px; padding:32px; max-width:460px; width:90%; text-align:center; box-shadow:0 0 32px rgba(0,210,255,0.15); }
  h1 { margin:0 0 8px; font-size:24px; }
  .accent { color:#00D2FF; }
  p { color:#94A3B8; font-size:14px; }
  .drop { border:2px dashed #3B82F6; border-radius:14px; padding:40px 20px; margin:20px 0; cursor:pointer; background:#111317; transition:.2s; }
  .drop:hover { border-color:#00D2FF; background:#161920; }
  button { background:#FF0033; color:#fff; border:none; padding:14px 28px; border-radius:12px; font-weight:700; font-size:15px; cursor:pointer; }
  #log { text-align:left; font-size:13px; color:#10B981; margin-top:16px; max-height:160px; overflow:auto; }
</style>
</head>
<body>
  <div class="card">
    <h1>Sonic<span class="accent">lane</span> Wi-Fi Drop</h1>
    <p>Drag &amp; drop audio (MP3, FLAC, WAV, M4A) or dashcam video (.mp4, .ts, .mov) straight into your cockpit.</p>
    <div class="drop" onclick="document.getElementById('fileInput').click()">
      Click or Drag Audio / Video Files Here
    </div>
    <input id="fileInput" type="file" multiple accept=".mp3,.flac,.wav,.m4a,.aac,.ogg,.mp4,.ts,.mov,.mkv,.m4v" style="display:none" />
    <div id="log"></div>
  </div>
<script>
  const input = document.getElementById('fileInput');
  const log = document.getElementById('log');
  input.addEventListener('change', () => uploadFiles(input.files));
  document.body.addEventListener('dragover', e => e.preventDefault());
  document.body.addEventListener('drop', e => { e.preventDefault(); uploadFiles(e.dataTransfer.files); });
  function uploadOne(file) {
    return new Promise((resolve) => {
      const row = document.createElement('div');
      row.textContent = 'Uploading: ' + file.name + ' (0%)...';
      log.appendChild(row);
      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload', true);
      xhr.setRequestHeader('x-filename', encodeURIComponent(file.name));
      xhr.upload.onprogress = (ev) => {
        if (ev.lengthComputable && ev.total > 0) {
          const pct = Math.round((ev.loaded / ev.total) * 100);
          row.textContent = 'Uploading: ' + file.name + ' (' + pct + '%)...';
        }
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          row.textContent = '✓ Added to Soniclane: ' + file.name;
        } else {
          row.style.color = '#F87171';
          row.textContent = '✗ Unsupported or failed: ' + file.name + ' (' + xhr.status + ')';
        }
        resolve();
      };
      xhr.onerror = () => {
        row.style.color = '#F87171';
        row.textContent = '✗ Network error: ' + file.name;
        resolve();
      };
      xhr.send(file);
    });
  }
  async function uploadFiles(files) {
    for (const file of files) {
      await uploadOne(file);
    }
  }
</script>
</body>
</html>
''';
}
