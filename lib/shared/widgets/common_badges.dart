import 'package:flutter/material.dart';
import '../../core/models/media_models.dart';
import '../../core/theme/sonic_tokens.dart';

class TrackArtwork extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;

  const TrackArtwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = SonicTokens.radiusMd,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: SonicTokens.surfaceHighest,
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackArt(icon: fallbackIcon),
              )
            : _FallbackArt(icon: fallbackIcon),
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  final IconData icon;
  const _FallbackArt({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SonicTokens.surfaceElevated, SonicTokens.surfaceLowest],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: SonicTokens.secondaryContainer.withOpacity(0.85),
          size: 28,
        ),
      ),
    );
  }
}

class SourceBadgeChip extends StatelessWidget {
  final TrackSource source;
  final String? customLabel;

  const SourceBadgeChip({
    super.key,
    required this.source,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SonicTokens.surfaceHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: source.accentColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Text(
        customLabel ?? source.badgeLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: source.accentColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class RecommendationTagBadge extends StatelessWidget {
  final String tag;

  const RecommendationTagBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    if (tag.contains('Followed') ||
        tag.contains('theo dõi') ||
        tag.startsWith('⭐')) {
      return const SizedBox.shrink();
    }
    final isTrending = tag.toUpperCase().contains('TRENDING');
    final isUsb = tag.toUpperCase().contains('USB');
    final bg = isTrending
        ? SonicTokens.primaryRed
        : (isUsb ? SonicTokens.successGreen : SonicTokens.secondaryBlue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTrending
                ? Icons.local_fire_department_rounded
                : (isUsb ? Icons.usb_rounded : Icons.auto_awesome_rounded),
            size: 13,
            color: SonicTokens.textPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            tag,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SonicTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class CockpitTouchButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double minSize;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? glow;

  const CockpitTouchButton({
    super.key,
    required this.child,
    required this.onTap,
    this.minSize = SonicTokens.minTouchTarget,
    this.backgroundColor,
    this.borderRadius,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(SonicTokens.radiusLg),
        child: Container(
          constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
          decoration: BoxDecoration(
            color: backgroundColor ?? SonicTokens.surfaceElevated,
            borderRadius:
                borderRadius ?? BorderRadius.circular(SonicTokens.radiusLg),
            boxShadow: glow,
            border: Border.all(color: SonicTokens.glassBorder),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
