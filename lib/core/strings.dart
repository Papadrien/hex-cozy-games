/// Wrapper i18n basé sur [AppLocalizations] (généré via flutter gen-l10n).
///
/// Fournit un accès concis via `context.tr.xxx` et [biomeName] pour les
/// traductions dynamiques non couvertes par les fichiers ARB.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Accès rapide aux traductions depuis n'importe quel [BuildContext].
extension AppLocalizationsX on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this)!;
}

/// Traduit une couleur de tuile (clé technique anglaise) vers l'affichage
/// localisé. Les tuiles n'ont pas de rendu thématique (village, forêt...) —
/// seule la couleur est visible, donc on affiche uniquement des noms de
/// couleur.
String biomeName(BuildContext context, String biome) {
  if (!AppLocalizations.of(context)!.localeName.startsWith('fr')) return biome;
  switch (biome) {
    case 'forest':
      return 'Vert';
    case 'village':
      return 'Rouge';
    case 'plain':
      return 'Jaune';
    case 'water':
      return 'Bleu';
    case 'mountain':
      return 'Violet';
    case 'orange':
      return 'Orange';
    case 'pink':
      return 'Rose';
    case 'black':
      return 'Noir';
    case 'white':
      return 'Blanc';
    default:
      return biome;
  }
}
