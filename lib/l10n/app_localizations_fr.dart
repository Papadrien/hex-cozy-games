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
  String get options_vibrations => 'Vibrations';

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
  String get home_totalCoins => 'Pièces totales';

  @override
  String get tutorial_step1 =>
      'Les cases brillantes sont les endroits où tu peux poser ta tuile';

  @override
  String get tutorial_step2 =>
      'Swipe pour la faire pivoter — plusieurs rotations d’un seul geste !';

  @override
  String get tutorial_step3 =>
      'Les icônes pièce te montrent ce que tu vas gagner';

  @override
  String get tutorial_step4 => 'Tape à nouveau pour valider le placement';

  @override
  String get tutorial_step5 =>
      'Connecte les côtés identiques pour gagner des tuiles et des pièces bonus';

  @override
  String get tutorial_skip => 'Passer';

  @override
  String get quests_title => 'Quêtes';

  @override
  String get quests_category_tiles => 'Tuiles posées';

  @override
  String get quests_category_village => 'Village';

  @override
  String get quests_category_biomes => 'Biomes fermés';

  @override
  String get quests_status_active => 'En cours';

  @override
  String get quests_status_completed => 'Terminée';

  @override
  String get quests_status_locked => 'Verrouillée';

  @override
  String get quests_reward_coins => 'Récompense';

  @override
  String get quests_reward_upgrade => 'Débloque amélioration';

  @override
  String get quests_progress => 'Progression';

  @override
  String get quests_empty => 'Aucune quête disponible';

  @override
  String get quests_close => 'Fermer';

  @override
  String get quests_next_reward => 'Prochaine récompense';

  @override
  String get upgrades_title => 'Améliorations';

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
  String get shop_premium => 'Premium';

  @override
  String get shop_premiumDescription =>
      'Supprime toutes les pubs + 50 pièces/jour automatiques';

  @override
  String get shop_buy => 'Acheter';

  @override
  String get shop_alreadyPremium => 'Déjà Premium';

  @override
  String get shop_purchasePending => 'Achat en attente...';

  @override
  String get shop_purchaseError => 'Achat échoué. Veuillez réessayer.';

  @override
  String get shop_purchaseCanceled => 'Achat annulé';

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
  String get home_buildSelection => 'Sélection des améliorations';

  @override
  String get home_quests => 'Quêtes';

  @override
  String get home_stats => 'Statistiques';

  @override
  String get ads_watchForCoins => 'Regarder une pub (+50 pièces)';

  @override
  String get ads_comeBackTomorrow => 'Revenez demain';

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
  String stats_biomeMax(Object biome, Object value) {
    return '$biome max : $value tuiles';
  }
}
