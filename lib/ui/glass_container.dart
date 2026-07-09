import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/colors.dart';

/// Composant glassmorphism réutilisable — applique [BackdropFilter] avec
/// flou, fond semi-transparent et bordure assortie.
///
/// Paramètres par défaut : bleu nuit tealisé, rayon 14, blur 10.
/// Fournir [onTap] pour rendre le container cliquable (InkWell).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.tintColor = kGlassBlue,
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

  /// Couleur de bordure « brute », avant garantie de lisibilité par rapport
  /// au fond (voir [_lightenAboveBackground]).
  Color get _rawBorderColor =>
      borderColor ?? tintColor.withValues(alpha: tintAlpha + 0.2);

  /// Couleur de bordure finale : toujours plus claire que le fond du
  /// composant (teinte/opacité d'origine conservées, seule la clarté est
  /// ajustée si besoin) pour préserver l'effet vitreux du glassmorphism.
  Color get _resolvedBorderColor =>
      _lightenAboveBackground(_rawBorderColor, tintColor);

  /// Épaisseur de bordure finale — doublée par rapport à [borderWidth] pour
  /// que le contour reste bien visible malgré le flou de fond.
  double get _resolvedBorderWidth => borderWidth * 2;

  /// Rapproche [color] du blanc, par petits paliers et sans toucher à son
  /// alpha d'origine, jusqu'à ce qu'elle soit perceptiblement plus claire
  /// que [background]. Si [color] est déjà assez claire, elle est renvoyée
  /// telle quelle.
  Color _lightenAboveBackground(Color color, Color background) {
    final double targetLuminance = background.computeLuminance() + 0.12;
    Color result = color;
    double t = 0.0;
    while (result.computeLuminance() < targetLuminance && t < 1.0) {
      t += 0.1;
      result = Color.lerp(color, Colors.white, t)!.withValues(alpha: color.a);
    }
    return result;
  }

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
          width: _resolvedBorderWidth,
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

    // RepaintBoundary : isole le flou dans son propre layer pour éviter que
    // le sous-arbre entier ne soit repeint (et potentiellement mal recomposé)
    // pendant l'animation de rebond (bounce-back) en haut/bas d'un scroll.
    //
    // Opacity(0.999) : la RepaintBoundary seule ne suffit pas — pendant le
    // rebond, Flutter peut réévaluer `needsCompositing` de ce sous-arbre à
    // chaque frame (les bounds de peinture changent avec l'offset de
    // rebond), et le layer de `BackdropFilter` (qui repose sur un
    // saveLayer) est alors parfois recréé sans contenu source valide à
    // flouter le temps d'une frame — d'où la disparition visible du fond.
    // Fixer une opacité quasi-1 (au lieu de 1.0 exactement) force ce
    // sous-arbre à toujours être composité sur son propre layer de façon
    // stable, indépendamment des bounds changeants du parent, ce qui
    // supprime le clignotement. C'est un contournement connu du moteur
    // Flutter pour ce bug de BackdropFilter en liste à rebond.
    final glass = RepaintBoundary(
      child: Opacity(
        opacity: 0.999,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: inner,
          ),
        ),
      ),
    );

    return margin != null ? Padding(padding: margin!, child: glass) : glass;
  }
}
