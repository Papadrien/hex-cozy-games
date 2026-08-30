import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/snackbar_utils.dart';
import '../core/strings.dart';
import '../services/ad_service.dart';

import 'coin_icon.dart';
import 'glass_button.dart';
import 'glass_container.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON PUB REWARDED
// ─────────────────────────────────────────────────────────────────────────────

class HomeRewardedAdButton extends ConsumerWidget {
  const HomeRewardedAdButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAvailable = ref.watch(isDailyRewardAvailableProvider);
    final isLoading = ref.watch(isWatchingRewardedAdProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: GlassContainer(
            borderRadius: 16,
            tintColor: adAvailable ? kAdRewardOrange : kGlassBlue,
            tintAlpha: adAvailable ? 0.10 : 0.18,
            borderColor: adAvailable
                ? kAdRewardOrange.withValues(alpha: 0.45)
                : kGlassBlueBorder,
            borderWidth: adAvailable ? 1.5 : 1,
            blurSigma: 10,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            // Désactivé pendant le chargement pour éviter un double tap, en
            // plus du blocage plein écran posé par HomeScreen via
            // isWatchingRewardedAdProvider.
            onTap: adAvailable && !isLoading
                ? () async {
                    ref.read(isWatchingRewardedAdProvider.notifier).state =
                        true;
                    try {
                      final rewarded = await claimDailyReward(ref);
                      if (rewarded && context.mounted) {
                        showAppSnackBar(
                          SnackBar(
                            content: Text(
                                '+$kAdRewardedCoins ${context.tr.reward_coins}'),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        ref.read(isWatchingRewardedAdProvider.notifier)
                            .state = false;
                      }
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kAdRewardOrange,
                    ),
                  )
                else
                  Icon(
                    adAvailable
                        ? Icons.play_circle_outline
                        : Icons.check_circle_outline,
                    size: 20,
                    color: adAvailable
                        ? kAdRewardOrange
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                const SizedBox(width: 8),
                Text(
                  isLoading
                      ? context.tr.ads_loading
                      : adAvailable
                          ? context.tr.ads_watchForCoins
                          : context.tr.ads_comeBackTomorrow,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: adAvailable
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Même point rouge que le bouton "Quêtes" (_NavButton) lorsqu'une
        // récompense est disponible — signale la pub comme les quêtes en
        // attente de réclamation.
        if (adAvailable && !isLoading)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON PIÈCES QUOTIDIENNES PREMIUM
// ─────────────────────────────────────────────────────────────────────────────

class HomePremiumDailyCoinsButton extends ConsumerWidget {
  const HomePremiumDailyCoinsButton({
    super.key,
    required this.animController,
  });

  final AnimationController animController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(isPremiumDailyCoinsAvailableProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            tint: available ? kUpgradePurple : Colors.grey,
            onPressed: available
                ? () async {
                    final claimed = await claimPremiumDailyCoins(ref);
                    if (claimed && context.mounted) {
                      animController.forward().then((_) {
                        Future.delayed(const Duration(seconds: 2), () {
                          if (context.mounted) animController.reverse();
                        });
                      });
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                available
                    ? const CoinIcon(size: 20)
                    : Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                const SizedBox(width: 8),
                Text(
                  available
                      ? context.tr.premium_dailyCoinsButton
                      : context.tr.ads_comeBackTomorrow,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: available
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Même pastille rouge que le bouton pub (HomeRewardedAdButton)
        // lorsqu'une récompense est disponible.
        if (available)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
