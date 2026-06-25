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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../game/hex_board_game.dart';
import '../providers/pause_provider.dart';
import '../providers/player_profile_provider.dart';
import '../providers/placement_commit.dart';
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

  // Décalage cumulatif de la caméra pour le parallax du fond de jeu.
  double _bgOffsetX = 0.0;
  double _bgOffsetY = 0.0;

  // Clés réelles utilisées par le tutoriel (Story 1.10a) pour cibler les
  // éléments UI à mettre en évidence — le highlight suit la position et la
  // taille effectives du widget, plutôt que des coordonnées arbitraires.
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _coinsKey = GlobalKey();
  final GlobalKey _tileStackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _game = HexBoardGame(
      ref: ref,
      onCameraMove: (dx, dy) {
        setState(() {
          _bgOffsetX += dx;
          _bgOffsetY += dy;
        });
      },
    );
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
          // ── Fond lié au plateau (dézoom 50 %, pas de parallax, synchro zoom) ─
          _ParallaxBackground(
            offsetX: _bgOffsetX,
            offsetY: _bgOffsetY,
            zoom: _game.zoom,
          ),

          // ── Jeu Flame — reçoit TOUS les gestes directement ────────────────
          GameWidget(key: _boardKey, game: _game),

          // ── Compteur de pièces (story 1.6b) + récompense pièces ────────
          Positioned(
            top: 80,
            left: 16,
            child: Consumer(builder: (context, ref, _) {
              final session = ref.watch(sessionProvider);
              return Container(
                key: _coinsKey,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr.game_sessionCoins,
                      style: TextStyle(
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
                ),
              );
            }),
          ),

          // ── Bouton Annuler ─────────────────────────────────────────────
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
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.undo, color: Colors.white),
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

/// Fond de jeu lié au plateau — zoom et déplacement 1:1 avec la caméra.
class _ParallaxBackground extends StatelessWidget {
  const _ParallaxBackground({
    required this.offsetX,
    required this.offsetY,
    required this.zoom,
  });

  final double offsetX;
  final double offsetY;
  final double zoom;

  // Échelle de base (dézoomée de 50% par rapport à l'ancienne valeur 5.0).
  static const double _baseBgScale = 2.5;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = _baseBgScale * zoom;
    // Centrage initial + décalage 1:1 avec la caméra.
    // Le pivot de zoom correspond à l'origine du plateau (42 % largeur, 38 % hauteur)
    // pour que fond et grille évoluent du même point.
    final pivotX = size.width * 0.42;
    final pivotY = size.height * 0.38;
    final dx = offsetX + pivotX * (1 - zoom) - zoom * (size.width * _baseBgScale - size.width) / 2;
    final dy = offsetY + pivotY * (1 - zoom) - zoom * (size.height * _baseBgScale - size.height) / 2;

    return OverflowBox(
      maxWidth: size.width * scale,
      maxHeight: size.height * scale,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Image.asset(
          'assets/images/game_background.png',
          width: size.width * scale,
          height: size.height * scale,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
