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
import 'dart:math' show sin, pi;
import 'dart:ui' show FragmentProgram, FragmentShader, Offset;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/colors.dart';
import '../core/constants.dart';
import '../core/strings.dart';
import '../game/hex_board_game.dart';
import '../game/hex_coords.dart';
import '../providers/end_game_provider.dart';
import '../providers/grid_state_provider.dart';
import '../providers/pause_provider.dart';
import '../providers/placement_provider.dart';
import '../providers/player_profile_provider.dart';
import '../providers/placement_commit.dart';
import '../providers/second_chance_provider.dart';
import '../providers/session_provider.dart';
import '../providers/tile_stack_provider.dart';
import '../providers/tutorial_provider.dart';
import '../services/ad_service.dart';
import '../services/haptics_service.dart';
import 'active_upgrades_hud.dart';
import 'glass_container.dart';
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
  final GlobalKey _undoKey = GlobalKey();
  final GlobalKey<_TileStackImpactReactionState> _tileStackImpactKey =
      GlobalKey();

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
    _game.getBonusFlyTarget = () => _stackHudFlyTarget();
    // Chaque icône de tuile bonus qui arrive sur le HUD (échelonnées sur
    // les gains multi-tuiles) fait "pop" le compteur avec une intensité
    // fixe, plus discrète que le pop principal déclenché par [lastReward]
    // — l'empilement des deux donne un feedback layered plutôt qu'un pop
    // unique répété identique.
    _game.onBonusImpact = () =>
        _tileStackImpactKey.currentState?.pulse(0.5);
    Future.microtask(
      () => ref.read(tutorialProvider.notifier).checkAndStart(),
    );
  }

  @override
  void dispose() {
    _clearRewardTimer?.cancel();
    super.dispose();
  }

  /// Position (coordonnées jeu Flame) du centre de la pile de tuiles HUD,
  /// utilisée comme cible de vol pour l'animation d'annulation — voir
  /// [HexBoardGame.removeTileFromFlame]. [GameWidget] occupant tout l'écran
  /// avec la même origine que le [Stack] racine, les coordonnées globales du
  /// HUD correspondent directement aux coordonnées jeu.
  Vector2? _stackHudFlyTarget() {
    final hudBox = _tileStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (hudBox == null || !hudBox.hasSize) return null;
    final globalCenter = hudBox.localToGlobal(hudBox.size.center(Offset.zero));
    return Vector2(globalCenter.dx, globalCenter.dy);
  }

  /// Sélectionne et oriente automatiquement une tuile en prévisualisation
  /// (sans la poser) pour l'étape 3 du tutoriel — les icônes pièce sont
  /// calculées à partir de la prévisualisation, pas d'un placement réel.
  ///
  /// Priorité donnée à la case sud-ouest — la même que celle indiquée par le
  /// doigt aux étapes 1 et 4 — pour que la démonstration reste cohérente
  /// visuellement d'une étape à l'autre ; les 5 autres directions servent de
  /// repli si cette case ne permet aucune connexion possible.
  Future<void> _previewTutorialConnection() async {
    final grid = ref.read(gridProvider);
    if (grid.placedTiles.length != 1) return;
    if (grid.tileAt(const HexCoords(0, 0)) == null) return;

    final activeTile = ref.read(tileStackProvider).activeTile;
    if (activeTile == null) return;

    const directionsPriority = [3, 0, 1, 2, 4, 5]; // sud-ouest en premier
    for (final dir in directionsPriority) {
      final coords = const HexCoords(0, 0).neighbor(dir);
      for (var rotation = 0; rotation < 6; rotation++) {
        final rotated = activeTile.rotated(rotation);
        if (!grid.hasCompatibleSide(coords, rotated)) continue;

        final placementNotifier = ref.read(placementProvider.notifier);
        placementNotifier.selectCell(coords);
        placementNotifier.rotate(rotation);
        return;
      }
    }
  }

  /// Déclenche automatiquement l'annulation du dernier placement (étape 6
  /// du tutoriel), avec l'animation de vol vers la pile.
  void _triggerUndo() {
    final target = _stackHudFlyTarget();
    undoPlacement(
      ref,
      onUndo: (coords) => _game.removeTileFromFlame(
        coords,
        flyTarget: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PauseState>(pauseProvider, (prev, next) {
      if (prev?.isPaused != next.isPaused) {
        _game.paused = next.isPaused;
      }
    });

    // Tutoriel étape 3 (« les icônes pièce te montrent ce que tu vas
    // gagner ») : pose automatiquement une tuile garantissant au moins une
    // connexion avec la tuile centrale, pour que l'icône de pièce mise en
    // évidence par [TutorialOverlay] soit effectivement visible à l'écran —
    // voir [_autoPlaceTutorialConnection].
    ref.listen<TutorialState>(tutorialProvider, (prev, next) {
      if (!next.isActive) return;
      final justEntered =
          prev == null || prev.currentStep != next.currentStep || !prev.isActive;
      if (!justEntered) return;

      if (next.currentStep == 2) {
        _previewTutorialConnection();
      } else if (next.currentStep == 4) {
        ref.read(placementProvider.notifier).clearSelection();
      } else if (next.currentStep == 5) {
        _triggerUndo();
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

    // Audit UX : le bouton retour système (Android) n'était intercepté nulle
    // part pendant une partie — un appui pouvait quitter l'écran de jeu sans
    // passer par la modale Pause (qui, elle, protège bien la sortie via
    // "Sauvegarder et quitter" / "Abandonner"). `PopScope(canPop: false)`
    // rend les deux chemins de sortie cohérents :
    //  - Partie en cours (pas en pause) → ouvre la modale Pause, comme le
    //    bouton Pause du HUD.
    //  - Modale Pause déjà ouverte → referme la modale (reprend le jeu),
    //    comme le bouton Reprendre.
    // Une fois la partie terminée (modale Résultats affichée), on laisse le
    // pop système reprendre son cours normal (retour à l'accueil).
    return PopScope(
      canPop: ref.watch(isGameOverProvider),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final isPaused = ref.read(pauseProvider).isPaused;
        if (isPaused) {
          ref.read(pauseProvider.notifier).resume();
        } else {
          ref.read(pauseProvider.notifier).pause();
        }
      },
      child: Scaffold(
      backgroundColor: kBackgroundColor,
      bottomNavigationBar: _BannerAdWidget(),
      body: Stack(
        children: [
          // ── Fond océan procédural (shader GLSL, résolution infinie) ──────────
          _OceanBackground(
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassContainer(
                    key: _coinsKey,
                    borderRadius: 14,
                    tintColor: kGlassBlue,
                    tintAlpha: 0.22,
                    borderColor: kGlassBlueBorder,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          const Icon(Icons.monetization_on,
                              color: Colors.amber, size: 20),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RewardTag(opacity: _rewardOpacity, isCoin: true),
                ],
              );
            }),
          ),

          // ── Bouton Annuler ─────────────────────────────────────────────
          // Zone cliquable alignée sur `kActiveUpgradeSlotSize` (44×44) —
          // même taille de cible tactile que les slots de l'encart central,
          // au lieu des 40×40 d'origine (audit UX).
          Consumer(builder: (context, ref, _) {
            final canUndo = ref.watch(lastPlacementProvider) != null;

            return Positioned(
              bottom: 24,
              right: 16,
              child: Semantics(
                button: true,
                label: context.tr.game_undo_semanticLabel,
                enabled: canUndo,
                child: GlassContainer(
                  key: _undoKey,
                  borderRadius: 14,
                  tintColor: kGlassBlue,
                  tintAlpha: 0.22,
                  borderColor: kGlassBlueBorder,
                  width: kActiveUpgradeSlotSize,
                  height: kActiveUpgradeSlotSize,
                  onTap: canUndo
                      ? () {
                          buttonHapticTap(context);
                          final target = _stackHudFlyTarget();
                          undoPlacement(
                            ref,
                            onUndo: (coords) => _game.removeTileFromFlame(
                              coords,
                              flyTarget: target,
                            ),
                          );
                        }
                      : null,
                  child: const Icon(Icons.undo, color: Colors.white, size: 20),
                ),
              ),
            );
          }),

          // ── Bouton Pause ──────────────────────────────────────────────────
          const Positioned(
            top: 42,
            right: 6,
            child: PauseButton(),
          ),

          // ── Encart des améliorations actives — Story B12e ───────────────
          // Emplacement Joker (Hold) et Deuxième chance (ex Story B10/B11)
          // sont désormais interactifs directement depuis leur slot ici,
          // au lieu d'un HUD dédié séparé à gauche (audit UX : un seul
          // emplacement à repérer par amélioration pendant la partie).
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(child: ActiveUpgradesHud()),
          ),

          // ── HUD pile de tuiles + tag tuiles bonus (story 1.7g) ──────────
          Positioned(
            top: 96,
            right: 12,
            child: Column(
              key: _tileStackKey,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TileStackImpactReaction(
                    key: _tileStackImpactKey, child: const TileStackHud()),
                _RewardTag(opacity: _rewardOpacity, isCoin: false),
              ],
            ),
          ),

          // ── Bannière d'indication du mode sélection Deuxième chance ─────
          const Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(child: _SecondChanceHintBanner()),
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
              'undo': _undoKey,
            },
          ),
        ],
      ),
      ),
    );
  }
}

