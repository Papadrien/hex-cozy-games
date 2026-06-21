/// Service publicitaire — Story 3.1a / 3.1b / 3.2a.
///
/// Fournit les providers Riverpod pour les bannières, interstitielles et
/// rewarded AdMob. Utilise les IDs de test pendant le développement ; les IDs
/// de production doivent être configurés avant la release.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants.dart';
import '../data/app_database.dart';
import '../providers/player_profile_provider.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

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

String get _interstitialAdUnitId {
  if (kReleaseMode) {
    // TODO(story-3.1b): Remplacer par les IDs de production avant release.
    if (Platform.isAndroid) return kAdMobInterstitialTestIdAndroid;
    if (Platform.isIOS) return kAdMobInterstitialTestIdIOS;
    return kAdMobInterstitialTestIdAndroid;
  }
  if (Platform.isAndroid) return kAdMobInterstitialTestIdAndroid;
  if (Platform.isIOS) return kAdMobInterstitialTestIdIOS;
  return kAdMobInterstitialTestIdAndroid;
}

// ── Bannière (3.1a) ────────────────────────────────────────────────────────

/// Provider qui crée, charge et maintient la bannière AdMob en vie.
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

// ── Interstitielle (3.1b) ──────────────────────────────────────────────────

/// Compteur cumulatif de tuiles posées pour le déclenchement des
/// interstitielles. Persiste entre les parties (pas de reset dans
/// [startNewGame]).
class AdTilesPlacedNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final adTilesPlacedProvider =
    NotifierProvider<AdTilesPlacedNotifier, int>(AdTilesPlacedNotifier.new);

/// Charge et affiche une interstitielle AdMob. Retourne immédiatement
/// si le chargement échoue (pas de crash).
Future<void> showInterstitialAd() async {
  await InterstitialAd.load(
    adUnitId: _interstitialAdUnitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('[AdMob] Interstitial show failed: $error');
            ad.dispose();
          },
        );
        ad.show();
      },
      onAdFailedToLoad: (error) {
        debugPrint('[AdMob] Interstitial load failed: $error');
      },
    ),
  );
}

// ── Récompense quotidienne (3.2a) ──────────────────────────────────────────

/// ID de la rewarded AdMob selon la plateforme (test en debug, production
/// en release).
String get _rewardedAdUnitId {
  if (kReleaseMode) {
    // TODO(story-3.2a): Remplacer par les IDs de production avant release.
    if (Platform.isAndroid) return kAdMobRewardedTestIdAndroid;
    if (Platform.isIOS) return kAdMobRewardedTestIdIOS;
    return kAdMobRewardedTestIdAndroid;
  }
  if (Platform.isAndroid) return kAdMobRewardedTestIdAndroid;
  if (Platform.isIOS) return kAdMobRewardedTestIdIOS;
  return kAdMobRewardedTestIdAndroid;
}

/// Date du dernier reward quotidien.
final lastDailyRewardDateProvider = Provider<DateTime?>((ref) {
  final profile = ref.watch(playerProfileProvider);
  return profile.maybeWhen(
    data: (row) => row.lastDailyRewardDate,
    orElse: () => null,
  );
});

/// true si la récompense quotidienne est disponible (aucun reward aujourd'hui).
final isDailyRewardAvailableProvider = Provider<bool>((ref) {
  final lastDate = ref.watch(lastDailyRewardDateProvider);
  if (lastDate == null) return true;
  final now = DateTime.now();
  return now.year != lastDate.year ||
      now.month != lastDate.month ||
      now.day != lastDate.day;
});

/// Charge et affiche une rewarded AdMob.
///
/// Retourne `true` si l'utilisateur a regardé la vidéo entièrement et gagné
/// la récompense, `false` en cas d'échec (fermeture anticipée, erreur de
/// chargement, etc.). Ne crash jamais.
Future<bool> showRewardedAd() async {
  final completer = Completer<bool>();

  await RewardedAd.load(
    adUnitId: _rewardedAdUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            if (!completer.isCompleted) completer.complete(false);
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('[AdMob] Rewarded show failed: $error');
            ad.dispose();
            if (!completer.isCompleted) completer.complete(false);
          },
        );
        ad.show(onUserEarnedReward: (ad, reward) {
          debugPrint('[AdMob] Reward earned');
          if (!completer.isCompleted) completer.complete(true);
        });
      },
      onAdFailedToLoad: (error) {
        debugPrint('[AdMob] Rewarded load failed: $error');
        if (!completer.isCompleted) completer.complete(false);
      },
    ),
  );

  return completer.future;
}

/// Réclame la récompense quotidienne.
///
/// 1. Vérifie si la récompense est disponible (pas déjà réclamée aujourd'hui).
/// 2. Affiche une rewarded AdMob.
/// 3. Si l'utilisateur regarde la vidéo entièrement : crédite
///    [kAdRewardedCoins] pièces et met à jour [lastDailyRewardDate].
///
/// Retourne `true` si la récompense a été créditée, `false` sinon (indisponible,
/// visionnage incomplet, échec de chargement).
Future<bool> claimDailyReward(WidgetRef ref) async {
  final available = ref.read(isDailyRewardAvailableProvider);
  if (!available) return false;

  final rewarded = await showRewardedAd();
  if (!rewarded) return false;

  final db = ref.read(appDatabaseProvider);
  await addCoinsToProfile(db, kAdRewardedCoins);
  await updateLastDailyRewardDate(db);
  return true;
}
