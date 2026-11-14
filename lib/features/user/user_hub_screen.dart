import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/theme/sonic_tokens.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';

/// Unified Personal Hub for mobile portrait mode:
/// Combines Driver Profile, Library (Playlists, Liked, Offline, USB, Wi-Fi, Drive),
/// and Settings (Cabin Bass/EQ, Sleep Timer, Server, Safety).
class UserHubScreen extends ConsumerWidget {
  const UserHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subTab = ref.watch(userHubSubTabProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Driver Profile Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceCard,
                  borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
                  border: Border.all(
                    color: SonicTokens.glassBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: SonicTokens.primaryContainer,
                      child: Text(
                        'SL',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Driver Cockpit',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Soniclane Cockpit • Free Edition (All Unlocked)',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: SonicTokens.secondaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Library | Settings Sub-tab Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SonicTokens.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SonicTokens.glassBorder),
                ),
                child: Row(
                  children: [
                    _HubTabChip(
                      icon: Icons.library_music_rounded,
                      label: 'Library',
                      active: subTab == 0,
                      onTap: () =>
                          ref.read(userHubSubTabProvider.notifier).state = 0,
                    ),
                    _HubTabChip(
                      icon: Icons.tune_rounded,
                      label: 'Settings',
                      active: subTab == 1,
                      onTap: () =>
                          ref.read(userHubSubTabProvider.notifier).state = 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: subTab == 0
              ? const LibraryScreen()
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SettingsScreen(embedded: true),
                ),
        ),
      ],
    );
  }
}

class _HubTabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HubTabChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: active ? SonicTokens.secondaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : SonicTokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: active ? Colors.white : SonicTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