/// Fait "réagir" la pile de tuiles HUD à chaque gain d'une pose : léger
/// rebond d'échelle (pop) et halo doré qui pulse, avec une intensité
/// proportionnelle au gain total (pièces + pièces bonus + tuiles bonus) de
/// la pose. Complète le vol de l'icône bonus vers ce même HUD en donnant
/// au HUD lui-même un feedback d'impact au moment où le gain "arrive".
class _TileStackImpactReaction extends ConsumerStatefulWidget {
  const _TileStackImpactReaction({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<_TileStackImpactReaction> createState() =>
      _TileStackImpactReactionState();
}

class _TileStackImpactReactionState
    extends ConsumerState<_TileStackImpactReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _intensity = 0.0;

  /// Gain total au-delà duquel l'intensité du pop/glow plafonne — garde une
  /// réaction perceptible mais pas écrasante sur les très gros gains
  /// (cohérent avec [kGainBurstMaxGain] côté rendu Flame).
  static const int _kMaxGainForIntensity = 9;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Déclenche le pop/glow avec l'intensité donnée (0.0-1.0). Utilisée à la
  /// fois pour le gain global d'une pose (via [sessionProvider.lastReward])
  /// et pour chaque icône de tuile bonus échelonnée arrivant sur le HUD
  /// (via [HexBoardGame.onBonusImpact]).
  void pulse(double intensity) {
    if (!mounted || intensity <= 0) return;
    _intensity = intensity.clamp(0.0, 1.0);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      final reward = next.lastReward;
      if (reward == null || prev?.lastReward == reward) return;
      final totalGain =
          reward.connectedSides.length + reward.bonusCoins + reward.bonusTiles;
      if (totalGain <= 0) return;
      pulse(totalGain / _kMaxGainForIntensity);
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Courbe "pop" : montée rapide puis léger sur-rebond avant de
        // revenir à l'échelle normale (sin sur une demi-période étirée).
        final t = _controller.value;
        final pop = sin(t * pi) * _intensity;
        final scale = 1.0 + pop * 0.14;
        final glow = pop;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: glow > 0.02
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kRewardGold.withValues(alpha: 0.45 * glow),
                        blurRadius: 18 * glow,
                        spreadRadius: 2 * glow,
                      ),
                    ],
                  )
                : null,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Tag récompense unique — pièces ou tuiles bonus, selon [isCoin].
