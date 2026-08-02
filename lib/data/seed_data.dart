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
// (biomes entièrement entourés), `forest_cluster_size`/`water_cluster_size`/
// `plain_cluster_size`/`mountain_cluster_size` (plus grand amas de la
// couleur correspondante connecté — même principe que `village_size`).
// rewardType : `coins` ou `upgrade_unlock`.
// rewardValue : montant de pièces, ou ignoré si rewardType ==
// upgrade_unlock (le déblocage cible est porté par
// `upgrades.unlockConditionValue`, la quête sert de palier déclencheur).

/// Quête record "pièces gagnées en une seule partie".
final kBestGameCoinsQuest = PermanentQuestsCompanion.insert(
  id: 'best_game_coins_500',
  category: QuestCategory.bestGameCoins.dbValue,
  description: 'Gagner 500 pièces en une seule partie',
  targetValue: 500,
  rewardType: RewardType.coins.dbValue,
  rewardValue: 200,
);

/// Quêtes record "cluster couleur" (forêt/eau/plaine/montagne).
/// Modèle exact de "village_10" : palier unique, pas de nextQuestId,
/// récompense = déblocage d'amélioration. Réutilisent `maxBiomeSizes`
/// (déjà calculé par [BoardAnalysis]), aucune nouvelle logique de board
/// analysis.
///
/// Paliers échelonnés (et non plus un palier unique à 50 partout) pour
/// étaler la difficulté d'obtention entre les 5 couleurs : Rouge 10 → Vert
/// 15 → Bleu 20 → Jaune 25 → Violet 30. Les récompenses (déblocage d'une
/// amélioration par couleur) restent inchangées.
final kClusterColorQuests = [
  PermanentQuestsCompanion.insert(
    id: 'forest_15',
    category: QuestCategory.forestClusterSize.dbValue,
    description: 'Faire un groupe vert de 15 tuiles',
    targetValue: 15,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
  PermanentQuestsCompanion.insert(
    id: 'water_20',
    category: QuestCategory.waterClusterSize.dbValue,
    description: 'Faire un groupe bleu de 20 tuiles',
    targetValue: 20,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
  PermanentQuestsCompanion.insert(
    id: 'plain_25',
    category: QuestCategory.plainClusterSize.dbValue,
    description: 'Faire un groupe jaune de 25 tuiles',
    targetValue: 25,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
  PermanentQuestsCompanion.insert(
    id: 'mountain_30',
    category: QuestCategory.mountainClusterSize.dbValue,
    description: 'Faire un groupe violet de 30 tuiles',
    targetValue: 30,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
];

/// Extension de la chaîne "biomes_closed" (Story A6) — `biomes_50` débloque
/// Bonus de clôture, `biomes_100` débloque Couleur détestée.
final kBiomesClosedExtensionQuests = [
  PermanentQuestsCompanion.insert(
    id: 'biomes_50',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 50 zones de couleur',
    targetValue: 50,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: const Value('biomes_100'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'biomes_100',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 100 zones de couleur',
    targetValue: 100,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
];

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
    nextQuestId: const Value('coins_1000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_1000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 1000 pièces au total',
    targetValue: 1000,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: const Value('coins_2000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_2000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 2000 pièces au total',
    targetValue: 2000,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: const Value('coins_3000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_3000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 3000 pièces au total',
    targetValue: 3000,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 500,
    nextQuestId: const Value('coins_5000'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'coins_5000',
    category: QuestCategory.coinsEarned.dbValue,
    description: 'Gagner 5000 pièces au total',
    targetValue: 5000,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 1000,
  ),

  // "best_game_coins" — record du nombre de pièces gagnées en une seule
  // partie. Enregistre le meilleur score à chaque fin de partie et
  // conserve le record. Palier unique : 500 pièces débloque une
  // amélioration.
  kBestGameCoinsQuest,

  // Chaîne "village_size" — débloque Rouge+. Premier palier de la série
  // "cluster couleur" (voir [kClusterColorQuests]) : Rouge est la couleur
  // la plus facile à obtenir (10 tuiles).
  PermanentQuestsCompanion.insert(
    id: 'village_10',
    category: QuestCategory.villageSize.dbValue,
    description: 'Faire un groupe rouge de 10 tuiles',
    targetValue: 10,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),

  // Quêtes "cluster couleur" — débloquent Vert+/Bleu+/Jaune+/Violet+.
  // Extraites en constante nommée (voir [kClusterColorQuests]).
  ...kClusterColorQuests,

  // Chaîne "biomes_closed" — débloque pièces, puis Tuile bonus,
  // puis Bonus de clôture, puis Couleur détestée (Story A6).
  PermanentQuestsCompanion.insert(
    id: 'biomes_10',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 10 zones de couleur',
    targetValue: 10,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 75,
    nextQuestId: const Value('biomes_25'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'biomes_25',
    category: QuestCategory.biomesClosed.dbValue,
    description: 'Fermer 25 zones de couleur',
    targetValue: 25,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: const Value('biomes_50'),
  ),
  ...kBiomesClosedExtensionQuests,

  // Chaîne "connexions" — quêtes répétables (cumul toutes parties
  // confondues), remises à zéro instantanément après récompense, même
  // palier. Pas de nextQuestId : elles ne font pas partie d'une chaîne.
  ...kConnectionQuests,

  // Quêtes one-shot connexions (Story A8) — débloquent Aperçu prolongé /
  // Emplacement Joker / Deuxième chance (Story A9).
  ...kOneShotConnectionQuests,

  // Quêtes "record de série" (Story A10) — palier 20 débloque Combo+
  // (Story A11), paliers suivants (40/60/80/100) rapportent des pièces.
  // Alimentées par le compteur de série en session, branché en Story B2.
  ...kConnectionStreakQuests,
];

/// Quêtes record "meilleure série de connexions consécutives". Paliers
/// chaînés par `nextQuestId` (comme `biomes_closed`/`coins_earned`) : un
/// seul palier est visible à la fois — le plus bas non complété — grâce à
/// la mécanique de verrouillage de `quests_screen.dart` (`_computeStatus`).
/// La progression, elle, reste alimentée pour tous les paliers non
/// complétés à chaque nouveau record (voir `quest_provider.dart`,
/// `_updateBestConnectionStreak`), verrouillés ou non : un palier peut donc
/// se retrouver déjà complété dès son déblocage si le record le dépassait.
/// Le premier palier débloque Combo+ (Story A11), les suivants rapportent
/// 200 pièces chacun.
final kConnectionStreakQuests = [
  PermanentQuestsCompanion.insert(
    id: 'best_streak_20',
    category: QuestCategory.bestConnectionStreak.dbValue,
    description: 'Réaliser une série de 20 connexions consécutives',
    targetValue: 20,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
    nextQuestId: const Value('best_streak_40'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'best_streak_40',
    category: QuestCategory.bestConnectionStreak.dbValue,
    description: 'Réaliser une série de 40 connexions consécutives',
    targetValue: 40,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 200,
    nextQuestId: const Value('best_streak_60'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'best_streak_60',
    category: QuestCategory.bestConnectionStreak.dbValue,
    description: 'Réaliser une série de 60 connexions consécutives',
    targetValue: 60,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 200,
    nextQuestId: const Value('best_streak_80'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'best_streak_80',
    category: QuestCategory.bestConnectionStreak.dbValue,
    description: 'Réaliser une série de 80 connexions consécutives',
    targetValue: 80,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 200,
    nextQuestId: const Value('best_streak_100'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'best_streak_100',
    category: QuestCategory.bestConnectionStreak.dbValue,
    description: 'Réaliser une série de 100 connexions consécutives',
    targetValue: 100,
    rewardType: RewardType.coins.dbValue,
    rewardValue: 200,
  ),
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
    rewardValue: 50000,
    isRepeatable: const Value(true),
  ),
];

/// Quêtes one-shot de connexions multiples (Story A8) — partagent la
/// catégorie avec les quêtes répétables de farm ([kConnectionQuests]) mais
/// `isRepeatable: false` : une seule complétion débloque une amélioration,
/// puis la quête reste acquise (pas de remise à zéro). Le mécanisme de
/// progression existant (`_updateConnectionQuests`, boucle sur toutes les
/// quêtes non complétées de la catégorie) les gère sans modification.
final kOneShotConnectionQuests = [
  PermanentQuestsCompanion.insert(
    id: 'connections_triple_first',
    category: QuestCategory.tripleConnections.dbValue,
    description: 'Réaliser 15 triples connexions',
    targetValue: 15,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
  PermanentQuestsCompanion.insert(
    id: 'connections_quad_first',
    category: QuestCategory.quadConnections.dbValue,
    description: 'Réaliser 8 quadruples connexions',
    targetValue: 8,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
  ),
  PermanentQuestsCompanion.insert(
    id: 'connections_quint_first',
    category: QuestCategory.quintConnections.dbValue,
    description: 'Réaliser 5 quintuples connexions',
    targetValue: 5,
    rewardType: RewardType.upgradeUnlock.dbValue,
    rewardValue: 0,
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
  const DailyQuestDef(
    id: 'daily_coins_15',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 15 pièces',
    targetValue: 15,
    rewardType: RewardType.coins,
    rewardValue: 10,
  ),
  const DailyQuestDef(
    id: 'daily_coins_30',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 30 pièces',
    targetValue: 30,
    rewardType: RewardType.coins,
    rewardValue: 12,
  ),
  const DailyQuestDef(
    id: 'daily_coins_50',
    category: QuestCategory.coinsEarned,
    description: 'Gagner 50 pièces',
    targetValue: 50,
    rewardType: RewardType.coins,
    rewardValue: 15,
  ),
  const DailyQuestDef(
    id: 'daily_village_3',
    category: QuestCategory.villageSize,
    description: 'Faire un groupe rouge de 3 tuiles',
    targetValue: 3,
    rewardType: RewardType.coins,
    rewardValue: 8,
  ),
  const DailyQuestDef(
    id: 'daily_village_5',
    category: QuestCategory.villageSize,
    description: 'Faire un groupe rouge de 5 tuiles',
    targetValue: 5,
    rewardType: RewardType.coins,
    rewardValue: 10,
  ),
  const DailyQuestDef(
    id: 'daily_village_8',
    category: QuestCategory.villageSize,
    description: 'Faire un groupe rouge de 8 tuiles',
    targetValue: 8,
    rewardType: RewardType.coins,
    rewardValue: 12,
  ),
  const DailyQuestDef(
    id: 'daily_biomes_2',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 2 zones de couleur',
    targetValue: 2,
    rewardType: RewardType.coins,
    rewardValue: 6,
  ),
  const DailyQuestDef(
    id: 'daily_biomes_3',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 3 zones de couleur',
    targetValue: 3,
    rewardType: RewardType.coins,
    rewardValue: 8,
  ),
  const DailyQuestDef(
    id: 'daily_biomes_5',
    category: QuestCategory.biomesClosed,
    description: 'Fermer 5 zones de couleur',
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
    name: 'Cargaison',
    effectType: UpgradeEffectType.startingTilesBonus.dbValue,
    unlockConditionType: 'coins_1000',
    unlockConditionValue: 1000,
  ),
  UpgradesCompanion.insert(
    id: 'doubled_connections',
    name: 'Marée généreuse',
    effectType: UpgradeEffectType.connectionBonusMultiplier.dbValue,
    unlockConditionType: 'biomes_25',
    unlockConditionValue: 25,
  ),
  UpgradesCompanion.insert(
    id: 'coins_plus',
    name: 'Butin',
    effectType: UpgradeEffectType.coinsPercentBonus.dbValue,
    unlockConditionType: 'coins_2000',
    unlockConditionValue: 2000,
  ),
  UpgradesCompanion.insert(
    id: 'villages_plus',
    name: 'Rouge',
    effectType: UpgradeEffectType.villageCoinsPercentBonus.dbValue,
    unlockConditionType: 'village_10',
    unlockConditionValue: 10,
  ),

  // Story A5 — déblocage uniquement. L'effet réel (bonus % pièces par
  // biome) est branché en Story B1 ; les upgrades ci-dessous restent
  // verrouillées jusqu'à ce que leur quête "cluster couleur" (Story A4)
  // soit complétée.
  ...kClusterColorUpgrades,

  // Story A7 — déblocage uniquement (Bonus de clôture / Couleur
  // détestée). Effets réels branchés en Story B7 / B5.
  ...kBiomesClosedExtensionUpgrades,

  // Story A9 — déblocage uniquement (Aperçu prolongé / Emplacement Joker /
  // Deuxième chance). Effets réels branchés en Story B4 / B9-B10 / B9-B11.
  ...kExtendedActionsUpgrades,

  // Story A11 — déblocage uniquement (Combo+). Effet réel branché en
  // Story B3 (utilise le compteur de série de Story B2).
  kComboPlusUpgrade,

  // Debug uniquement — débloquées via le bouton "Tout débloquer", jamais
  // par quête (unlockConditionType: 'debug_only').
  kMillionaireUpgrade,
  kWarehouseUpgrade,
];

/// Amélioration débloquée par la quête record "best_streak_20" (série de
/// 20 connexions consécutives).
final kComboPlusUpgrade = UpgradesCompanion.insert(
  id: 'combo_plus',
  name: 'Alizés',
  effectType: UpgradeEffectType.comboBonusTiles.dbValue,
  unlockConditionType: 'best_streak_20',
  unlockConditionValue: 20,
);

/// Améliorations liées aux quêtes one-shot de connexions (Story A9) —
/// déblocage uniquement.
final kExtendedActionsUpgrades = [
  UpgradesCompanion.insert(
    id: 'extended_preview',
    name: 'Longue-vue',
    effectType: UpgradeEffectType.extendedPreviewCount.dbValue,
    unlockConditionType: 'connections_triple_first',
    unlockConditionValue: 15,
  ),
  UpgradesCompanion.insert(
    id: 'hold_slot',
    name: 'Sacoche',
    effectType: UpgradeEffectType.holdSlotUses.dbValue,
    unlockConditionType: 'connections_quad_first',
    unlockConditionValue: 8,
  ),
  UpgradesCompanion.insert(
    id: 'second_chance',
    name: 'Ressac',
    effectType: UpgradeEffectType.secondChanceUses.dbValue,
    unlockConditionType: 'connections_quint_first',
    unlockConditionValue: 5,
  ),
];

/// Améliorations "cluster couleur" (Vert+/Bleu+/Jaune+/Violet+).
final kClusterColorUpgrades = [
  UpgradesCompanion.insert(
    id: 'forest_plus',
    name: 'Vert',
    effectType: UpgradeEffectType.forestCoinsPercentBonus.dbValue,
    unlockConditionType: 'forest_15',
    unlockConditionValue: 15,
  ),
  UpgradesCompanion.insert(
    id: 'water_plus',
    name: 'Bleu',
    effectType: UpgradeEffectType.waterCoinsPercentBonus.dbValue,
    unlockConditionType: 'water_20',
    unlockConditionValue: 20,
  ),
  UpgradesCompanion.insert(
    id: 'plain_plus',
    name: 'Jaune',
    effectType: UpgradeEffectType.plainCoinsPercentBonus.dbValue,
    unlockConditionType: 'plain_25',
    unlockConditionValue: 25,
  ),
  UpgradesCompanion.insert(
    id: 'mountain_plus',
    name: 'Violet',
    effectType: UpgradeEffectType.mountainCoinsPercentBonus.dbValue,
    unlockConditionType: 'mountain_30',
    unlockConditionValue: 30,
  ),
];

/// Améliorations liées à l'extension "biomes_closed" (Story A7) —
/// déblocage uniquement.
final kBiomesClosedExtensionUpgrades = [
  UpgradesCompanion.insert(
    id: 'closure_bonus',
    name: 'Atoll',
    effectType: UpgradeEffectType.closureBonusTiles.dbValue,
    unlockConditionType: 'biomes_50',
    unlockConditionValue: 50,
  ),
  UpgradesCompanion.insert(
    id: 'hated_color',
    name: 'Exil',
    effectType: UpgradeEffectType.hatedColorExclusion.dbValue,
    unlockConditionType: 'biomes_100',
    unlockConditionValue: 100,
  ),
];

/// Millionnaire (debug) : crédite 1 000 000 pièces sur le profil.
final kMillionaireUpgrade = UpgradesCompanion.insert(
  id: 'millionaire',
  name: 'Millionnaire',
  effectType: UpgradeEffectType.millionaireCoins.dbValue,
  unlockConditionType: 'debug_only',
  unlockConditionValue: 0,
);

/// Entrepôt de tuiles (debug) : démarre une partie avec 500 tuiles.
final kWarehouseUpgrade = UpgradesCompanion.insert(
  id: 'warehouse',
  name: 'Entrepôt',
  effectType: UpgradeEffectType.warehouseStartingTiles.dbValue,
  unlockConditionType: 'debug_only',
  unlockConditionValue: 0,
);
