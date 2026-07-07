import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../providers/player_profile_provider.dart';
import '../services/iap_service.dart';
import '../services/haptics_service.dart';
import 'glass_container.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHOP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final isPremium = profile.maybeWhen(
      data: (row) => row.isPremium,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Même fond tropical que l'accueil ──────────────────────────────
          Image.asset(
            'assets/images/home_background.png',
            fit: BoxFit.cover,
          ),
          // ── Voile bleuté — signature des écrans secondaires ───────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1B3E).withValues(alpha: 0.72),
                  const Color(0xFF0A1628).withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          // ── Contenu ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShopAppBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    children: [
                      _GlassSectionHeader(label: context.tr.shop_coinPacks),
                      const SizedBox(height: 12),
                      ...List.generate(kCoinPacks.length, (i) {
                        final pack = kCoinPacks[i];
                        return _CoinPackCard(pack: pack, index: i);
                      }),
                      const SizedBox(height: 24),
                      _GlassSectionHeader(label: context.tr.shop_premium),
                      const SizedBox(height: 12),
                      _PremiumCard(isPremium: isPremium),
                      const SizedBox(height: 24),
                      _RestoreButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR GLASS
// ─────────────────────────────────────────────────────────────────────────────

class _ShopAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Bouton fermer glassmorphism
          _ShopGlassIconButton(
            icon: Icons.close,
            onPressed: () {
              buttonHapticTap(context);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 14),
          Text(
            context.tr.shop_title,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopGlassIconButton extends StatelessWidget {
  const _ShopGlassIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      tintColor: kGlassBlue,
      tintAlpha: 0.22,
      borderColor: kGlassBlueBorder.withValues(alpha: 0.38),
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EN-TÊTE DE SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSectionHeader extends StatelessWidget {
  const _GlassSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: kBrandBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE PACK DE PIÈCES
// ─────────────────────────────────────────────────────────────────────────────

class _CoinPackCard extends ConsumerStatefulWidget {
  const _CoinPackCard({required this.pack, required this.index});
  final CoinPack pack;
  final int index;

  @override
  ConsumerState<_CoinPackCard> createState() => _CoinPackCardState();
}

class _CoinPackCardState extends ConsumerState<_CoinPackCard> {
  bool _loading = false;

  void _showPurchaseResult(BuildContext context, IapResult result, int coins) {
    final (String message, Color color) = switch (result) {
      IapResult.success => (
          '+$coins ${context.tr.reward_coins}',
          Colors.green.withValues(alpha: 0.3),
        ),
      IapResult.restored => (
          '+$coins ${context.tr.reward_coins}',
          Colors.green.withValues(alpha: 0.3),
        ),
      IapResult.canceled => (
          context.tr.shop_purchaseCanceled,
          Colors.white.withValues(alpha: 0.1),
        ),
      IapResult.pending => (
          context.tr.shop_purchasePending,
          Colors.amber.withValues(alpha: 0.3),
        ),
      IapResult.error => (
          context.tr.shop_purchaseError,
          Colors.red.withValues(alpha: 0.3),
        ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBestValue = widget.index == kCoinPacks.length - 1;
    final iapAvailable = ref.watch(iapAvailableProvider);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 18,
      tintColor: isBestValue ? kRewardGold : kGlassBlue,
      tintAlpha: 0.10,
      borderColor: isBestValue ? kRewardGold.withValues(alpha: 0.45) : kGlassBlueBorder.withValues(alpha: 0.38),
      borderWidth: isBestValue ? 1.5 : 1,
      blurSigma: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _CoinStackIcon(index: widget.index, isBestValue: isBestValue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.shop_coinCount(widget.pack.coins.toString()),
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isBestValue) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: kRewardGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: kRewardGold.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      context.tr.shop_bestValueBadge,
                      style: TextStyle(
                        color: kRewardGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _PriceButton(
            price: widget.pack.price,
            loading: _loading,
            available: iapAvailable,
            onTap: (_loading || !iapAvailable)
                ? null
                : () async {
                    buttonHapticTap(context);
                    setState(() => _loading = true);
                    try {
                      final result =
                          await purchaseCoinPack(ref, widget.index);
                      if (!context.mounted) return;
                      _showPurchaseResult(
                          context, result, widget.pack.coins);
                    } finally {
                      if (context.mounted) {
                        setState(() => _loading = false);
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON PRIX GLASS
// ─────────────────────────────────────────────────────────────────────────────

class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.price,
    required this.loading,
    required this.available,
    required this.onTap,
  });
  final String price;
  final bool loading;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      tintColor: available ? kGlassBlue : Colors.white,
      tintAlpha: available ? 0.32 : 0.08,
      borderColor: available
          ? kGlassBlueBorder.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.12),
      blurSigma: 8,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: 42,
      onTap: onTap,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                price,
                style: TextStyle(
                  color: available
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ICÔNE PIÈCES
// ─────────────────────────────────────────────────────────────────────────────

class _CoinStackIcon extends StatelessWidget {
  const _CoinStackIcon({required this.index, required this.isBestValue});
  final int index;
  final bool isBestValue;

  @override
  Widget build(BuildContext context) {
    final iconSize = 20.0 + index * 4;

    return GlassContainer(
      borderRadius: 14,
      tintColor: isBestValue ? kRewardGold : kGlassBlue,
      tintAlpha: 0.22,
      borderColor: isBestValue
          ? kRewardGold.withValues(alpha: 0.35)
          : kGlassBlueBorder.withValues(alpha: 0.35),
      borderWidth: 0.8,
      blurSigma: 6,
      width: 48,
      height: 48,
      child: Icon(
        Icons.monetization_on,
        size: iconSize,
        color: kRewardGold,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE PREMIUM
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumCard extends ConsumerStatefulWidget {
  const _PremiumCard({required this.isPremium});
  final bool isPremium;

  @override
  ConsumerState<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends ConsumerState<_PremiumCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final iapAvailable = ref.watch(iapAvailableProvider);

    final buttonTint = _loading || (!widget.isPremium && iapAvailable)
        ? kUpgradePurple
        : Colors.white;
    final buttonAlpha = (_loading || (!widget.isPremium && iapAvailable)) ? 0.35 : 0.07;

    return GlassContainer(
      borderRadius: 20,
      tintColor: widget.isPremium ? kUpgradePurple : kGlassBlue,
      tintAlpha: widget.isPremium ? 0.18 : 0.22,
      borderColor: widget.isPremium
          ? kUpgradePurple.withValues(alpha: 0.50)
          : kGlassBlueBorder.withValues(alpha: 0.38),
      borderWidth: widget.isPremium ? 1.5 : 1,
      blurSigma: 14,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Icône étoile
              GlassContainer(
                borderRadius: 14,
                tintColor: kUpgradePurple,
                tintAlpha: 0.20,
                borderColor: kUpgradePurple.withValues(alpha: 0.40),
                borderWidth: 0.8,
                blurSigma: 6,
                width: 52,
                height: 52,
                child: const Icon(
                  Icons.star_rounded,
                  size: 28,
                  color: kUpgradePurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.shop_premium,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr.shop_premiumDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Bouton Acheter — glassmorphism violet
          GlassContainer(
            borderRadius: 14,
            tintColor: buttonTint,
            tintAlpha: buttonAlpha,
            borderColor: widget.isPremium
                ? Colors.white.withValues(alpha: 0.12)
                : kUpgradePurple.withValues(alpha: 0.55),
            blurSigma: 8,
            padding: const EdgeInsets.symmetric(vertical: 15),
            onTap: (widget.isPremium || _loading || !iapAvailable)
                ? null
                : () async {
                    buttonHapticTap(context);
                    setState(() => _loading = true);
                    try {
                      final result = await purchasePremium(ref);
                      if (!context.mounted) return;
                      if (result == IapResult.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr.shop_premium),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        _showPremiumResult(context, result);
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => _loading = false);
                      }
                    }
                  },
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.isPremium
                          ? context.tr.shop_alreadyPremium
                          : context.tr.shop_buy,
                      style: GoogleFonts.nunito(
                        color: widget.isPremium
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumResult(BuildContext context, IapResult result) {
    final (String message, Color color) = switch (result) {
      IapResult.canceled => (
          context.tr.shop_purchaseCanceled,
          Colors.white.withValues(alpha: 0.1),
        ),
      IapResult.pending => (
          context.tr.shop_purchasePending,
          Colors.amber.withValues(alpha: 0.3),
        ),
      IapResult.error => (
          context.tr.shop_purchaseError,
          Colors.red.withValues(alpha: 0.3),
        ),
      _ => (
          context.tr.shop_purchaseError,
          Colors.red.withValues(alpha: 0.3),
        ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOUTON RESTAURER
// ─────────────────────────────────────────────────────────────────────────────

class _RestoreButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RestoreButton> createState() => _RestoreButtonState();
}

class _RestoreButtonState extends ConsumerState<_RestoreButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      tintColor: kGlassBlue,
      tintAlpha: 0.18,
      borderColor: kGlassBlueBorder.withValues(alpha: 0.30),
      blurSigma: 8,
      padding: const EdgeInsets.symmetric(vertical: 14),
      onTap: _loading
          ? null
          : () async {
              buttonHapticTap(context);
              setState(() => _loading = true);
              try {
                final ok = await restoreAllPurchases(ref);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? context.tr.shop_restoreCompleted
                        : context.tr.shop_restoreError),
                    backgroundColor: ok
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                if (context.mounted) {
                  setState(() => _loading = false);
                }
              }
            },
      child: Center(
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restore,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.45)),
                  const SizedBox(width: 8),
                  Text(
                    context.tr.shop_restorePurchases,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
