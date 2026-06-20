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

/// Traduit un nom de biome (clé technique anglaise) vers l'affichage localisé.
String biomeName(BuildContext context, String biome) {
  if (!AppLocalizations.of(context)!.localeName.startsWith('fr')) return biome;
  switch (biome) {
    case 'forest':
      return 'Forêt';
    case 'village':
      return 'Village';
    case 'plain':
      return 'Plaine';
    case 'water':
      return 'Eau';
    case 'mountain':
      return 'Montagne';
    default:
      return biome;
  }
}
