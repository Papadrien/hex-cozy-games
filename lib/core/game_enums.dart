/// Types d'effet d'amélioration (effectType) — remplace les chaînes magiques.
enum UpgradeEffectType {
  startingTilesBonus,
  connectionBonusMultiplier,
  coinsPercentBonus,
  villageCoinsPercentBonus;

  String get dbValue => name;
  static UpgradeEffectType fromDb(String value) =>
      UpgradeEffectType.values.firstWhere((e) => e.name == value);
}

/// Catégories de quêtes (category) — remplace les chaînes magiques.
enum QuestCategory {
  tilesPlaced,
  villageSize,
  biomesClosed;

  String get dbValue => name;
  static QuestCategory fromDb(String value) =>
      QuestCategory.values.firstWhere((e) => e.name == value);
}

/// Types de récompense (rewardType) — remplace les chaînes magiques.
enum RewardType {
  coins,
  upgradeUnlock;

  String get dbValue => name;
  static RewardType fromDb(String value) =>
      RewardType.values.firstWhere((e) => e.name == value);
}
