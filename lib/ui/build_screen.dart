/// Écran de sélection des améliorations avant une partie — Story 2.7b.
///
/// Liste toutes les améliorations débloquées. Tap pour sélectionner /
/// désélectionner (0 à [kMaxSelectedUpgrades]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_enums.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../providers/build_provider.dart';
import '../providers/progression_provider.dart';

class BuildScreen extends ConsumerWidget {
  const BuildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedUpgradesProvider);
    final selected = ref.watch(selectedUpgradeIdsProvider);

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
          Str.home_buildSelection,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: unlocked.isEmpty
          ? Center(
              child: Text(
                'Aucune amélioration débloquée',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${selected.length} / $kMaxSelectedUpgrades',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                ...unlocked.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BuildCard(
                        upgrade: u,
                        isSelected: selected.contains(u.id),
                        onTap: () => ref
                            .read(selectedUpgradeIdsProvider.notifier)
                            .toggle(u.id),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _BuildCard extends StatelessWidget {
  const _BuildCard({
    required this.upgrade,
    required this.isSelected,
    required this.onTap,
  });

  final UpgradeRow upgrade;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF6FA8DC)
        : Colors.white.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6FA8DC).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6FA8DC).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                upgradeIconData(UpgradeEffectType.fromDb(upgrade.effectType)),
                color: isSelected
                    ? const Color(0xFF6FA8DC)
                    : Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upgrade.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    upgradeEffectLabel(upgrade),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF6FA8DC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
