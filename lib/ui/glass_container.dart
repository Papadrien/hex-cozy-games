import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/colors.dart';

/// Composant glassmorphism réutilisable — applique [BackdropFilter] avec
/// flou, fond semi-transparent et bordure assortie.
///
/// Paramètres par défaut : teinte teal tropicale, rayon 14, blur 10.
/// Fournir [onTap] pour rendre le container cliquable (InkWell).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.tintColor = kTropicalTeal,
    this.tintAlpha = 0.22,
    this.borderColor,
    this.borderWidth = 1.0,
    this.blurSigma = 10,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final double borderRadius;
  final Color tintColor;
  final double tintAlpha;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  Color get _resolvedBorderColor =>
      borderColor ?? tintColor.withValues(alpha: tintAlpha + 0.2);

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _resolvedBorderColor,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    final inner = onTap != null
        ? Material(
            color: tintColor.withValues(alpha: tintAlpha),
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap,
              child: container,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: tintAlpha),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: container,
          );

    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: inner,
      ),
    );

    return margin != null ? Padding(padding: margin!, child: glass) : glass;
  }
}
