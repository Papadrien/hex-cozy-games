library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/player_profile_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/quest_provider.dart';

class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upgradesAsync = ref.watch(upgradesProvider);
    final questsAsync = ref.watch(permanentQuestsProvider);
    final totalCoinsAsync = ref.watch(totalCoinsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2332),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          Str.upgrades_title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: upgradesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, _) => Center(
          child: Text(
            'Erreur',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        data: (upgrades) {
          final questMap = questsAsync.maybeWhen(
            data: (list) => {
              for (final q in list) q.id: q.description,
            },
            orElse: () => <String, String>{},
          );
          return _UpgradesList(
            upgrades: upgrades,
            questDescriptions: questMap,
            totalCoins: totalCoinsAsync,
          );
        },
      ),
    );
  }
}

class _UpgradesList extends StatelessWidget {
  const _UpgradesList({
    required this.upgrades,
    required this.questDescriptions,
    required this.totalCoins,
  });

  final List<UpgradeRow> upgrades;
  final Map<String, String> questDescriptions;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    final unlocked = upgrades.where((u) => u.isUnlocked).toList();
    final locked = upgrades.where((u) => !u.isUnlocked).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        if (unlocked.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.check_circle,
            color: const Color(0xFF4CAF50),
            label: 'Débloquées',
          ),
          const SizedBox(height: 8),
          ...unlocked.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UpgradeCard(
                upgrade: u,
                isLocked: false,
                questDescriptions: questDescriptions,
                totalCoins: totalCoins,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (locked.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.lock,
            color: Colors.white.withValues(alpha: 0.5),
            label: 'Verrouillées',
          ),
          const SizedBox(height: 8),
          ...locked.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UpgradeCard(
                upgrade: u,
                isLocked: true,
                questDescriptions: questDescriptions,
                totalCoins: totalCoins,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.isLocked,
    required this.questDescriptions,
    required this.totalCoins,
  });

  final UpgradeRow upgrade;
  final bool isLocked;
  final Map<String, String> questDescriptions;
  final int totalCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isLocked ? 0.03 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF6FA8DC).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLocked ? Icons.lock : Icons.auto_awesome,
                  color: isLocked
                      ? Colors.white.withValues(alpha: 0.4)
                      : const Color(0xFF6FA8DC),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  upgrade.name,
                  style: TextStyle(
                    color: isLocked
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.tune,
                  size: 14,
                  color: isLocked
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                isLocked ? Str.upgrades_hiddenEffect : _effectLabel(upgrade),
                style: TextStyle(
                  color: isLocked
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontStyle: isLocked ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isLocked) ...[
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${Str.upgrades_unlockCondition} : ${_conditionLabel(upgrade, questDescriptions)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            _LevelsPreview(upgrade: upgrade),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.stars,
                    size: 14,
                    color: Colors.amber.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  '${Str.upgrades_level} ${upgrade.currentLevel + 1}',
                  style: TextStyle(
                    color: Colors.amber.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _UpgradeButton(upgrade: upgrade, totalCoins: totalCoins),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne de preview des 3 niveaux avec effet de chaque palier.
class _LevelsPreview extends StatelessWidget {
  const _LevelsPreview({required this.upgrade});

  final UpgradeRow upgrade;

  @override
  Widget build(BuildContext context) {
    final levels = _allLevelEffects(upgrade.effectType);

    return Row(
      children: [
        for (var i = 0; i < levels.length; i++)
          Expanded(
            child: _LevelDot(
              index: i,
              label: levels[i],
              isCurrent: i == upgrade.currentLevel,
              isReached: i <= upgrade.currentLevel,
            ),
          ),
      ],
    );
  }
}

/// Un petit palier dans la ligne de niveaux.
class _LevelDot extends StatelessWidget {
  const _LevelDot({
    required this.index,
    required this.label,
    required this.isCurrent,
    required this.isReached,
  });

  final int index;
  final String label;
  final bool isCurrent;
  final bool isReached;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? const Color(0xFF6FA8DC)
        : isReached
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            if (index < 2)
              Container(
                height: 2,
                width: 12,
                color: isReached && index < 2
                    ? color
                    : Colors.white.withValues(alpha: 0.1),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Niv.${index + 1}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Bouton Améliorer avec coût affiché, désactivé si pièces insuffisantes.
class _UpgradeButton extends ConsumerWidget {
  const _UpgradeButton({
    required this.upgrade,
    required this.totalCoins,
  });

  final UpgradeRow upgrade;
  final int totalCoins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMaxLevel = upgrade.currentLevel >= kUpgradeCosts.length;
    if (isMaxLevel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          Str.upgrades_max,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final cost = kUpgradeCosts[upgrade.currentLevel];
    final canAfford = totalCoins >= cost;

    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: canAfford
            ? const Color(0xFF6FA8DC).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: canAfford
          ? () => _handleUpgrade(context, ref)
          : null,
      child: Text(
        '${Str.upgrades_cost} : $cost  ${Str.upgrades_upgradeButton}',
        style: TextStyle(
          color: canAfford
              ? const Color(0xFF6FA8DC).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.3),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context, WidgetRef ref) async {
    final service = ref.read(progressionServiceProvider);
    final result = await service.levelUpUpgrade(upgrade.id);

    if (!context.mounted) return;

    final (message, color) = switch (result) {
      UpgradeResult.success => (
        '${upgrade.name} → ${Str.upgrades_level} ${upgrade.currentLevel + 2}',
        const Color(0xFF4CAF50),
      ),
      UpgradeResult.insufficientCoins => (
        'Pièces insuffisantes',
        Colors.orange,
      ),
      UpgradeResult.maxLevelReached => (
        'Niveau maximum atteint',
        Colors.white.withValues(alpha: 0.5),
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

// ── Helpers ──────────────────────────────────────────────────────────────

String _effectLabel(UpgradeRow upgrade) {
  final allLevels = _allLevelEffects(upgrade.effectType);
  final idx = upgrade.currentLevel < allLevels.length
      ? upgrade.currentLevel
      : allLevels.length - 1;
  return allLevels[idx];
}

List<String> _allLevelEffects(String effectType) {
  switch (effectType) {
    case 'starting_tiles_bonus':
      return ['+2', '+5', '+10'];
    case 'connection_bonus_multiplier':
      return ['x2', 'x2', 'x2'];
    case 'coins_percent_bonus':
      return ['+10%', '+20%', '+30%'];
    case 'village_coins_percent_bonus':
      return ['+33%', '+66%', '+100%'];
    default:
      return ['', '', ''];
  }
}

String _conditionLabel(
  UpgradeRow upgrade,
  Map<String, String> questDescriptions,
) {
  if (upgrade.unlockConditionType == 'tiles_placed') {
    return 'Poser ${upgrade.unlockConditionValue} tuiles';
  }
  return questDescriptions[upgrade.unlockConditionType] ??
      upgrade.unlockConditionType;
}
