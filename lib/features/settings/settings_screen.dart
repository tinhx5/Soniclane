import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/database_service.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/services/stream_resolver.dart';
import '../../core/theme/sonic_tokens.dart';
import '../browser/web_browser_screen.dart';
import '../overlays/equalizer_modal.dart';
import '../overlays/wifi_transfer_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _customUrlCtrl = TextEditingController();
  bool _testingLatency = false;

  @override
  void initState() {
    super.initState();
    _customUrlCtrl.text = ref.read(settingsProvider).customServerUrl;
  }

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _runPingTest() async {
    setState(() => _testingLatency = true);
    final measured =
        await ref.read(settingsProvider.notifier).syncWithDefaultServers();
    if (!mounted) return;
    setState(() => _testingLatency = false);
    final healthyCount = measured.where((e) => e.isHealthy).length;
    final isConnected = healthyCount > 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isConnected ? SonicTokens.surfaceCard : SonicTokens.warningAmber,
        content: Text(
          isConnected
              ? 'Connected'
              : 'Connection failed. Please check internet or server.',
          style: TextStyle(
            color: isConnected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAutoSelectFastest(bool enabled) async {
    setState(() => _testingLatency = true);
    await ref
        .read(settingsProvider.notifier)
        .syncWithDefaultServers(overrideAutoSelectFastest: enabled);
    if (mounted) setState(() => _testingLatency = false);
  }

  Future<void> _clearCustomServerUrl(AppSettings settings) async {
    _customUrlCtrl.clear();
    await ref.read(settingsProvider.notifier).update(
          settings.copyWith(
            customServerUrl: '',
            syncedDefaultServers: '',
          ),
        );
    await ref.read(homeFeedProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleared custom media server')),
    );
  }

  Future<void> _saveCustomServerUrl(AppSettings settings) async {
    final raw = _customUrlCtrl.text.trim();
    final normalized = raw.isEmpty
        ? ''
        : await StreamResolver.instance.expandServerConfigInput(raw);

    if (raw.isNotEmpty && normalized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SonicTokens.warningAmber,
            content: Text(
              'Invalid server URL, domain, or JSON config. Example: media.example.com or https://host/sources.json',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return;
    }

    _customUrlCtrl.text = normalized;
    if (mounted) setState(() => _testingLatency = true);
    final latest = await ref
        .read(settingsProvider.notifier)
        .syncWithDefaultServers(overrideUserUrl: normalized);

    if (!mounted) return;
    setState(() => _testingLatency = false);
    final first = latest.isNotEmpty ? latest.first : null;
    final msg = latest.isEmpty
        ? 'No valid custom server or default mirror reachable'
        : (first != null && !first.isHealthy && first.tier == 'HTML Website'
            ? '${first.name} is an HTML website, not a JSON Media API — open it in In-App Web Browser instead.'
            : 'Saved custom server (${latest.length} active endpoint${latest.length == 1 ? "" : "s"})');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final instances = ref.watch(serverInstancesProvider);
    final wifi = ref.watch(wifiServerProvider);
    final library = ref.watch(libraryProvider);
    final snapshot = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final eq = snapshot.eqSettings;
    final rem = snapshot.sleepTimerRemainingSec;

    final primaryInstance = instances.isNotEmpty ? instances.first : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 0 : 20,
        widget.embedded ? 4 : 20,
        widget.embedded ? 0 : 20,
        widget.embedded ? 120 : 130,
      ),
      children: [
        if (!widget.embedded) ...[
          Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cockpit Settings',
                style: Theme.of(context).textTheme.headlineMedium),
            InkWell(
              onTap: null,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: settings.isPro
                      ? SonicTokens.warningAmber.withOpacity(0.18)
                      : SonicTokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: settings.isPro
                        ? SonicTokens.warningAmber
                        : SonicTokens.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: settings.isPro
                          ? SonicTokens.warningAmber
                          : SonicTokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'All Features Free',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: settings.isPro
                            ? SonicTokens.warningAmber
                            : SonicTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ],

        // 1. Audio, Cabin Bass & Sleep Timer
        _SettingsSection(
          title: 'AUDIO, BASS & SLEEP TIMER',
          icon: Icons.graphic_eq_rounded,
          children: [
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded,
                  color: SonicTokens.secondaryContainer),
              title: const Text('Cabin Bass & 10-Band Equalizer'),
              subtitle: Text('Active Preset: ${eq.presetName}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => EqualizerDspModal.show(context),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_rounded,
                  color: SonicTokens.secondaryContainer),
              title: const Text('Cockpit Sleep Timer'),
              subtitle: Text(
                rem != null
                    ? 'Active: ${(rem / 60).ceil()}m remaining'
                    : 'Off • Auto-pause playback',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => SleepTimerSheet.show(context),
            ),
            ListTile(
              title: const Text('Mobile Audio Bitrate'),
              subtitle: const Text('128k AAC saves 90% 4G data on highways'),
              trailing: DropdownButton<String>(
                value: settings.audioBitrate,
                dropdownColor: SonicTokens.surfaceElevated,
                items: const [
                  DropdownMenuItem(value: '128k', child: Text('128kbps Saver')),
                  DropdownMenuItem(value: '256k', child: Text('256kbps High')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .update(settings.copyWith(audioBitrate: v));
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Parked Video Resolution'),
              trailing: DropdownButton<String>(
                value: settings.videoQuality,
                dropdownColor: SonicTokens.surfaceElevated,
                items: const [
                  DropdownMenuItem(value: '720p', child: Text('720p HD')),
                  DropdownMenuItem(value: '1080p', child: Text('1080p Full HD')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .update(settings.copyWith(videoQuality: v));
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. In-App Web Browser & User-Configured Media Source (BYO Source)
        _SettingsSection(
          title: 'IN-APP BROWSER & CUSTOM MEDIA SOURCE',
          icon: Icons.public_rounded,
          children: [
            ListTile(
              leading: const Icon(Icons.language_rounded,
                  color: SonicTokens.secondaryContainer),
              title: const Text('In-App Web Browser'),
              subtitle: const Text(
                  'Open regular websites directly inside Soniclane via WebView'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => WebBrowserScreen.open(context),
            ),
            ListTile(
              title: const Text(
                'Media Server Connection',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                () {
                  if (_testingLatency) {
                    return 'Connecting...';
                  }
                  if (primaryInstance == null) {
                    return 'Not Configured';
                  }
                  if (primaryInstance.isHealthy) {
                    return 'Connected';
                  }
                  return 'Connection failed (Server offline or unreachable)';
                }(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _testingLatency
                      ? SonicTokens.secondaryContainer
                      : (primaryInstance == null
                          ? SonicTokens.textSecondary
                          : (primaryInstance.isHealthy
                              ? SonicTokens.successGreen
                              : SonicTokens.warningAmber)),
                ),
              ),
              trailing: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _testingLatency ? null : _runPingTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SonicTokens.surfaceElevated,
                    foregroundColor: SonicTokens.secondaryContainer,
                  ),
                  icon: _testingLatency
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_testingLatency ? 'Connecting...' : 'Check Connection'),
                ),
              ),
            ),
            for (final htmlSite in () {
              final userEnteredUrls = StreamResolver.parseServerEntries(
                settings.customServerUrl,
              ).toSet();
              return instances
                  .where((e) =>
                      e.tier == 'HTML Website' &&
                      userEnteredUrls.contains(e.url))
                  .take(2);
            }())
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => WebBrowserScreen.open(
                      context,
                      initialUrl: htmlSite.url,
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: Text('Open ${htmlSite.name} in Web Browser'),
                  ),
                ),
              ),
            SwitchListTile(
              title: const Text('Auto-Select Fastest Server Mirror'),
              value: settings.autoSelectFastestServer,
              onChanged: _testingLatency ? null : _toggleAutoSelectFastest,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _customUrlCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText:
                      'Domain, URL, .json URL, or JSON list (auto https://)',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_customUrlCtrl.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear server URL',
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _clearCustomServerUrl(settings),
                        ),
                      IconButton(
                        tooltip: 'Save custom server',
                        icon: const Icon(Icons.save_rounded,
                            color: SonicTokens.secondaryContainer),
                        onPressed: () => _saveCustomServerUrl(settings),
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _saveCustomServerUrl(settings),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Driving Safety & Park Detection (Optional In-Car Controls)
        _SettingsSection(
          title: 'DRIVING SAFETY & PARK MODE (OPTIONAL)',
          icon: Icons.shield_rounded,
          children: [
            SwitchListTile(
              title: const Text('GPS Parked Detection (0 km/h > 15s)'),
              subtitle: const Text(
                  'Optional for in-dash mounts • Leave off on phone/passenger use'),
              value: settings.gpsParkDetection,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update(settings.copyWith(gpsParkDetection: v)),
            ),
            SwitchListTile(
              title: const Text('Driving Video Lockout (> 5 km/h)'),
              subtitle: const Text(
                  'When enabled, blocks Video Mode above 5 km/h while driving'),
              value: settings.drivingVideoLockout,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update(settings.copyWith(drivingVideoLockout: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Local Storage & Wireless Transfer
        _SettingsSection(
          title: 'STORAGE & WI-FI DROP TRANSFER',
          icon: Icons.usb_rounded,
          children: [
            ListTile(
              title: const Text('Hardware Storage & USB Scanner'),
              subtitle: Text(
                '${library.usbDevices.length} USB drives • ${library.localDeviceTracks.length} local tracks',
              ),
              trailing: ElevatedButton(
                onPressed: () => ref.read(libraryProvider.notifier).refresh(),
                child: const Text('Rescan'),
              ),
            ),
            ListTile(
              title: const Text('Wi-Fi Drag & Drop Server (Port 8080)'),
              subtitle: Text(
                wifi.isRunning ? wifi.serverUrl : 'Stopped',
                style: TextStyle(
                  color: wifi.isRunning
                      ? SonicTokens.successGreen
                      : SonicTokens.textSecondary,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: () => WifiTransferModal.show(context),
                child: Text(wifi.isRunning ? 'Manage QR' : 'Setup'),
              ),
            ),
            ListTile(
              title: const Text('Clear Playback History Cache'),
              trailing: TextButton(
                onPressed: () async {
                  await DatabaseService.instance.clearHistory();
                  await ref.read(homeFeedProvider.notifier).refresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Cleared playback history cache')),
                    );
                  }
                },
                child: const Text('Clear',
                    style: TextStyle(color: SonicTokens.errorRed)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Center(
          child: Text(
            'Soniclane Cockpit v2.0 • Cross-Platform (iOS • Android • Windows)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SonicTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
        border: Border.all(color: SonicTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: SonicTokens.secondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: SonicTokens.secondaryLight,
                          letterSpacing: 1.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
