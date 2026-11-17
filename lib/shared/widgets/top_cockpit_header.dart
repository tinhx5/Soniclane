import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/voice_search_service.dart';
import '../../core/theme/sonic_tokens.dart';
import 'sonic_logo.dart';

class TopCockpitHeader extends ConsumerStatefulWidget {
  final bool isParked;
  final bool showLogoWordmark;
  final bool isMobileMode;
  final int activeTab;
  final VoidCallback onHome;
  final VoidCallback onSearchTap;
  final VoidCallback onSettings;
  final VoidCallback onProfile;

  const TopCockpitHeader({
    super.key,
    required this.isParked,
    required this.showLogoWordmark,
    required this.isMobileMode,
    required this.activeTab,
    required this.onHome,
    required this.onSearchTap,
    required this.onSettings,
    required this.onProfile,
  });

  @override
  ConsumerState<TopCockpitHeader> createState() => TopCockpitHeaderState();
}

class TopCockpitHeaderState extends ConsumerState<TopCockpitHeader> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    if (widget.activeTab != 1) {
      ref.read(activeTabProvider.notifier).state = 1;
    }
    ref.read(searchProvider.notifier).executeSearch(query);
  }

  Future<void> _triggerVoiceSearch() async {
    ref.read(activeTabProvider.notifier).state = 1;
    final isVoiceOpen = ref.read(searchProvider).isVoiceHudOpen;
    final next = !isVoiceOpen;
    ref.read(searchProvider.notifier).setVoiceHud(next);
    if (next) {
      await VoiceSearchService.instance.startListening(
        onFinalResult: (spoken) {
          ref.read(searchProvider.notifier).setVoiceHud(false);
          _searchCtrl.text = spoken;
          ref.read(searchProvider.notifier).executeSearch(spoken);
        },
      );
    } else {
      await VoiceSearchService.instance.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobileMode) {
      // Mobile Portrait Header: Logo on left, Search and Profile on right
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: SonicTokens.surfaceLowest.withOpacity(0.92),
          border: const Border(
            bottom: BorderSide(color: SonicTokens.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: widget.onHome,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: SonicLogo(size: 32, showWordmark: true),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Search',
              onPressed: widget.onSearchTap,
              icon: Icon(
                Icons.search_rounded,
                size: 26,
                color: widget.activeTab == 1
                    ? SonicTokens.secondaryContainer
                    : SonicTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.activeTab == 2 || widget.activeTab == 5
                      ? SonicTokens.secondaryBlue.withOpacity(0.28)
                      : SonicTokens.surfaceElevated,
                  border: Border.all(
                    color: widget.activeTab == 2 || widget.activeTab == 5
                        ? SonicTokens.secondaryContainer
                        : SonicTokens.glassBorder,
                  ),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: SonicTokens.primaryTint, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    // Landscape / Widescreen Cockpit Header:
    // No logo/name (in left rail), no status pills, center Search input bar, right Voice search mic button
    final searchQuery = ref.watch(searchProvider).query;
    if (_searchCtrl.text.isEmpty && searchQuery.isNotEmpty) {
      _searchCtrl.text = searchQuery;
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceLowest.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: SonicTokens.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Center Search Input
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: SonicTokens.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.activeTab == 1
                      ? SonicTokens.activeBorderCyan
                      : SonicTokens.glassBorder,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: SonicTokens.secondaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Tìm kiếm bài hát, ca sĩ, danh sách phát...',
                        hintStyle: TextStyle(
                          color: SonicTokens.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _triggerSearch,
                      onTap: () {
                        if (widget.activeTab != 1) {
                          ref.read(activeTabProvider.notifier).state = 1;
                        }
                      },
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: SonicTokens.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        _triggerSearch('');
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Far Right Voice Search Mic Button
          InkWell(
            onTap: _triggerVoiceSearch,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: SonicTokens.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
                boxShadow: SonicTokens.cyanGlow(opacity: 0.35),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: SonicTokens.surfaceBase,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tìm giọng nói',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SonicTokens.surfaceBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
