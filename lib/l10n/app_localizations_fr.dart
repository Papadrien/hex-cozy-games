// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get pause_resume => 'Reprendre';

  @override
  String get pause_options => 'Options';

  @override
  String get options_sound => 'Son';

  @override
  String get options_music => 'Musique';

  @override
  String get options_sfx => 'Bruitages';

  @override
  String get options_musicVolume => 'Volume musique';

  @override
  String get options_sfxVolume => 'Volume bruitages';

  @override
  String get options_vibrations => 'Vibrations';

  @override
  String get options_immersiveMode => 'Mode immersif';

  @override
  String get settings_sectionGeneral => 'Général';

  @override
  String get pause_saveAndQuit => 'Sauvegarder et quitter';

  @override
  String get pause_abandon => 'Abandonner';

  @override
  String get pause_abandonConfirmTitle =>
      'Es-tu sûr de vouloir abandonner cette partie ?';

  @override
  String get pause_abandonConfirmBody =>
      'Tes pièces gagnées durant cette partie seront perdues.';

  @override
  String get pause_abandonConfirmCancel => 'Annuler';

  @override
  String get pause_abandonConfirmConfirm => 'Abandonner';

  @override
  String get home_play => 'Jouer';

  @override
  String get home_resume => 'Reprendre';

  @override
  String get reward_coins => ' bonus';

  @override
  String get reward_bonusTiles => ' tuiles bonus';

  @override
  String get results_title => 'Partie terminée !';

  @override
  String get results_tilesPlaced => 'Tuiles posées';

  @override
  String get results_connections => 'Connexions';

  @override
  String get results_coins => 'Pièces gagnées';

  @override
  String get results_connections3 => '3 côtés';

  @override
  String get results_connections4 => '4 côtés';

  @override
  String get results_connections5 => '5 côtés';

  @override
  String get results_connections6 => '6 côtés';

  @override
  String get results_replay => 'Rejouer';

  @override
  String get results_home => 'Accueil';

  @override
  String get game_sessionCoins => 'Pièces de la partie';

  @override
  String get game_undo_semanticLabel => 'Annuler la dernière pose de tuile';

  @override
  String get game_holdSlot_tooltip =>
      'Emplacement Joker : échanger avec la tuile active';

  @override
  String get game_secondChance_tooltip =>
      'Deuxième chance : reprendre une tuile posée';

  @override
  String get game_secondChance_tooltipActive =>
      'Touchez une tuile posée pour la reprendre';

  @override
  String get home_totalCoins => 'Pièces totales';

  @override
  String get tutorial_step1 =>
      'Les cases brillantes sont les endroits où tu peux poser ta tuile';

  @override
  String get tutorial_step2 => 'Swipe pour la faire pivoter';

  @override
  String get tutorial_step3 =>
      'Les icônes pièce te montrent ce que tu vas gagner';

  @override
  String get tutorial_step4 =>
      'Tape n\'importe où sur l\'écran pour valider le placement';

  @override
  String get tutorial_step5 =>
      'La croix sur la pile retire la prévisualisation.';

  @override
  String get tutorial_step6 =>
      'Utilise le bouton Annuler pour annuler la dernière tuile posée.';

  @override
  String get tutorial_step7 =>
      'Connecte des côtés identiques pour gagner des tuiles et des pièces bonus';

  @override
  String get tutorial_skip => 'Passer';

  @override
  String get quests_title => 'Quêtes';

  @override
  String get quests_category_coins => 'Pièces gagnées';

  @override
  String get quests_category_record => 'Record de pièces';

  @override
  String get quests_category_village => 'Rouge';

  @override
  String get quests_category_biomes => 'Zones de couleur fermées';

  @override
  String get quests_category_connections => 'Connexions multiples';

  @override
  String get quests_category_biome_colors => 'Groupes de couleur';

  @override
  String get quests_category_streak => 'Série de connexions';

  @override
  String get quests_category_daily => 'Quêtes quotidiennes';

  @override
  String get quests_status_active => 'En cours';

  @override
  String get quests_status_completed => 'Terminée';

  @override
  String get quests_status_locked => 'Verrouillée';

  @override
  String get quests_tap_to_claim => 'Toucher pour récupérer';

  @override
  String get quests_reward_coins => 'Récompense';

  @override
  String get quests_reward_upgrade => 'Débloque power-up';

  @override
  String get quests_progress => 'Progression';

  @override
  String get quests_empty => 'Aucune quête disponible';

  @override
  String get quests_close => 'Fermer';

  @override
  String get quests_next_reward => 'Prochaine récompense';

  @override
  String quest_desc_best_game_coins(Object value) {
    return 'Gagner $value pièces en une seule partie';
  }

  @override
  String quest_desc_cluster_forest(Object value) {
    return 'Faire un groupe vert de $value tuiles';
  }

  @override
  String quest_desc_cluster_water(Object value) {
    return 'Faire un groupe bleu de $value tuiles';
  }

  @override
  String quest_desc_cluster_plain(Object value) {
    return 'Faire un groupe jaune de $value tuiles';
  }

  @override
  String quest_desc_cluster_mountain(Object value) {
    return 'Faire un groupe violet de $value tuiles';
  }

  @override
  String quest_desc_cluster_village(Object value) {
    return 'Faire un groupe rouge de $value tuiles';
  }

  @override
  String quest_desc_biomes_closed(Object value) {
    return 'Fermer $value zones de couleur';
  }

  @override
  String quest_desc_coins_total(Object value) {
    return 'Gagner $value pièces au total';
  }

  @override
  String quest_desc_coins_simple(Object value) {
    return 'Gagner $value pièces';
  }

  @override
  String quest_desc_streak(Object value) {
    return 'Réaliser une série de $value connexions consécutives';
  }

  @override
  String get quest_desc_triple_connection => 'Triple connexion réalisée';

  @override
  String get quest_desc_quad_connection => 'Quadruple connexion réalisée';

  @override
  String get quest_desc_quint_connection => 'Quintuple connexion réalisée';

  @override
  String get quest_desc_sext_connection => 'Sextuple connexion réalisée';

  @override
  String quest_desc_triple_connections_count(Object value) {
    return 'Réaliser $value triples connexions';
  }

  @override
  String quest_desc_quad_connections_count(Object value) {
    return 'Réaliser $value quadruples connexions';
  }

  @override
  String quest_desc_quint_connections_count(Object value) {
    return 'Réaliser $value quintuples connexions';
  }

  @override
  String get upgrades_title => 'Power-ups';

  @override
  String get upgrades_locked => 'Verrouillée';

  @override
  String get upgrades_hiddenEffect => '???';

  @override
  String get upgrades_unlockCondition => 'Condition de déblocage';

  @override
  String get upgrades_upgradeButton => 'Améliorer';

  @override
  String get upgrades_level => 'Niveau';

  @override
  String get upgrades_cost => 'Coût';

  @override
  String get upgrades_max => 'MAX';

  @override
  String get upgrades_noneUnlocked => 'Aucun power-up débloqué pour l\'instant';

  @override
  String get upgrades_confirmButton => 'Confirmer ?';

  @override
  String get upgrade_desc_starting_tiles_plus =>
      'Augmente le nombre de tuiles dans la pile de tuiles au début de chaque partie.';

  @override
  String get upgrade_desc_doubled_connections =>
      'Augmente le nombre de tuiles bonus obtenues sur les connexions quintuple et sextuple.';

  @override
  String get upgrade_desc_coins_plus =>
      'Octroie une pièce bonus dès que tu gagnes au moins N pièces sur une pose.';

  @override
  String get upgrade_desc_villages_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés rouges sur une pose.';

  @override
  String get upgrade_desc_combo_plus =>
      'Ajoute une tuile bonus tous les N doubles connexions cumulées sur la partie.';

  @override
  String get upgrade_desc_extended_preview =>
      'Affiche plus de tuiles à venir dans la pile, pour mieux anticiper tes placements.';

  @override
  String get upgrade_desc_hold_slot =>
      'Permet de stocker une tuile et de la remettre plus tard dans la pile de tuiles.';

  @override
  String get upgrade_desc_second_chance =>
      'Permet de retirer une tuile déjà posée.';

  @override
  String get upgrade_desc_forest_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés verts sur une pose.';

  @override
  String get upgrade_desc_water_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés bleus sur une pose.';

  @override
  String get upgrade_desc_plain_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés jaunes sur une pose.';

  @override
  String get upgrade_desc_mountain_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés violets sur une pose.';

  @override
  String get upgrade_desc_closure_bonus =>
      'Offre des tuiles bonus à chaque fermeture complète d\'une zone de couleur.';

  @override
  String get upgrade_desc_hated_color =>
      'Tape sur ce power-up en cours de partie pour choisir une couleur à exclure temporairement de la pile de tuiles, un nombre limité de fois par partie.';

  @override
  String get upgrade_hated_color_picker_title => 'Choisis la couleur à exclure';

  @override
  String get upgrade_desc_millionaire =>
      'Crédite instantanément 1 000 000 de pièces sur ton profil (outil de développement).';

  @override
  String get upgrade_desc_warehouse =>
      'Démarre une partie avec 500 tuiles en réserve (outil de développement).';

  @override
  String get upgrade_name_starting_tiles_plus => 'Cargaison';

  @override
  String get upgrade_name_doubled_connections => 'Marée généreuse';

  @override
  String get upgrade_name_coins_plus => 'Butin';

  @override
  String get upgrade_name_villages_plus => 'Rouge';

  @override
  String get upgrade_name_combo_plus => 'Alizés';

  @override
  String get upgrade_name_extended_preview => 'Longue-vue';

  @override
  String get upgrade_name_hold_slot => 'Sacoche';

  @override
  String get upgrade_name_second_chance => 'Ressac';

  @override
  String get upgrade_name_forest_plus => 'Vert';

  @override
  String get upgrade_name_water_plus => 'Bleu';

  @override
  String get upgrade_name_plain_plus => 'Jaune';

  @override
  String get upgrade_name_mountain_plus => 'Violet';

  @override
  String get upgrade_name_closure_bonus => 'Atoll';

  @override
  String get upgrade_name_hated_color => 'Exil';

  @override
  String get upgrade_name_millionaire => 'Millionnaire';

  @override
  String get upgrade_name_warehouse => 'Entrepôt';

  @override
  String get upgrade_effect_startingTilesBonus_0 => '+2 tuiles de départ';

  @override
  String get upgrade_effect_startingTilesBonus_1 => '+5 tuiles de départ';

  @override
  String get upgrade_effect_startingTilesBonus_2 => '+10 tuiles de départ';

  @override
  String get upgrade_effect_connectionBonusMultiplier_0 =>
      '+1 tuile bonus (connexion 5-6)';

  @override
  String get upgrade_effect_connectionBonusMultiplier_1 =>
      '+2 tuiles bonus (connexion 5-6)';

  @override
  String get upgrade_effect_connectionBonusMultiplier_2 =>
      '+5 tuiles bonus (connexion 5-6)';

  @override
  String get upgrade_effect_coinsPercentBonus_0 =>
      '+1 pièce par tranche de 8 pièces';

  @override
  String get upgrade_effect_coinsPercentBonus_1 =>
      '+1 pièce par tranche de 4 pièces';

  @override
  String get upgrade_effect_coinsPercentBonus_2 =>
      '+1 pièce par tranche de 2 pièces';

  @override
  String get upgrade_effect_biomeCoinsBonus_0 =>
      '+1 pièce par tranche de 4 côtés';

  @override
  String get upgrade_effect_biomeCoinsBonus_1 =>
      '+1 pièce par tranche de 2 côtés';

  @override
  String get upgrade_effect_biomeCoinsBonus_2 => '+1 pièce par côté';

  @override
  String get upgrade_effect_closureBonusTiles_0 =>
      '+1 tuile bonus / 8 tuiles de la zone';

  @override
  String get upgrade_effect_closureBonusTiles_1 =>
      '+2 tuiles bonus / 8 tuiles de la zone';

  @override
  String get upgrade_effect_closureBonusTiles_2 =>
      '+3 tuiles bonus / 8 tuiles de la zone';

  @override
  String get upgrade_effect_hatedColorExclusion_0 =>
      'Exclut une couleur (5 tuiles), 1 usage';

  @override
  String get upgrade_effect_hatedColorExclusion_1 =>
      'Exclut une couleur (8 tuiles), 2 usages';

  @override
  String get upgrade_effect_hatedColorExclusion_2 =>
      'Exclut une couleur (10 tuiles), 3 usages';

  @override
  String get upgrade_effect_extendedPreviewCount_0 => 'Voir 4 tuiles à venir';

  @override
  String get upgrade_effect_extendedPreviewCount_1 => 'Voir 5 tuiles à venir';

  @override
  String get upgrade_effect_extendedPreviewCount_2 => 'Voir 6 tuiles à venir';

  @override
  String get upgrade_effect_holdSlotUses_0 => 'Stocke une tuile, 1 usage';

  @override
  String get upgrade_effect_holdSlotUses_1 => 'Stocke une tuile, 2 usages';

  @override
  String get upgrade_effect_holdSlotUses_2 => 'Stocke une tuile, 3 usages';

  @override
  String get upgrade_effect_secondChanceUses_0 =>
      'Retire une tuile posée, 1 usage';

  @override
  String get upgrade_effect_secondChanceUses_1 =>
      'Retire une tuile posée, 2 usages';

  @override
  String get upgrade_effect_secondChanceUses_2 =>
      'Retire une tuile posée, 3 usages';

  @override
  String get upgrade_effect_comboBonusTiles_0 =>
      'Tuile bonus toutes les 10 doubles connexions';

  @override
  String get upgrade_effect_comboBonusTiles_1 =>
      'Tuile bonus toutes les 8 doubles connexions';

  @override
  String get upgrade_effect_comboBonusTiles_2 =>
      'Tuile bonus toutes les 5 doubles connexions';

  @override
  String get upgrade_effect_millionaireCoins_0 => '+1 000 000 pièces';

  @override
  String get upgrade_effect_warehouseStartingTiles_0 => '+500 tuiles de départ';

  @override
  String get shop_title => 'Boutique';

  @override
  String get shop_coinPacks => 'Packs de pièces';

  @override
  String get shop_comingSoon => 'Bientôt disponible';

  @override
  String shop_coinCount(Object count) {
    return '$count pièces';
  }

  @override
  String get shop_bestValueBadge => 'Meilleur rapport';

  @override
  String get shop_adRemovalIncludedBadge => 'Premium inclus';

  @override
  String get shop_premium => 'Premium';

  @override
  String get shop_premiumDescription =>
      'Supprime toutes les pubs + 100 pièces/jour automatiques';

  @override
  String get shop_buy => 'Acheter';

  @override
  String shop_buyForPrice(Object price) {
    return 'Acheter — $price';
  }

  @override
  String get shop_alreadyPremium => 'Déjà Premium';

  @override
  String get shop_purchasePending => 'Achat en attente...';

  @override
  String get shop_purchaseError => 'Achat échoué. Veuillez réessayer.';

  @override
  String get shop_purchaseCanceled => 'Achat annulé';

  @override
  String get shop_purchaseSuccessCoinsTitle => 'Achat réussi !';

  @override
  String get shop_purchaseSuccessCoinsSubtitle => 'ajoutées à ton solde';

  @override
  String get shop_purchaseSuccessPremiumTitle => 'Premium débloqué !';

  @override
  String get shop_purchaseSuccessContinue => 'Continuer';

  @override
  String get shop_restorePurchases => 'Restaurer les achats';

  @override
  String get shop_restoreCompleted => 'Achats restaurés';

  @override
  String get shop_restoreError => 'Impossible de restaurer les achats';

  @override
  String get home_settings => 'Réglages';

  @override
  String get home_shop => 'Boutique';

  @override
  String get home_buildSelection => 'Power-ups';

  @override
  String get home_buildSelectionLockedResume =>
      'Termine ou abandonne ta partie en cours avant de choisir de nouveaux power-ups.';

  @override
  String get home_quests => 'Quêtes';

  @override
  String get home_stats => 'Statistiques';

  @override
  String get ads_watchForCoins => 'Regarder une pub (+100 pièces)';

  @override
  String get ads_comeBackTomorrow => 'Revenez demain';

  @override
  String get ads_loading => 'Chargement…';

  @override
  String get premium_dailyCoinsButton => 'Vos pièces quotidiennes';

  @override
  String get stats_title => 'Statistiques';

  @override
  String get stats_totalTiles => 'Tuiles totales placées';

  @override
  String get stats_bestScore => 'Meilleur score';

  @override
  String get stats_gamesPlayed => 'Parties jouées';

  @override
  String get stats_totalCoins => 'Pièces totales gagnées';

  @override
  String get stats_colorGroups => 'GROUPES DE COULEUR';

  @override
  String get stats_error => 'Erreur';

  @override
  String get stats_noData => 'Aucune donnée';

  @override
  String stats_biomeMax(Object value) {
    return 'Max : $value tuiles';
  }

  @override
  String get settings_title => 'Réglages';

  @override
  String get settings_sectionAudio => 'Audio';

  @override
  String get settings_sectionAbout => 'À propos';

  @override
  String get settings_rateApp => 'Laisser un avis';

  @override
  String get settings_rateAppSubtitle => 'Donne ton avis sur le Store';

  @override
  String get review_title => 'Tu aimes HexHaven ?';

  @override
  String get review_body =>
      'Un avis nous aide énormément à faire grandir le jeu et à le faire découvrir à d\'autres joueurs !';

  @override
  String get review_rateNow => 'Laisser un avis';

  @override
  String get review_later => 'Plus tard';
}
