import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerSearch([String? query]) {
    FocusScope.of(context).unfocus();
    _searchFocusNode.unfocus();
    final q = (query != null && query.trim().isNotEmpty)
        ? query.trim()
        : _searchCtrl.text.trim();
    if (widget.activeTab != 1) {
      ref.read(activeTabProvider.notifier).state = 1;
    }
    ref.read(searchProvider.notifier).executeSearch(q);
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
    ref.listen<int>(searchFocusTriggerProvider, (prev, next) {
      if (next > 0) {
        _searchFocusNode.requestFocus();
      }
    });

    final searchQuery = ref.watch(searchProvider).query;
    if (_searchCtrl.text.isEmpty && searchQuery.isNotEmpty) {
      _searchCtrl.text = searchQuery;
    }

    if (widget.isMobileMode) {
      // Mobile Portrait Header: Logo on left, Search input bar, Filter Icon, Profile on right
      return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: SonicLogo(size: 28, showWordmark: false),
              ),
            ),
            const SizedBox(width: 8),
            // Mobile Search Input
            Expanded(
              child: Tooltip(
                message: 'Search',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _triggerSearch(),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.search_rounded,
                            color: SonicTokens.secondaryContainer,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                 event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                              _triggerSearch();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocusNode,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Search songs, artists...',
                              hintStyle: TextStyle(
                                color: SonicTokens.textTertiary,
                                fontSize: 12.5,
                              ),
                            ),
                            onSubmitted: (val) => _triggerSearch(val),
                            onEditingComplete: () => _triggerSearch(),
                            onTap: () {
                              if (widget.activeTab != 1) {
                                ref.read(activeTabProvider.notifier).state = 1;
                              }
                            },
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded,
                              size: 15, color: SonicTokens.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            _triggerSearch('');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Filter icon placed right next to Search Input on portrait!
            const _HeaderFilterButton(),
            const SizedBox(width: 8),
            // User Profile
            InkWell(
              onTap: widget.onProfile,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
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
                    color: SonicTokens.primaryTint, size: 18),
              ),
            ),
          ],
        ),
      );
    }

    // Landscape / Widescreen Cockpit Header:
    // Left Search Input, Filter Icon next to it, Far Right Voice Search
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
          // Center Search Input (English placeholder)
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
                  InkWell(
                    onTap: () => _triggerSearch(),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.search_rounded,
                        color: SonicTokens.secondaryContainer,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                          _triggerSearch();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search songs, artists, playlists...',
                          hintStyle: TextStyle(
                            color: SonicTokens.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                        onSubmitted: (val) => _triggerSearch(val),
                        onEditingComplete: () => _triggerSearch(),
                        onTap: () {
                          if (widget.activeTab != 1) {
                            ref.read(activeTabProvider.notifier).state = 1;
                          }
                        },
                      ),
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
          const SizedBox(width: 8),
          // Filter Tag Icon placed right next to Search Input
          const _HeaderFilterButton(),
          const SizedBox(width: 8),
          // Far Right Voice Search Mic Button (English label)
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
                    'Voice Search',
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

/// Compact Filter Icon Button placed directly beside Search Input
class _HeaderFilterButton extends ConsumerWidget {
  const _HeaderFilterButton();

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final home = ref.read(homeFeedProvider);
    final activeFilter = home.selectedFilter;
    const filters = [
      {
        'name': 'All Blended',
        'desc': 'All music & smart streams',
        'icon': Icons.all_inclusive_rounded
      },
      {
        'name': '💾 In-Car USB',
        'desc': 'Local storage tracks only',
        'icon': Icons.usb_rounded
      },
      {
        'name': 'Night Drives',
        'desc': 'Chill highway ambient music',
        'icon': Icons.nightlight_round
      },
      {
        'name': 'High-BPM Focus',
        'desc': 'Energetic beats & driving tempo',
        'icon': Icons.bolt_rounded
      },
      {
        'name': 'Lo-Fi Road',
        'desc': 'Relaxing background road beats',
        'icon': Icons.headphones_rounded
      },
      {
        'name': 'Podcasts & Talk',
        'desc': 'Talk shows & spoken audio',
        'icon': Icons.podcasts_rounded
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: SonicTokens.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SonicTokens.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        color: SonicTokens.secondaryContainer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Feed & Recommendation Filters',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...filters.map((f) {
                  final name = f['name'] as String;
                  final desc = f['desc'] as String;
                  final icon = f['icon'] as IconData;
                  final isSelected = activeFilter == name;

                  return InkWell(
                    onTap: () {
                      ref.read(homeFeedProvider.notifier).selectFilter(name);
                      Navigator.pop(ctx);
                      final activeTab = ref.read(activeTabProvider);
                      if (activeTab != 0) {
                        ref.read(activeTabProvider.notifier).state = 0;
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SonicTokens.secondaryBlue.withOpacity(0.18)
                            : SonicTokens.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? SonicTokens.activeBorderCyan
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? SonicTokens.secondaryContainer
                                : SonicTokens.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : SonicTokens.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    color: SonicTokens.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: SonicTokens.secondaryContainer,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(homeFeedProvider).selectedFilter;
    final isFiltered = activeFilter != 'All Blended';

    return Tooltip(
      message: 'Feed Filter: $activeFilter',
      child: InkWell(
        onTap: () => _showFilterSheet(context, ref),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFiltered
                ? SonicTokens.secondaryBlue.withOpacity(0.24)
                : SonicTokens.surfaceHigh,
            border: Border.all(
              color: isFiltered
                  ? SonicTokens.activeBorderCyan
                  : SonicTokens.glassBorder,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: isFiltered
                    ? SonicTokens.secondaryContainer
                    : SonicTokens.textSecondary,
              ),
              if (isFiltered)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SonicTokens.secondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
