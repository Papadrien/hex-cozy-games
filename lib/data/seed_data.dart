/// Données de seed initial — Story 2.1b.
///
/// Quêtes permanentes (chaînées par `nextQuestId`) et améliorations
/// initiales (contexte 4.1 et 5.3). Exécuté une seule fois à la création
/// de la base (onCreate), via [seedDatabase].
library;

import 'package:drift/drift.dart';

import '../core/game_enums.dart';
import 'app_database.dart';

/// Insère les données initiales si les tables sont vides.
/// Idempotent : ne ré-insère rien si déjà seedé (évite les doublons en cas
/// de double appel).
Future<void> seedDatabase(AppDatabase db) async {
  final hasQuests = await (db.select(db.permanentQuests)..limit(1)).get();
  if (hasQuests.isEmpty) {
    await db.batch((b) => b.insertAll(db.permanentQuests, _permanentQuests));
  }

  final hasUpgrades = await (db.select(db.upgrades)..limit(1)).get();
  if (hasUpgrades.isEmpty) {
    await db.batch((b) => b.insertAll(db.upgrades, _upgrades));
  }
}

// ── Quêtes permanentes ───────────────────────────────────────────────────
//
// Catégories : `coins_earned` (cumul global de pièces gagnées),
// `best_game_coins` (record de pièces gagnées en une seule partie),
// `village_size` (plus grand amas village connecté), `biomes_closed`
// (biomes entièrement entourés). rewardType : `coins` ou `upgrade_unlock`.
// rewardValue : montant de pièces, ou ignoré si rewardType ==
// upgrade_unlock (le déblocage cible est porté par
// `upgrades.unlockConditionValue`, la quête sert de palier déclencheur).

/// Quête record "pièces gagnées en une seule partie" — extraite en
/// constante nommée pour être réutilisable depuis la migration de schéma
/// (voir [AppDatabase.migration], version 6).
final kBestGameCoinsQuest = PermanentQuestsCompanion.insert(
  id: 'best_game_coins_500',
  category: QuestCategory.bestGameCoins.dbValue,
  description: 'Gagner 500 pièces en une seule partie',
  targetValue: 500,
  rewardType: RewardType.upgradeUnlock.dbValue,
  rewardValue: 0,
);

