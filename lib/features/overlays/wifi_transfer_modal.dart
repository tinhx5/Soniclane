import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';
import '../now_playing/now_playing_screen.dart';

class WifiTransferModal extends ConsumerWidget {
  const WifiTransferModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const WifiTransferModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wifi = ref.watch(wifiServerProvider);

    return Dialog(
      backgroundColor: SonicTokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonicTokens.radius2Xl),
        side: const BorderSide(color: SonicTokens.activeBorderCyan),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wi-Fi Drop Server',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        wifi.isRunning
                            ? 'Active on Port 8080'
                            : 'Tap Start to open LAN transfer',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: wifi.isRunning
                                  ? SonicTokens.successGreen
                                  : SonicTokens.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: wifi.isRunning,
                  onChanged: (_) =>
                      ref.read(wifiServerProvider.notifier).toggle(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (wifi.isRunning) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                  ),
                  child: QrImageView(
                    data: wifi.serverUrl,
                    version: QrVersions.auto,
                    size: 168,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: wifi.serverUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied LAN URL to clipboard')),
                  );
                },
                borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceBase,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                    border: Border.all(color: SonicTokens.activeBorderBlue),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        wifi.serverUrl,
                        style: const TextStyle(
                          color: SonicTokens.secondaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded,
                          size: 18, color: SonicTokens.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open this address in any laptop or phone browser on the same Wi-Fi to drag & drop audio (MP3, FLAC, WAV, M4A) or dashcam videos (.mp4, .ts, .mov).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (wifi.uploadedTracks.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Recently Received (${wifi.uploadedTracks.length})',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: wifi.uploadedTracks.length,
                    itemBuilder: (_, i) {
                      final t = wifi.uploadedTracks[i];
                      final isVideo =
                          t.videoStreamUrl != null && t.videoStreamUrl!.isNotEmpty;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : Icons.check_circle,
                          color: isVideo
                              ? SonicTokens.secondaryContainer
                              : SonicTokens.successGreen,
                          size: 18,
                        ),
                        title: Text(t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          t.qualityBadge,
                          style: const TextStyle(
                              fontSize: 11, color: SonicTokens.textSecondary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow_rounded,
                              color: SonicTokens.primaryRed),
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final isMobile = MediaQuery.sizeOf(context).width < 700;
                            nav.pop();
                            if (isMobile) {
                              NowPlayingScreen.open(nav.context);
                            }
                            await SonicAudioEngine.instance.playTrack(
                              t,
                              queue: wifi.uploadedTracks,
                              playlistName: 'Wi-Fi Drop',
                              keepVideoMode: isVideo ? true : null,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceBase,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.devices_rounded,
                        size: 48, color: SonicTokens.textTertiary),
                    const SizedBox(height: 10),
                    Text(
                      'Transfer lossless music or dashcam videos (.mp4/.ts/.mov) wirelessly without unplugging storage.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: SonicTokens.minTouchTarget,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            ref.read(wifiServerProvider.notifier).toggle(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SonicTokens.secondaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SonicTokens.radiusLg),
                          ),
                        ),
                        icon: const Icon(Icons.power_settings_new_rounded),
                        label: const Text('Start Wi-Fi Server (:8080)'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: SonicTokens.minTouchTarget,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
