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
  String get upgrades_noneUnlocked =>
      'Aucune amélioration débloquée pour l\'instant';

  @override
  String get upgrades_confirmButton => 'Confirmer ?';

  @override
  String get upgrade_desc_starting_tiles_plus =>
      'Augmente le nombre de tuiles en main au début de chaque partie.';

  @override
  String get upgrade_desc_doubled_connections =>
      'Augmente le nombre de tuiles bonus obtenues sur les connexions quintuple et sextuple.';

  @override
  String get upgrade_desc_coins_plus =>
      'Octroie une pièce bonus dès que tu gagnes au moins N pièces sur une pose (4/2/1 pièces selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_villages_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés rouges sur une pose (4/2/1 selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_combo_plus =>
      'Ajoute une tuile bonus tous les N doubles connexions cumulées sur la partie (10/8/5 selon le niveau).';

  @override
  String get upgrade_desc_extended_preview =>
      'Affiche plus de tuiles à venir dans la pile, pour mieux anticiper tes placements.';

  @override
  String get upgrade_desc_hold_slot =>
      'Permet d\'échanger la tuile active avec une tuile en réserve, un nombre limité de fois par partie.';

  @override
  String get upgrade_desc_second_chance =>
      'Permet de retirer une tuile déjà posée, un nombre limité de fois par partie.';

  @override
  String get upgrade_desc_forest_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés verts sur une pose (4/2/1 selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_water_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés bleus sur une pose (4/2/1 selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_plain_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés jaunes sur une pose (4/2/1 selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_mountain_plus =>
      'Octroie une pièce bonus dès que tu connectes au moins N côtés violets sur une pose (4/2/1 selon le niveau). Non-cumulable.';

  @override
  String get upgrade_desc_closure_bonus =>
      'Offre des tuiles bonus à chaque fermeture complète d\'une zone de couleur.';

  @override
  String get upgrade_desc_hated_color =>
      'Tape sur cette amélioration en cours de partie pour exclure temporairement une couleur aléatoire (parmi les couleurs de base) de la pile de tuiles. Usage unique par partie.';

  @override
  String get upgrade_desc_jackpot_plus =>
      'Booste encore le bonus de pièces : octroie une pièce bonus dès que tu gagnes au moins N pièces sur une pose (4/2/1 selon le niveau). Non-cumulable — débloqué en récompense d\'une partie exceptionnelle.';

  @override
  String get upgrade_desc_millionaire =>
      'Crédite instantanément 1 000 000 de pièces sur ton profil (outil de développement).';

  @override
  String get upgrade_desc_warehouse =>
      'Démarre une partie avec 500 tuiles en réserve (outil de développement).';

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
  String get shop_adRemovalIncludedBadge => 'Sans pubs incluses';

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
  String get home_buildSelection => 'Améliorations';

  @override
  String get home_buildSelectionLockedResume =>
      'Termine ou abandonne ta partie en cours avant de choisir de nouvelles améliorations.';

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