final _permanentQuests = [
  // Chaîne "coins_earned" — cumul de pièces gagnées toutes parties
  // confondues. Débloque pièces puis améliorations aux seuils définis en
  // 5.1 (2000 → A, 3000 → B...).
  PermanentQuestsCompanion.insert(
    id: 'coins_500',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 500 pièces au total',
    targetValue: 500,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 50,
    nextQuestId: Value('coins_1000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_1000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 1000 pièces au total',
    targetValue: 1000,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 100,
    nextQuestId: Value('coins_2000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_2000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 2000 pièces au total',
    targetValue: 2000,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: Value('coins_3000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_3000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 3000 pièces au total',
    targetValue: 3000,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: Value('coins_5000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_5000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 5000 pièces au total',
    targetValue: 5000,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),

  // "best_game_coins" — record du nombre de pièces gagnées en une seule
  // partie. Enregistre le meilleur score à chaque fin de partie et
  // conserve le record. Palier unique : 500 pièces débloque une
  // amélioration.
  kBestGameCoinsQuest,

  // Chaîne "village_size" — débloque Villages+.
  PermanentQuestsCompanion.insert(
    id: 'village_100',
    category: QuestCategory.villageSize.dbValue,
    description: 'Faire un groupe rouge de plus de 50 tuiles',
    targetValue: 51,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),

  // Chaîne "biomes_closed" — débloque pièces puis Connexions doublées.
  PermanentQuestsCompanion.insert(
    id: 'biomes_10',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 10 biomes',
    targetValue: 10,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 75,
    nextQuestId: Value('biomes_25'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'biomes_25',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 25 biomes',
    targetValue: 25,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),

  // Chaîne "connexions" — quêtes répétables (cumul toutes parties
  // confondues), remises à zéro instantanément après récompense, même
  // palier. Pas de nextQuestId : elles ne font pas partie d'une chaîne.
  ...kConnectionQuests,
];

/// Quêtes répétables de connexions multiples. Chaque quête cumule le nombre
/// de fois où une tuile posée obtient exactement N côtés connectés (toutes
/// parties confondues). Dès le palier atteint : récompense accordée puis
/// remise à zéro immédiate de `currentValue`, avec le même `targetValue`.
final kConnectionQuests = [
  PermanentQuestsCompanion.insert(
    id: 'connections_triple',
    category: QuestCategory.tripleConnections.dbValue,
    description: 'Triple connexion réalisée',
    targetValue: 100,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 500,
    isRepeatable: const Value(true),
  ),
  PermanentQuestsCompanion.insert(
    id: 'connections_quad',
    category: QuestCategory.quadConnections.dbValue,
    description: 'Quadruple connexion réalisée',
    targetValue: 50,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 500,
    isRepeatable: const Value(true),
  ),
  PermanentQuestsCompanion.insert(
    id: 'connections_quint',
    category: QuestCategory.quintConnections.dbValue,
    description: 'Quintuple connexion réalisée',
    targetValue: 20,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 500,
    isRepeatable: const Value(true),
  ),
  PermanentQuestsCompanion.insert(
    id: 'connections_sext',
    category: QuestCategory.sextConnections.dbValue,
    description: 'Sextuple connexion réalisée',
    targetValue: 10,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 500,
    isRepeatable: const Value(true),
  ),
];

// ── Améliorations ────────────────────────────────────────────────────────
//
// effectType identifie la logique appliquée par le moteur de jeu.
// unlockConditionType : `permanent_quest` — unlockConditionValue ignoré,
// le déblocage réel est piloté par l'achèvement de la quête liée (voir
// mapping ci-dessous, par cohérence de nommage avec id de quête).

// ── Quêtes quotidiennes (pool de tirage) ────────────────────────────────
//
// Variantes des quêtes permanentes, valeurs plus petites.
// 3 quêtes tirées aléatoirement chaque jour dans ce pool.

/// Définition d'une quête quotidienne (variante d'une quête permanente).
class DailyQuestDef {
  final String id;
  final QuestCategory category;
  final String description;
  final int targetValue;
  final RewardType rewardType;
  final int rewardValue;

  const DailyQuestDef({
    required this.id,
    required this.category,
    required this.description,
    required this.targetValue,
    required this.rewardType,
    required this.rewardValue,
  });
}

/// Pool de toutes les quêtes quotidiennes disponibles.
/// Le tirage quotidien en sélectionne 3 via un seed reproductible.
final kDailyQuestPool = [
  DailyQuestDef(
    id: 'daily_coins_15',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 15 pièces',
    targetValue: 15,
    rewardType: RewardType.coins,
    rewardValue: 10,
  ),
  DailyQuestDef(
    id: 'daily_coins_30',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 30 pièces',
    targetValue: 30,
    rewardType: RewardType.coins,
    rewardValue: 12,
  ),
  DailyQuestDef(
    id: 'daily_coins_50',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 50 pièces',
    targetValue: 50,
    rewardType: RewardType.coins,
    rewardValue: 15,
  ),
  DailyQuestDef(
    id: 'daily_village_3',
    category: QuestCategory.villageSize,
    description: 'Faire un village de 3 maisons',
    targetValue: 3,
    rewardType: RewardType.coins,
    rewardValue: 8,
  ),
  DailyQuestDef(
    id: 'daily_village_5',
    category: QuestCategory.villageSize,
    description: 'Faire un village de 5 maisons',
    targetValue: 5,
    rewardType: RewardType.coins,
    rewardValue: 10,
  ),
  DailyQuestDef(
    id: 'daily_village_8',
    category: QuestCategory.villageSize,
    description: 'Faire un village de 8 maisons',
    targetValue: 8,
    rewardType: RewardType.coins,
    rewardValue: 12,
  ),
  DailyQuestDef(
    id: 'daily_biomes_2',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 2 biomes',
    targetValue: 2,
    rewardType: RewardType.coins,
    rewardValue: 6,
  ),
  DailyQuestDef(
    id: 'daily_biomes_3',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 3 biomes',
    targetValue: 3,
    rewardType: RewardType.coins,
    rewardValue: 8,
  ),
  DailyQuestDef(
    id: 'daily_biomes_5',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 5 biomes',
    targetValue: 5,
    rewardType: RewardType.coins,
    rewardValue: 10,
  ),
];

/// Lookup map id → DailyQuestDef pour un accès rapide.
final Map<String, DailyQuestDef> kDailyQuestDefMap = {
  for (final def in kDailyQuestPool) def.id: def,
};

final _upgrades = [
  UpgradesCompanion.insert(
    id: 'starting_tiles_plus',
    name: 'Tuiles de départ+',
    effectType: UpgradeEffectType.startingTilesBonus.dbValue,
    unlockConditionType: 'coins_2000',
    unlockConditionValue: 2000,
  ),
  UpgradesCompanion.insert(
    id: 'doubled_connections',
    name: 'Connexions doublées',
    effectType: UpgradeEffectType.connectionBonusMultiplier.dbValue,
    unlockConditionType: 'biomes_25',
    unlockConditionValue: 25,
  ),
  UpgradesCompanion.insert(
    id: 'coins_plus',
    name: 'Pièces+',
    effectType: UpgradeEffectType.coinsPercentBonus.dbValue,
    unlockConditionType: 'coins_3000',
    unlockConditionValue: 3000,
  ),
  UpgradesCompanion.insert(
    id: 'villages_plus',
    name: 'Villages+',
    effectType: UpgradeEffectType.villageCoinsPercentBonus.dbValue,
    unlockConditionType: 'village_100',
    unlockConditionValue: 100,
  ),
  kJackpotPlusUpgrade,
];

/// Amélioration débloquée par la quête record "best_game_coins_500" (500
/// pièces gagnées en une seule partie) — extraite en constante nommée
/// pour être réutilisable depuis la migration de schéma (voir
/// [AppDatabase.migration], version 6).
final kJackpotPlusUpgrade = UpgradesCompanion.insert(
  id: 'jackpot_plus',
  name: 'Jackpot+',
  effectType: UpgradeEffectType.coinsPercentBonus.dbValue,
  unlockConditionType: 'best_game_coins_500',
  unlockConditionValue: 500,
);
