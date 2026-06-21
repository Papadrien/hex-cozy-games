/// Écran de jeu principal — story 1.2 / 1.3 / 1.5a / 1.5b / 1.6b / 1.7g.
///
/// Gestion des gestes :
///  - Pan 1 doigt + Zoom pinch : délégués à Flame via [HexBoardGame]
///    (PanDetector + ScaleDetector). Le [GameWidget] reçoit les gestes
///    directement — pas de GestureDetector Flutter par-dessus pour ne pas
///    interférer avec le multi-touch. Pendant une prévisualisation (story
///    1.5a), le pan vertical sert à la rotation plutôt qu'au déplacement
///    caméra — voir [HexBoardGame].
///  - Tap : capturé via [TapDetector] dans [HexBoardGame] — sélectionne ou
///    déplace la prévisualisation sur un emplacement disponible (1.5a),
///    valide le placement au second tap sur la même cellule (1.5b).
library;

import 'dart:async';

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/game_enums.dart';
import '../core/strings.dart';
import '../data/app_database.dart';
import '../game/hex_board_game.dart';
import '../providers/pause_provider.dart';
import '../providers/player_profile_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/quest_provider.dart';
import '../providers/session_provider.dart';
import '../providers/tutorial_provider.dart';
import '../services/ad_service.dart';
import 'pause_button.dart';
import 'pause_modal.dart';
import 'results_modal.dart';
import 'tile_stack_hud.dart';
import 'tutorial_overlay.dart';

