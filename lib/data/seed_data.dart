/// Données de seed initial — Story 2.1b.
///
/// Quêtes permanentes (chaînées par `nextQuestId`) et améliorations
/// initiales (contexte 4.1 et 5.3). Exécuté une seule fois à la création
/// de la base (onCreate), via [seedDatabase].
library;

import 'package:drift/drift.dart';

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
// Catégories : `tiles_placed` (cumul global), `village_size` (plus grand
// amas village connecté), `biomes_closed` (biomes entièrement entourés).
// rewardType : `coins` ou `upgrade_unlock`. rewardValue : montant de pièces,
// ou ignoré si rewardType == upgrade_unlock (le déblocage cible est porté
// par `upgrades.unlockConditionValue`, la quête sert de palier déclencheur).

final _permanentQuests = [
  // Chaîne "tiles_placed" — débloque pièces puis améliorations aux seuils
  // définis en 5.1 (200 → A, 300 → B...).
  PermanentQuestsCompanion.insert(
    id: 'tiles_50',
    category: 'tiles_placed',
    description: 'Poser 50 tuiles',
    targetValue: 50,
    rewardType: 'coins',
    rewardValue: 50,
    nextQuestId: Value('tiles_100'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'tiles_100',
    category: 'tiles_placed',
    description: 'Poser 100 tuiles',
    targetValue: 100,
    rewardType: 'coins',
    rewardValue: 100,
    nextQuestId: Value('tiles_200'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'tiles_200',
    category: 'tiles_placed',
    description: 'Poser 200 tuiles',
    targetValue: 200,
    rewardType: 'upgrade_unlock',
    rewardValue: 0,
    nextQuestId: Value('tiles_300'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'tiles_300',
    category: 'tiles_placed',
    description: 'Poser 300 tuiles',
    targetValue: 300,
    rewardType: 'upgrade_unlock',
    rewardValue: 0,
    nextQuestId: Value('tiles_500'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'tiles_500',
    category: 'tiles_placed',
    description: 'Poser 500 tuiles',
    targetValue: 500,
    rewardType: 'upgrade_unlock',
    rewardValue: 0,
  ),

  // Chaîne "village_size" — débloque Villages+.
  PermanentQuestsCompanion.insert(
    id: 'village_100',
    category: 'village_size',
    description: 'Faire un village de 100 maisons',
    targetValue: 100,
    rewardType: 'upgrade_unlock',
    rewardValue: 0,
  ),

  // Chaîne "biomes_closed" — débloque pièces puis Connexions doublées.
  PermanentQuestsCompanion.insert(
    id: 'biomes_10',
    category: 'biomes_closed',
    description: 'Fermer 10 biomes',
    targetValue: 10,
    rewardType: 'coins',
    rewardValue: 75,
    nextQuestId: Value('biomes_25'),
  ),
  PermanentQuestsCompanion.insert(
    id: 'biomes_25',
    category: 'biomes_closed',
    description: 'Fermer 25 biomes',
    targetValue: 25,
    rewardType: 'upgrade_unlock',
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
  final String category;
  final String description;
  final int targetValue;
  final String rewardType;
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
    id: 'daily_tiles_10',
    category: 'tiles_placed',
    description: 'Poser 10 tuiles',
    targetValue: 10,
    rewardType: 'coins',
    rewardValue: 10,
  ),
  DailyQuestDef(
    id: 'daily_tiles_20',
    category: 'tiles_placed',
    description: 'Poser 20 tuiles',
    targetValue: 20,
    rewardType: 'coins',
    rewardValue: 12,
  ),
  DailyQuestDef(
    id: 'daily_tiles_30',
    category: 'tiles_placed',
    description: 'Poser 30 tuiles',
    targetValue: 30,
    rewardType: 'coins',
    rewardValue: 15,
  ),
  DailyQuestDef(
    id: 'daily_village_3',
    category: 'village_size',
    description: 'Faire un village de 3 maisons',
    targetValue: 3,
    rewardType: 'coins',
    rewardValue: 8,
  ),
  DailyQuestDef(
    id: 'daily_village_5',
    category: 'village_size',
    description: 'Faire un village de 5 maisons',
    targetValue: 5,
    rewardType: 'coins',
    rewardValue: 10,
  ),
  DailyQuestDef(
    id: 'daily_village_8',
    category: 'village_size',
    description: 'Faire un village de 8 maisons',
    targetValue: 8,
    rewardType: 'coins',
    rewardValue: 12,
  ),
  DailyQuestDef(
    id: 'daily_biomes_2',
    category: 'biomes_closed',
    description: 'Fermer 2 biomes',
    targetValue: 2,
    rewardType: 'coins',
    rewardValue: 6,
  ),
  DailyQuestDef(
    id: 'daily_biomes_3',
    category: 'biomes_closed',
    description: 'Fermer 3 biomes',
    targetValue: 3,
    rewardType: 'coins',
    rewardValue: 8,
  ),
  DailyQuestDef(
    id: 'daily_biomes_5',
    category: 'biomes_closed',
    description: 'Fermer 5 biomes',
    targetValue: 5,
    rewardType: 'coins',
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
    effectType: 'starting_tiles_bonus', // niveaux : +2 / +5 / +10
    unlockConditionType: 'tiles_200',
    unlockConditionValue: 200,
  ),
  UpgradesCompanion.insert(
    id: 'doubled_connections',
    name: 'Connexions doublées',
    effectType: 'connection_bonus_multiplier', // x2 sur seuil 3/4/5 côtés
    unlockConditionType: 'biomes_25',
    unlockConditionValue: 25,
  ),
  UpgradesCompanion.insert(
    id: 'coins_plus',
    name: 'Pièces+',
    effectType: 'coins_percent_bonus', // niveaux : +X% / +Y% / +Z%
    unlockConditionType: 'tiles_300',
    unlockConditionValue: 300,
  ),
  UpgradesCompanion.insert(
    id: 'villages_plus',
    name: 'Villages+',
    effectType: 'village_coins_percent_bonus', // niveaux : +33% / +66% / +100%
    unlockConditionType: 'village_100',
    unlockConditionValue: 100,
  ),
];
