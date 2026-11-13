import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/media_models.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/sonic_audio_engine.dart';
import '../../core/theme/sonic_tokens.dart';

class EqualizerDspModal extends ConsumerWidget {
  const EqualizerDspModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const EqualizerDspModal(),
    );
  }

  static const _bandLabels = [
    '31',
    '62',
    '125',
    '250',
    '500',
    '1k',
    '2k',
    '4k',
    '8k',
    '16k',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final eq = snapshot.eqSettings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Cabin Bass & 10-Band EQ',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EqSettings.presets.keys.map((preset) {
                final selected = eq.presetName == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: selected,
                  selectedColor: SonicTokens.secondaryBlue,
                  backgroundColor: SonicTokens.surfaceCard,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : SonicTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    SonicAudioEngine.instance.updateEqSettings(
                      eq.copyWith(
                        presetName: preset,
                        bands: List<double>.from(EqSettings.presets[preset]!),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_bandLabels.length, (i) {
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${eq.bands[i] >= 0 ? '+' : ''}${eq.bands[i].toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: SonicTokens.secondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: eq.bands[i],
                              min: -12,
                              max: 12,
                              onChanged: (val) {
                                final next = List<double>.from(eq.bands);
                                next[i] = val;
                                SonicAudioEngine.instance.updateEqSettings(
                                  eq.copyWith(
                                    presetName: 'Custom',
                                    bands: next,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _bandLabels[i],
                          style: const TextStyle(
                            fontSize: 11,
                            color: SonicTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Playback Tempo: ${eq.playbackSpeed.toStringAsFixed(2)}x',
                    style: Theme.of(context).textTheme.bodyMedium),
                Expanded(
                  child: Slider(
                    value: eq.playbackSpeed,
                    min: 0.75,
                    max: 2.0,
                    divisions: 5,
                    onChanged: (val) => SonicAudioEngine.instance
                        .updateEqSettings(eq.copyWith(playbackSpeed: val)),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Volume Normalization (ReplayGain)'),
              subtitle: const Text('Keep balanced loudness across tracks'),
              value: eq.volumeNormalization,
              onChanged: (v) => SonicAudioEngine.instance
                  .updateEqSettings(eq.copyWith(volumeNormalization: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackSnapshotProvider).valueOrNull ??
        SonicAudioEngine.instance.snapshot;
    final rem = snapshot.sleepTimerRemainingSec;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_rounded,
                    color: SonicTokens.secondaryContainer, size: 28),
                const SizedBox(width: 10),
                Text('Cockpit Sleep Timer',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (rem != null)
                  Text(
                    '${rem ~/ 60}:${(rem % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: SonicTokens.primaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final mins in [15, 30, 45, 60])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: SonicTokens.minTouchTarget,
                  child: OutlinedButton(
                    onPressed: () {
                      SonicAudioEngine.instance.setSleepTimerMinutes(mins);
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: SonicTokens.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    child: Text('$mins Minutes'),
                  ),
                ),
              ),
            if (rem != null)
              SizedBox(
                height: SonicTokens.minTouchTarget,
                child: ElevatedButton(
                  onPressed: () {
                    SonicAudioEngine.instance.setSleepTimerMinutes(null);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SonicTokens.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Turn Off Timer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
