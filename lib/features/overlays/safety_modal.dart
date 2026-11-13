import 'package:flutter/material.dart';
import '../../core/theme/sonic_tokens.dart';

class SafetyDisclaimerModal extends StatelessWidget {
  const SafetyDisclaimerModal({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SafetyDisclaimerModal(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(SonicTokens.spaceLg),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(SonicTokens.radius2Xl),
          border: Border.all(
            color: SonicTokens.warningAmber.withOpacity(0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: SonicTokens.warningAmber.withOpacity(0.18),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: SonicTokens.warningAmber.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: SonicTokens.warningAmber,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'CẢNH BÁO AN TOÀN\nVIDEO MODE',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: SonicTokens.warningAmber,
                          height: 1.2,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Tính năng phát Video chỉ dành cho:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            const _BulletItem(text: 'Người ngồi ghế phụ hoặc hành khách.'),
            const SizedBox(height: 6),
            const _BulletItem(text: 'Khi xe đã dừng đỗ an toàn (về số P).'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SonicTokens.surfaceBase,
                borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                border: Border.all(color: SonicTokens.glassBorder),
              ),
              child: Text(
                'Tài xế tuyệt đối không xem video khi đang điều khiển phương tiện. Bạn hoàn toàn tự chịu trách nhiệm an toàn giao thông.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SonicTokens.textSecondary,
                      height: 1.4,
                    ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SonicTokens.onSurface,
                        side: const BorderSide(color: SonicTokens.surfaceHighest),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                        ),
                      ),
                      child: const Text('HỦY'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: SonicTokens.minTouchTarget,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SonicTokens.primaryRed,
                        foregroundColor: SonicTokens.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SonicTokens.radiusLg),
                        ),
                      ),
                      child: const Text(
                        'TÔI HIỂU & BẬT VIDEO',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 18, color: SonicTokens.secondaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