/// Disparaît en fade out. N'affiche que la partie bonus de la récompense.
class _RewardTag extends ConsumerWidget {
  const _RewardTag({required this.opacity, required this.isCoin});

  final double opacity;
  final bool isCoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final reward = session.lastReward;
    if (reward == null) return const SizedBox.shrink();

    final value = isCoin ? reward.bonusCoins : reward.bonusTiles;
    if (value <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: GlassContainer(
        borderRadius: 10,
        tintColor: kGlassBlue,
        tintAlpha: 0.22,
        borderColor: kGlassBlueBorder,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCoin ? Icons.monetization_on : Icons.hexagon,
              color: isCoin ? Colors.amber : Colors.lightBlue,
              size: isCoin ? 16 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              '+$value${isCoin ? context.tr.reward_coins : context.tr.reward_bonusTiles}',
              style: TextStyle(
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

/// Fond d'océan procédural généré par shader GLSL.
///
/// Remplace l'ancien [_ParallaxBackground] bitmap. Avantages :
///   - Résolution infinie : aucun flou au zoom.
///   - Infini dans toutes les directions : jamais de bord visible.
///   - Animé : léger mouvement de l'eau (très lent, non intrusif).
///
/// Les coordonnées monde sont calculées avec le même pivot que
/// [HexGridComponent._layout], ce qui garantit un ancrage parfait
/// du motif à la grille hexagonale.
class _OceanBackground extends StatefulWidget {
  const _OceanBackground({
    required this.offsetX,
    required this.offsetY,
    required this.zoom,
  });

  final double offsetX;
  final double offsetY;
  final double zoom;

  @override
  State<_OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<_OceanBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0.0;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadShader();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _time = elapsed.inMicroseconds / 1e6;
    });
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await FragmentProgram.fromAsset('assets/shaders/ocean.frag');
      if (mounted) setState(() => _program = program);
    } catch (e) {
      debugPrint('OceanBackground: shader load failed: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      return const ColoredBox(color: Color(0xFF42E0F5));
    }

    final size = MediaQuery.sizeOf(context);
    final shader = program.fragmentShader();

    shader.setFloat(0, _time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setFloat(3, widget.offsetX);
    shader.setFloat(4, widget.offsetY);
    shader.setFloat(5, widget.zoom);

    return CustomPaint(
      painter: _OceanPainter(shader: shader),
      size: size,
    );
  }
}

class _OceanPainter extends CustomPainter {
  const _OceanPainter({required this.shader});

  final FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_OceanPainter oldDelegate) => true;
}

/// Bannière d'indication affichée pendant le mode sélection de Deuxième
/// chance (Story B11) — invisible sinon.
class _SecondChanceHintBanner extends ConsumerWidget {
  const _SecondChanceHintBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(secondChanceModeProvider);
    if (!isActive) return const SizedBox.shrink();

    return GlassContainer(
      borderRadius: 20,
      tintColor: const Color(0xFFFFB300),
      tintAlpha: 0.28,
      borderColor: const Color(0xFFFFD54F).withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.tr.game_secondChance_tooltipActive,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

