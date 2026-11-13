import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/billing_service.dart';
import '../../core/theme/sonic_tokens.dart';

class DriverProfileProModal extends ConsumerWidget {
  const DriverProfileProModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const DriverProfileProModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return StreamBuilder<BillingState>(
      stream: BillingService.instance.stream,
      initialData: BillingService.instance.state,
      builder: (context, billingSnap) {
        final billing = billingSnap.data ?? BillingService.instance.state;
        final priceLabel = billing.proProduct?.price ?? '\$4.99 One-Time';

        return Dialog(
          backgroundColor: SonicTokens.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SonicTokens.radius2Xl),
            side: const BorderSide(color: SonicTokens.activeBorderBlue),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(SonicTokens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: SonicTokens.primaryContainer,
                      child: Text(
                        settings.isPro ? 'PRO' : 'SL',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Driver Cockpit Profile',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            settings.isPro
                                ? 'Soniclane Pro Active • Spatial DSP Unlocked'
                                : 'Free Edition • Local & Cloud Cockpit',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: settings.isPro
                                      ? SonicTokens.secondaryContainer
                                      : SonicTokens.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(SonicTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: SonicTokens.surfaceBase,
                    borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                    border: Border.all(
                      color: SonicTokens.secondaryContainer.withOpacity(0.35),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProFeatureRow(text: 'Remove all in-app banner ads'),
                      SizedBox(height: 8),
                      _ProFeatureRow(
                          text: '10-Band Cabin Equalizer & Spatial DSP'),
                      SizedBox(height: 8),
                      _ProFeatureRow(
                          text: 'Unlimited Hybrid Playlists (Online + USB FLAC)'),
                      SizedBox(height: 8),
                      _ProFeatureRow(
                          text: 'Wi-Fi Drag & Drop Server (Port 8080)'),
                    ],
                  ),
                ),
                if (billing.statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    billing.statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: SonicTokens.secondaryLight, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: SonicTokens.minTouchTarget,
                  child: ElevatedButton(
                    onPressed: billing.isPurchasing
                        ? null
                        : () async {
                            if (settings.isPro) {
                              Navigator.of(context).pop();
                              return;
                            }
                            final ok =
                                await BillingService.instance.purchasePro();
                            if (ok &&
                                !billing.storeAvailable &&
                                context.mounted) {
                              await ref.read(settingsProvider.notifier).update(
                                    settings.copyWith(isPro: true),
                                  );
                              if (context.mounted) Navigator.of(context).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settings.isPro
                          ? SonicTokens.surfaceHigh
                          : SonicTokens.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(SonicTokens.radiusLg),
                      ),
                    ),
                    child: Text(
                      settings.isPro
                          ? 'Soniclane Pro Activated ✓'
                          : (billing.isPurchasing
                              ? 'Connecting to Store...'
                              : 'Unlock Soniclane Pro ($priceLabel)'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (billing.storeAvailable && !settings.isPro) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => BillingService.instance.restorePurchases(),
                    child: const Text('Restore Purchases'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final String text;
  const _ProFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified_rounded,
            size: 18, color: SonicTokens.secondaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
