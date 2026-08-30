import 'package:flutter/material.dart';

import '../core/colors.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';

/// Bouton glassmorphism réutilisable — teinte bleu glacier.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.tint = Colors.transparent,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color tint;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tintColor: kGlassBlue,
      tintAlpha: 0.18,
      borderColor: kGlassBlueBorder,
      borderRadius: 16,
      padding: padding,
      blurSigma: 10,
      onTap: onPressed != null
          ? () {
              if (onPressed != null) {
                buttonTapFeedback(context);
                onPressed();
              }
            }
          : null,
      child: tint == Colors.transparent
          ? child
          : Stack(
              children: [
                child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
