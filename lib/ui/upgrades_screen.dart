/// Écran des améliorations — Story 2.5b.
///
/// Affiche les améliorations débloquées (nom + effet + niveau) et
/// verrouillées (nom + effet masqué + condition de déblocage).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/progression_provider.dart';
import '../providers/quest_provider.dart';

class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upgradesAsync = ref.watch(upgradesProvider);
    final questsAsync = ref.watch(permanentQuestsProvider);

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
  });

  final List<UpgradeRow> upgrades;
  final Map<String, String> questDescriptions;

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
  });

  final UpgradeRow upgrade;
  final bool isLocked;
  final Map<String, String> questDescriptions;

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
          // Name row
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
          // Effect line
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
          // Condition or level
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
                _UpgradeButton(upgrade: upgrade),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton Améliorer (placeholder — la mécanique de coût sera ajoutée
/// dans une story ultérieure).
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.upgrade});

  final UpgradeRow upgrade;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: const Color(0xFF6FA8DC).withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Amélioration à venir'),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Text(
        Str.upgrades_upgradeButton,
        style: TextStyle(
          color: const Color(0xFF6FA8DC).withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _effectLabel(UpgradeRow upgrade) {
  switch (upgrade.effectType) {
    case 'starting_tiles_bonus':
      const bonuses = [2, 5, 10];
      final value = upgrade.currentLevel < bonuses.length
          ? bonuses[upgrade.currentLevel]
          : bonuses.last;
      return 'Tuiles de départ +$value';
    case 'connection_bonus_multiplier':
      return 'Bonus de connexion x2';
    case 'coins_percent_bonus':
      const bonuses = [10, 20, 30];
      final value = upgrade.currentLevel < bonuses.length
          ? bonuses[upgrade.currentLevel]
          : bonuses.last;
      return 'Pièces +$value%';
    case 'village_coins_percent_bonus':
      const bonuses = [33, 66, 100];
      final value = upgrade.currentLevel < bonuses.length
          ? bonuses[upgrade.currentLevel]
          : bonuses.last;
      return 'Village +$value%';
    default:
      return upgrade.effectType;
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
