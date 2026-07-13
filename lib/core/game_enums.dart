/// Types d'effet d'amélioration (effectType) — remplace les chaînes magiques.
enum UpgradeEffectType {
  startingTilesBonus,
  connectionBonusMultiplier,
  coinsPercentBonus,
  villageCoinsPercentBonus,

  /// Bonus % pièces forêt (Vert+) — déblocage en Story A5, effet réel
  /// (application au calcul des pièces) branché en Story B1.
  forestCoinsPercentBonus,

  /// Bonus % pièces eau (Bleu+) — déblocage en Story A5, effet réel
  /// branché en Story B1.
  waterCoinsPercentBonus,

  /// Bonus % pièces plaine (Jaune+) — déblocage en Story A5, effet réel
  /// branché en Story B1.
  plainCoinsPercentBonus,

  /// Bonus % pièces montagne (Violet+) — déblocage en Story A5, effet réel
  /// branché en Story B1.
  mountainCoinsPercentBonus,

  /// Bonus tuiles à la fermeture d'un biome (Bonus de clôture) —
  /// déblocage en Story A7, effet réel (calcul sur taille du biome fermé)
  /// branché en Story B7.
  closureBonusTiles,

  /// Exclusion temporaire d'une couleur aléatoire de la pile (Couleur
  /// détestée) — déblocage en Story A7, effet réel branché en Story B5.
  hatedColorExclusion,

  /// Nombre de tuiles visibles dans la file d'attente (Aperçu prolongé) —
  /// déblocage en Story A9, effet réel (HUD `tile_stack_hud.dart`) branché
  /// en Story B4.
  extendedPreviewCount,

  /// Nombre d'utilisations par partie de l'échange tuile active ↔ tuile en
  /// réserve (Emplacement Joker / Hold) — déblocage en Story A9, effet
  /// réel branché en Story B9/B10.
  holdSlotUses,

  /// Nombre d'utilisations par partie du retrait d'une tuile posée
  /// (Deuxième chance) — déblocage en Story A9, effet réel branché en
  /// Story B9/B11.
  secondChanceUses,

  /// Tuile bonus ajoutée tous les N crans de la série de doubles
  /// connexions (exactement 2 côtés connectés) d'affilée (Combo+) — N
  /// dépend du niveau (15/13/10 aux niveaux 1/2/3). Déblocage en
  /// Story A11, effet réel branché en Story B3.
  comboBonusTiles,

  /// Millionnaire (debug) : crédite 1 000 000 pièces sur le profil.
  millionaireCoins,

  /// Entrepôt de tuiles (debug) : démarre une partie avec 500 tuiles.
  warehouseStartingTiles;

  String get dbValue => name;
  static UpgradeEffectType fromDb(String value) =>
      UpgradeEffectType.values.firstWhere((e) => e.name == value);
}

/// Catégories de quêtes (category) — remplace les chaînes magiques.
enum QuestCategory {
  /// Cumul (toutes parties confondues) de pièces gagnées.
  coinsEarned,

  /// Meilleur score (pièces gagnées) atteint en une seule partie.
  bestGameCoins,
  villageSize,
  biomesClosed,
  tripleConnections,
  quadConnections,
  quintConnections,
  sextConnections,

  /// Plus grand amas forêt (vert) connecté — débloque Vert+ (Story A4/A5).
  forestClusterSize,

  /// Plus grand amas eau (bleu) connecté — débloque Bleu+ (Story A4/A5).
  waterClusterSize,

  /// Plus grand amas plaine (jaune) connecté — débloque Jaune+ (Story A4/A5).
  plainClusterSize,

  /// Plus grand amas montagne (violet) connecté — débloque Violet+
  /// (Story A4/A5).
  mountainClusterSize,

  /// Record de la plus longue série de connexions consécutives (poses
  /// ayant connecté ≥1 côté sans interruption), toutes parties confondues
  /// — débloque Combo+ (Story A10/A11). Mécanisme de comptage en session
  /// branché en Story B2.
  bestConnectionStreak;

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
