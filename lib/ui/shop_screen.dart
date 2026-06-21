import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../providers/player_profile_provider.dart';

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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr.shop_title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _SectionHeader(label: context.tr.shop_coinPacks),
          const SizedBox(height: 12),
          ...List.generate(kCoinPacks.length, (i) {
            final pack = kCoinPacks[i];
            return _CoinPackCard(pack: pack, index: i);
          }),
          const SizedBox(height: 24),
          _SectionHeader(label: context.tr.shop_premium),
          const SizedBox(height: 12),
          _PremiumCard(isPremium: isPremium),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({required this.pack, required this.index});

  final CoinPack pack;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isBestValue = index == kCoinPacks.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBestValue
            ? Colors.amber.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBestValue
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          width: isBestValue ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          _CoinStackIcon(index: index),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.shop_coinCount(pack.coins.toString()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isBestValue) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MEILLEUR RAPPORT',
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              backgroundColor: kRewardGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr.shop_comingSoon),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              pack.price,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinStackIcon extends StatelessWidget {
  const _CoinStackIcon({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final iconSize = 20.0 + index * 4;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: kRewardGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.monetization_on,
        size: iconSize,
        color: kRewardGold,
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPremium
            ? kUpgradePurple.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? kUpgradePurple.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kUpgradePurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.star,
                  size: 26,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr.shop_premiumDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                    isPremium ? Colors.white.withValues(alpha: 0.08) : kUpgradePurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isPremium
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr.shop_comingSoon),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              child: Text(
                isPremium
                    ? context.tr.shop_alreadyPremium
                    : context.tr.shop_buy,
                style: TextStyle(
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