/// Durée d'affichage de l'animation de confirmation de récompense (story 1.6b).
/// Le tag reste visible 1.5s puis disparaît en fade out sur 0.5s (total 2s).
const Duration _kConfirmationDuration = Duration(milliseconds: 1500);
const Duration _kFadeOutDuration = Duration(milliseconds: 500);

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final HexBoardGame _game;
  Timer? _clearRewardTimer;
  double _rewardOpacity = 0.0;

  // Clés réelles utilisées par le tutoriel (Story 1.10a) pour cibler les
  // éléments UI à mettre en évidence — le highlight suit la position et la
  // taille effectives du widget, plutôt que des coordonnées arbitraires.
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _coinsKey = GlobalKey();
  final GlobalKey _tileStackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _game = HexBoardGame(ref: ref);
    Future.microtask(
      () => ref.read(tutorialProvider.notifier).checkAndStart(),
    );
  }

  @override
  void dispose() {
    _clearRewardTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PauseState>(pauseProvider, (prev, next) {
      if (prev?.isPaused != next.isPaused) {
        _game.paused = next.isPaused;
      }
    });

    // Interstitielle AdMob toutes les [kAdInterstitialFrequency] tuiles
    // (Story 3.1b). Le compteur est cumulatif sur la session.
    // Désactivée si le joueur est premium (Story 3.5a).
    ref.listen<int>(adTilesPlacedProvider, (prev, next) {
      if (prev != null && next > 0 && next % kAdInterstitialFrequency == 0) {
        final isPremium =
            ref.read(playerProfileProvider).maybeWhen(
                  data: (row) => row.isPremium,
                  orElse: () => false,
                );
        if (!isPremium) {
          showInterstitialAd();
        }
      }
    });

    // Auto-effacement de la dernière récompense affichée après le délai.
    // Fade out sur 500ms après 1.5s de visibilité.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.lastReward != null && prev?.lastReward != next.lastReward) {
        _clearRewardTimer?.cancel();
        setState(() => _rewardOpacity = 1.0);
        _clearRewardTimer = Timer(_kConfirmationDuration, () {
          if (mounted) {
            setState(() => _rewardOpacity = 0.0);
            Future.delayed(_kFadeOutDuration, () {
              if (mounted) {
                ref.read(sessionProvider.notifier).clearLastReward();
              }
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: kBackgroundColor,
      bottomNavigationBar: _BannerAdWidget(),
      body: Stack(
        children: [
          // ── Jeu Flame — reçoit TOUS les gestes directement ────────────────
          GameWidget(key: _boardKey, game: _game),

          // ── Badge debug ───────────────────────────────────────────────────
          if (kDebugMode)
            const Positioned(
              top: 48,
              left: 16,
              child: _DebugBadge(label: 'Story 1.8b — écran résultats'),
            ),

          // ── Compteur de pièces (story 1.6b) + récompense pièces ────────
          Positioned(
            top: 80,
            left: 16,
            child: Consumer(builder: (context, ref, _) {
              final session = ref.watch(sessionProvider);
              return Column(
                key: _coinsKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr.game_sessionCoins,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  Row(children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${session.coins}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                  _CoinRewardTag(opacity: _rewardOpacity),
                ],
              );
            }),
          ),

          // ── Bouton Annuler ──────────────────────────────────────────────
          Consumer(builder: (context, ref, _) {
            final canUndo = ref.watch(lastPlacementProvider) != null;

            return Stack(children: [
              Positioned(
                bottom: 24,
                left: 16,
                child: FloatingActionButton.small(
                  heroTag: 'undo',
                  onPressed: canUndo
                      ? () => undoPlacement(
                            ref,
                            onUndo: _game.removeTileFromFlame,
                          )
                      : null,
                  child: const Icon(Icons.undo),
                ),
              ),
            ]);
          }),

          // ── Bouton Pause ──────────────────────────────────────────────────
          const Positioned(
            top: 48,
            right: 12,
            child: PauseButton(),
          ),

          // ── HUD pile de tuiles + tag tuiles bonus (story 1.7g) ──────────
          Positioned(
            top: 96,
            right: 12,
            child: Column(
              key: _tileStackKey,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const TileStackHud(),
                _BonusTileTag(opacity: _rewardOpacity),
              ],
            ),
          ),

          // ── Modale Pause ──────────────────────────────────────────────────
          const PauseModal(),

          // ── Écran de résultats (Story 1.8b) ──────────────────────────────
          const ResultsModal(),

          // ── Encart progression quêtes (Story 2.3b) ───────────────────────
          const Positioned(
            bottom: 96,
            left: 16,
            right: 16,
            child: _QuestProgressBanner(),
          ),

          // ── Tutoriel premier lancement (Story 1.10a / 1.10b) ────────────
          TutorialOverlay(
            targetKeys: {
              'board': _boardKey,
              'tileStack': _tileStackKey,
              'coins': _coinsKey,
            },
          ),
        ],
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Tag pièces bonus — affiché sous le compteur de pièces. Disparaît en fade
/// out. N'affiche que les pièces bonus (améliorations), pas le total de base.
class _CoinRewardTag extends ConsumerWidget {
  const _CoinRewardTag({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final reward = session.lastReward;
    if (reward == null || reward.bonusCoins <= 0) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              '+${reward.bonusCoins}${context.tr.reward_coins}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tag tuiles bonus — affiché sous la pile de tuiles. Disparaît en fade out.
/// Bannette de progression des quêtes — Story 2.3b.
///
/// Affiche la quête active la plus proche de la complétion
/// (toutes catégories confondues).
class _QuestProgressBanner extends ConsumerWidget {
  const _QuestProgressBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(permanentQuestsProvider);
    return questsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (quests) {
        final active = quests
            .where((q) => !q.isCompleted)
            .where((q) => !_hasIncompletePredecessor(q, quests))
            .toList();
        if (active.isEmpty) return const SizedBox.shrink();

        // Prendre la quête la plus proche de la complétion.
        active.sort(
          (a, b) => (b.currentValue / b.targetValue)
              .compareTo(a.currentValue / a.targetValue),
        );
        final quest = active.first;
        final progress = (quest.currentValue / quest.targetValue).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _iconForCategory(QuestCategory.fromDb(quest.category)),
                color: _colorForCategory(QuestCategory.fromDb(quest.category)),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      quest.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _colorForCategory(QuestCategory.fromDb(quest.category)),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${quest.currentValue}/${quest.targetValue}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasIncompletePredecessor(
    PermanentQuestRow quest,
    List<PermanentQuestRow> all,
  ) {
    return all.any((q) => q.nextQuestId == quest.id && !q.isCompleted);
  }

  Color _colorForCategory(QuestCategory category) {
    return switch (category) {
      QuestCategory.tilesPlaced => const Color(0xFF4CAF50),
      QuestCategory.villageSize => const Color(0xFFE57373),
      QuestCategory.biomesClosed => const Color(0xFF64B5F6),
    };
  }

  IconData _iconForCategory(QuestCategory category) {
    return switch (category) {
      QuestCategory.tilesPlaced => Icons.grid_on,
      QuestCategory.villageSize => Icons.home,
      QuestCategory.biomesClosed => Icons.water_drop,
    };
  }
}

class _BonusTileTag extends ConsumerWidget {
  const _BonusTileTag({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final reward = session.lastReward;
    if (reward == null || reward.bonusTiles <= 0) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hexagon, color: Colors.lightBlue, size: 14),
            const SizedBox(width: 4),
            Text(
               '+${reward.bonusTiles}${context.tr.reward_bonusTiles}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière publicitaire AdMob en bas de l'écran de jeu (Story 3.1a).
///
/// N'apparaît que si [isPremium] est faux (Story 3.5a). Affiche une bannière
/// [AdSize.banner] (320×50 dp) centrée en bas. Si la bannière n'est pas
/// chargée ou si le chargement échoue, un espace vide de la même hauteur est
/// affiché pour éviter le sautillement du layout.
class _BannerAdWidget extends ConsumerWidget {
  const _BannerAdWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(playerProfileProvider).maybeWhen(
          data: (row) => row.isPremium,
          orElse: () => false,
        );
    if (isPremium) return const SizedBox.shrink();

    final banner = ref.watch(bannerAdProvider);
    return Container(
      color: kBackgroundColor,
      height: kAdBannerHeight,
      alignment: Alignment.center,
      child: banner != null
          ? AdWidget(ad: banner)
          : const SizedBox.shrink(),
    );
  }
}
