import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/cloud_drive_service.dart';
import '../../core/services/offline_download_service.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';

class CloudDriveModal extends ConsumerStatefulWidget {
  const CloudDriveModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CloudDriveModal(),
    );
  }

  @override
  ConsumerState<CloudDriveModal> createState() => _CloudDriveModalState();
}

class _CloudDriveModalState extends ConsumerState<CloudDriveModal> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  List<MediaTrack> _folderTracks = [];
  bool _loading = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _loadSavedDriveConfig();
  }

  Future<void> _loadSavedDriveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('gdrive_saved_url') ?? '';
    final savedKey = prefs.getString('gdrive_api_key') ?? '';
    if (mounted) {
      if (savedUrl.isNotEmpty) _urlCtrl.text = savedUrl;
      if (savedKey.isNotEmpty) _apiKeyCtrl.text = savedKey;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDriveInput({bool downloadOffline = false}) async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gdrive_saved_url', raw);
    if (_apiKeyCtrl.text.trim().isNotEmpty) {
      await prefs.setString('gdrive_api_key', _apiKeyCtrl.text.trim());
    }

    final folderId = CloudDriveService.instance.extractFolderId(raw);
    if (folderId != null) {
      if (_apiKeyCtrl.text.trim().isEmpty) {
        setState(() {
          _statusMsg =
              'To list a Google Drive folder automatically, enter your Drive API Key below.';
        });
        return;
      }
      setState(() {
        _loading = true;
        _statusMsg = null;
      });
      final tracks = await CloudDriveService.instance.listFolderTracks(
        folderUrlOrId: raw,
        apiKey: _apiKeyCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _folderTracks = tracks;
          _loading = false;
          if (tracks.isEmpty) {
            _statusMsg = 'No public audio files found in this Drive folder.';
          }
        });
      }
      return;
    }

    final track = CloudDriveService.instance.buildTrackFromShareUrl(
      shareUrl: raw,
      customTitle: _titleCtrl.text.trim().isEmpty
          ? 'Google Drive Audio'
          : _titleCtrl.text.trim(),
    );

    if (downloadOffline) {
      setState(() => _loading = true);
      final ok = await OfflineDownloadService.instance
          .downloadTrack(track, customDirectUrl: track.streamUrl);
      await ref.read(libraryProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMsg = ok
              ? 'Saved Drive audio to Offline Cache!'
              : 'Could not download file (ensure link sharing is "Anyone with link").';
        });
      }
    } else {
      await SonicAudioEngine.instance.playTrack(track);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SonicTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonicTokens.radius2Xl),
        side: const BorderSide(color: SonicTokens.activeBorderBlue),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_rounded,
                      color: SonicTokens.successGreen, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Google Drive Personal Cloud',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Paste a Google Drive audio file link (MP3/FLAC/M4A) to stream or download offline, or paste a folder link with your API Key.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://drive.google.com/file/d/...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final d = await Clipboard.getData(Clipboard.kTextPlain);
                      if (d?.text != null) _urlCtrl.text = d!.text!;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Track Name (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  hintText: 'Drive API Key (only needed for Folders)',
                ),
              ),
              if (_statusMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMsg!,
                  style: const TextStyle(
                      color: SonicTokens.secondaryLight, fontSize: 12),
                ),
              ],
              if (_folderTracks.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Folder Audio (${_folderTracks.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: _folderTracks.length,
                    itemBuilder: (_, i) {
                      final t = _folderTracks[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.audiotrack_rounded,
                            color: SonicTokens.successGreen),
                        title: Text(t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow_rounded,
                              color: SonicTokens.primaryRed),
                          onPressed: () {
                            SonicAudioEngine.instance.playTrack(
                              t,
                              queue: _folderTracks,
                              playlistName: 'Google Drive Folder',
                            );
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: SonicTokens.minTouchTarget,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _handleDriveInput(downloadOffline: true),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Save Offline'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: SonicTokens.minTouchTarget,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => _handleDriveInput(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SonicTokens.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SonicTokens.radiusLg),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_loading ? 'Loading...' : 'Stream'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
