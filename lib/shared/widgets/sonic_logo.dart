import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/sonic_tokens.dart';

class SonicLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final double fontSize;

  const SonicLogo({
    super.key,
    this.size = 36,
    this.showWordmark = true,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
            boxShadow: SonicTokens.cyanGlow(opacity: 0.35),
          ),
          child: SvgPicture.asset(
            'assets/logo/logo.svg',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
              children: const [
                TextSpan(
                  text: 'Sonic',
                  style: TextStyle(color: SonicTokens.textPrimary),
                ),
                TextSpan(
                  text: 'lane',
                  style: TextStyle(color: SonicTokens.secondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
