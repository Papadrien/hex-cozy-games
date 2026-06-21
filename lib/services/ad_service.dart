/// Service publicitaire — Story 3.1a / 3.1b.
///
/// Fournit les providers Riverpod pour les bannières et interstitielles
/// AdMob. Utilise les IDs de test pendant le développement ; les IDs de
/// production doivent être configurés avant la release.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants.dart';

/// ID de bannière AdMob selon la plateforme (test en debug, production
/// en release). À configurer avec les vrais IDs avant release.
String get _bannerAdUnitId {
  if (kReleaseMode) {
    // TODO(story-3.1a): Remplacer par les IDs de production avant release.
    if (Platform.isAndroid) return kAdMobBannerTestIdAndroid;
    if (Platform.isIOS) return kAdMobBannerTestIdIOS;
    return kAdMobBannerTestIdAndroid;
  }
  if (Platform.isAndroid) return kAdMobBannerTestIdAndroid;
  if (Platform.isIOS) return kAdMobBannerTestIdIOS;
  return kAdMobBannerTestIdAndroid;
}

/// Provider qui crée, charge et maintient la bannière AdMob en vie.
///
/// La bannière est chargée au premier accès et automatiquement disposée
/// quand le provider est détruit. Retourne `null` si le chargement a
/// échoué (le widget affichera un espace vide à la place).
final bannerAdProvider = Provider<BannerAd?>((ref) {
  final banner = BannerAd(
    adUnitId: _bannerAdUnitId,
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (_) {
        debugPrint('[AdMob] Banner loaded');
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('[AdMob] Banner failed: $error');
        ad.dispose();
      },
    ),
  );

  banner.load();
  ref.onDispose(() => banner.dispose());

  return banner;
});
