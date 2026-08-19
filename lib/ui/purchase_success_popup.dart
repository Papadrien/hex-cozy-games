/// Pop-up de célébration affichée lorsqu'un achat in-app aboutit
/// (`IapResult.success`) — pack de pièces ou premium, voir
/// `shop_screen.dart` (`_CoinPackCardState` / `_PremiumCard`).
///
/// Volontairement plus marquée que l'animation de récompense de quête
/// ([QuestCard]) dont elle reprend les briques (bounce élastique, halo,
/// [QuestRewardBurst]) : un achat réel est un événement plus rare, la
/// célébration doit se sentir nettement au-dessus — confetti multicolore
/// (au lieu d'une seule teinte ambrée), compteur de pièces qui défile
/// jusqu'au montant final plutôt qu'un texte statique, triple impact
/// haptique ([HapticsService.purchaseSuccess]) et fanfare dédiée
/// ([AudioService.playPurchaseSuccess]).
///
/// Se ferme automatiquement après [_kAutoDismissDelay], ou immédiatement
/// sur tap (fond flouté ou bouton "Continuer").
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/strings.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import 'coin_icon.dart';
import 'glass_container.dart';
import 'quest_reward_burst.dart';

/// Affiche la pop-up de succès d'achat.
///
/// [coins] : montant à afficher en compteur animé pour un pack de pièces —
/// `null` pour un achat premium (aucun montant, icône étoile à la place).
Future<void> showPurchaseSuccessPopup(
  BuildContext context,
  WidgetRef ref, {
  int? coins,
  bool isPremium = false,
}) {
  // Déclenchés une seule fois à l'ouverture, avant même que l'entrée
  // n'anime — même principe que [QuestCardState._handleClaim] (haptique +
  // son lancés en fire-and-forget, non bloquants pour l'animation).
  unawaited(ref.read(hapticsServiceProvider).purchaseSuccess());
  unawaited(ref.read(audioServiceProvider).playPurchaseSuccess());

  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'purchase_success',
    barrierDismissible: true,
    barrierColor: const Color(0xFF0D1A2A).withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _PurchaseSuccessContent(coins: coins, isPremium: isPremium);
    },
  );
}

class _PurchaseSuccessContent extends StatefulWidget {
  const _PurchaseSuccessContent({this.coins, required this.isPremium});

  final int? coins;
  final bool isPremium;

  @override
  State<_PurchaseSuccessContent> createState() =>
      _PurchaseSuccessContentState();
}

class _PurchaseSuccessContentState extends State<_PurchaseSuccessContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _burstAnim;
  late final Animation<int> _counterAnim;
  Timer? _autoDismissTimer;

  static const _kAutoDismissDelay = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Rebond élastique prononcé — dépasse volontairement 1.0 avant de se
    // stabiliser, plus marqué que celui de [QuestCard] (1.08 max) pour
    // rester cohérent avec un événement plus important.
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.14,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);
    _burstAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    // Le compteur démarre un peu après le début du bounce (le temps que la
    // carte "atterrisse") et termine avant la toute fin de l'animation,
    // pour que le montant final soit déjà stable au moment où tout se fige.
    _counterAnim = IntTween(begin: 0, end: widget.coins ?? 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _autoDismissTimer = Timer(_kAutoDismissDelay, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isPremium ? kUpgradePurple : kCoinAmber;
    final confettiColors = widget.isPremium
        ? [kUpgradePurple, Colors.white, kCoinAmber]
        : [kCoinAmber, Colors.white, Colors.orangeAccent];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Center(
          child: GestureDetector(
            // Absorbe le tap pour que toucher la carte elle-même ne ferme
            // pas la pop-up — seul le fond ou le bouton "Continuer" ferme.
            onTap: () {},
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Halo doré/violet statique derrière la carte, présent
                    // dès le début du bounce et jusqu'à la fermeture.
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.35),
                            accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    QuestRewardBurst(
                      progress: _burstAnim.value,
                      colors: confettiColors,
                      particleCount: 18,
                      maxDistance: 100,
                    ),
                    Transform.scale(
                      scale: _bounceAnim.value.clamp(0.0, 1.2),
                      child: child,
                    ),
                  ],
                );
              },
              child: _PurchaseSuccessCard(
                coins: widget.coins,
                isPremium: widget.isPremium,
                counterAnim: _counterAnim,
                accent: accent,
                onContinue: _dismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseSuccessCard extends StatelessWidget {
  const _PurchaseSuccessCard({
    required this.coins,
    required this.isPremium,
    required this.counterAnim,
    required this.accent,
    required this.onContinue,
  });

  final int? coins;
  final bool isPremium;
  final Animation<int> counterAnim;
  final Color accent;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: GlassContainer(
        borderRadius: 22,
        tintColor: accent,
        tintAlpha: 0.16,
        borderColor: accent.withValues(alpha: 0.5),
        borderWidth: 1.5,
        blurSigma: 14,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.20),
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: isPremium
                  ? const Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: kUpgradePurple,
                    )
                  : const Padding(
                      padding: EdgeInsets.all(14),
                      child: CoinIcon(size: 36),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              isPremium
                  ? context.tr.shop_purchaseSuccessPremiumTitle
                  : context.tr.shop_purchaseSuccessCoinsTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (isPremium)
              Text(
                context.tr.shop_premiumDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              )
            else
              AnimatedBuilder(
                animation: counterAnim,
                builder: (context, _) {
                  return Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '+${counterAnim.value}',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              color: kCoinAmber,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr.shop_purchaseSuccessCoinsSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GlassContainer(
                borderRadius: 12,
                tintColor: accent,
                tintAlpha: 0.30,
                borderColor: accent.withValues(alpha: 0.6),
                blurSigma: 8,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: () {
                  buttonTapFeedback(context);
                  onContinue();
                },
                child: Center(
                  child: Text(
                    context.tr.shop_purchaseSuccessContinue,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
