import 'dart:math';
import 'dart:ui' show Canvas, Color, FontWeight, Offset, Paint, PaintingStyle, Path, Rect, StrokeCap, TextDirection;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../core/colors.dart';
import 'tile_component.dart'; // kIsoScaleY, kTileDepthPriorityPreview

// ── Animation constants ─────────────────────────────────────────────────────

const int kBonusIntensityMaxTiles = 10;
const double kBonusLiftDurationSec = 0.16;
const double kBonusWaterDurationSec = 0.16;
const double kBonusLiftMinPx = 6.0;
const double kBonusLiftMaxPx = 18.0;
const double kBonusGrowMinScale = 1.45;
const double kBonusGrowMaxScale = 2.2;
const int kBonusWaterParticleMin = 3;
const int kBonusWaterParticleMax = 10;
const double kBonusIconStaggerInterval = 0.12;

// ── Helper ──────────────────────────────────────────────────────────────────

/// Dessine un hexagone regular (pointy-top, isotrope) sur le canvas.
void drawHex(Canvas canvas, Offset center, double radius,
    {required Paint paint}) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angleDeg = 60.0 * i - 90.0;
    final angleRad = angleDeg * pi / 180.0;
    final x = center.dx + radius * cos(angleRad);
    final y = center.dy + radius * sin(angleRad) * kIsoScaleY;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}

/// Coins d'un hexagone régulier (pointy-top), avec écrasement isométrique
/// optionnel en Y (1.0 = pas d'écrasement — cas de [PreviewBonusComponent]).
List<Offset> _hexCorners(Offset center, double radius, {double squashY = 1.0}) {
  return List.generate(6, (i) {
    final angleDeg = 60.0 * i - 90.0;
    final angleRad = angleDeg * pi / 180.0;
    return Offset(
      center.dx + radius * cos(angleRad),
      center.dy + radius * sin(angleRad) * squashY,
    );
  });
}

/// Dessine la face latérale (extrusion 3D assombrie) sous les côtés tournés
/// vers le bas de l'icône de tuile bonus — même principe que l'extrusion
/// des tuiles du plateau ([tile_component.dart], facteur d'assombrissement
/// 0.62) et de la pile HUD ([tile_stack_hud.dart]), pour que l'icône reste
/// raccord visuellement plutôt que de rester un simple aplat bleu.
void _drawHexSideDepth(
  Canvas canvas,
  Offset center,
  double radius,
  double depth,
  Color topColor,
  double alpha, {
  double squashY = 1.0,
}) {
  if (depth <= 0.01) return;
  final corners = _hexCorners(center, radius, squashY: squashY);
  final shaded = Color.from(
    alpha: topColor.a,
    red: topColor.r * 0.62,
    green: topColor.g * 0.62,
    blue: topColor.b * 0.62,
  );
  final paint = Paint()
    ..color = shaded.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;
  for (var i = 0; i < 6; i++) {
    final c0 = corners[i];
    final c1 = corners[(i + 1) % 6];
    final midY = (c0.dy + c1.dy) / 2;
    if (midY < center.dy + 0.01) continue; // côté tourné vers le haut : ignoré
    final b0 = Offset(c0.dx, c0.dy + depth);
    final b1 = Offset(c1.dx, c1.dy + depth);
    canvas.drawPath(
      Path()
        ..moveTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b0.dx, b0.dy)
        ..close(),
      paint,
    );
  }
}

/// Fine surbrillance sur le bord supérieur de l'icône, pour un léger effet
/// de biseau brillant côté "haut" — cohérent avec la bande de surbrillance
/// des tuiles du plateau (bord extérieur éclairci).
void _drawHexTopRim(
  Canvas canvas,
  Offset center,
  double radius,
  double alpha, {
  double squashY = 1.0,
}) {
  final corners = _hexCorners(center, radius, squashY: squashY);
  final paint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, radius * 0.06)
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 6; i++) {
    final c0 = corners[i];
    final c1 = corners[(i + 1) % 6];
    final midY = (c0.dy + c1.dy) / 2;
    if (midY > center.dy - 0.01) continue; // ne garde que les côtés du haut
    canvas.drawLine(c0, c1, paint);
  }
}

// ── Coin component ──────────────────────────────────────────────────────────

/// Pièce affichée au niveau d'un côté connecté — animée ou statique selon [animated].
/// Si [flyTarget] est non-null, la pièce vole vers cette position.
class CoinComponent extends PositionComponent {
  CoinComponent({
    required super.position,
    required double hexSize,
    this.animated = false,
    this.flyTarget,
    int priority = 10,
  })  : _radius = hexSize * 0.18,
        _alpha = animated ? null : 0.85,
        super(priority: priority);

  final double _radius;
  final bool animated;

  /// Non-null en mode statique, null en mode animé.
  final double? _alpha;

  /// Position cible pour le vol vers le compteur (null = pas de vol).
  final Vector2? flyTarget;

  double _life = 0.0;
  static const double _kDuration = 1.2;

  /// Sprite partagé (chargé une seule fois, réutilisé par toutes les pièces).
  static Sprite? _sprite;
  static Future<Sprite>? _spriteLoad;

  static Future<Sprite> _loadSprite() {
    return _spriteLoad ??= Sprite.load('coin.png').then((s) => _sprite = s);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (_sprite == null) {
      await _loadSprite();
    }
    if (flyTarget != null) {
      add(MoveEffect.to(
        flyTarget!,
        EffectController(duration: 0.6, curve: Curves.easeInOut),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!animated) return;
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite == null) return;

    final alpha = animated
        ? (_life < 0.3)
            ? (_life / 0.3)
            : (1.0 - (_life - 0.3) / (_kDuration - 0.3))
        : _alpha!;
    final r = animated ? _radius + _life * 2.0 : _radius;

    sprite.renderRect(
      canvas,
      Rect.fromCircle(center: Offset.zero, radius: r),
      overridePaint: Paint()
        ..color = kRewardWhite.withValues(alpha: alpha),
    );
  }
}

// ── Preview bonus icon ──────────────────────────────────────────────────────

/// Icône de tuile bonus centrée sur la prévisualisation (story 1.7e).
class PreviewBonusComponent extends PositionComponent {
  PreviewBonusComponent({
    required super.position,
    required double hexSize,
    required this.bonusCount,
  })  : _radius = hexSize * 0.22,
        super(priority: kTileDepthPriorityPreview + 1);

  final double _radius;
  final int bonusCount;

  late final TextPainter _textPainter = TextPainter(
    text: TextSpan(
      text: '+$bonusCount',
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: _radius * 1.0,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void render(Canvas canvas) {
    const alpha = 0.9;
    final r = _radius;

    // Face latérale (extrusion 3D) sous l'icône, raccord avec les tuiles
    // du plateau plutôt qu'un simple aplat bleu.
    _drawHexSideDepth(canvas, Offset.zero, r, r * 0.28, kBonusBlueLight, alpha);

    // Hexagone extérieur (fond).
    canvas.drawPath(
      _hexagonPath(r),
      Paint()
        ..color = kBonusBlueLight.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _hexagonPath(r * 0.75),
      Paint()
        ..color = kBonusBlueLighter.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.fill,
    );
    // Fin liseré clair sur le bord supérieur pour un léger effet de biseau.
    _drawHexTopRim(canvas, Offset.zero, r, alpha);

    // Nombre de tuiles bonus (+N) centré en blanc.
    _textPainter.text = TextSpan(
      text: '+$bonusCount',
      style: TextStyle(
        color: kRewardWhite.withValues(alpha: alpha),
        fontSize: r * 1.0,
        fontWeight: FontWeight.bold,
      ),
    );
    _textPainter.layout();
    _textPainter.paint(
      canvas,
      Offset(-_textPainter.width / 2, -_textPainter.height / 2),
    );
  }

  Path _hexagonPath(double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60.0 * i - 90.0) * pi / 180.0;
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

// ── Bonus tile animation ────────────────────────────────────────────────────

/// Icône de tuile bonus animée après placement — vole vers la pile HUD
/// comme les pièces (Story 4.2b).
///
/// Enrichie (effet de gain renforcé) : halo qui pulse pendant le vol,
/// traînée de particules fantômes laissée derrière l'icône, et un léger
/// "squash & stretch" à l'arrivée sur le HUD plutôt qu'une disparition
/// sèche.
class BonusTileAnimComponent extends PositionComponent {
  BonusTileAnimComponent({
    required super.position,
    required double hexSize,
    required this.bonusCount,
    this.flyTarget,
    this._startDelay = 0.0,
    this.onImpact,
    int totalBonusTiles = 1,
  })  : _radius = hexSize * 0.22,
        _liftPx = kBonusLiftMinPx +
            (kBonusLiftMaxPx - kBonusLiftMinPx) *
                _intensityFor(totalBonusTiles),
        _growScale = kBonusGrowMinScale +
            (kBonusGrowMaxScale - kBonusGrowMinScale) *
                _intensityFor(totalBonusTiles),
        _waterParticleCount = (kBonusWaterParticleMin +
                (kBonusWaterParticleMax - kBonusWaterParticleMin) *
                    _intensityFor(totalBonusTiles))
            .round(),
        super(priority: kTileDepthPriorityPreview + 1);

  final double _radius;
  final int bonusCount;

  final Vector2? flyTarget;

  final double _startDelay;
  double _delayElapsed = 0.0;

  final VoidCallback? onImpact;

  final double _liftPx;
  final double _growScale;
  final int _waterParticleCount;

  late final TextPainter _textPainter = TextPainter(
    text: TextSpan(
      text: '+$bonusCount',
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: _radius * 1.0,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static double _intensityFor(int totalBonusTiles) {
    const maxExtra = kBonusIntensityMaxTiles - 1;
    if (maxExtra <= 0) return 1.0;
    return ((totalBonusTiles - 1) / maxExtra).clamp(0.0, 1.0);
  }

  late Vector2 _spawnPos;
  late Vector2 _liftedPos;
  bool _waterSpawned = false;

  double _life = 0.0;
  static const double _kFlyDuration = 0.6;
  static const double _kFloatDuration = 0.58;
  static const double _kPreFlyDuration =
      kBonusLiftDurationSec + kBonusWaterDurationSec;
  static const double _kArrivalBounceDuration = 0.22;
  bool _arrived = false;
  double _arrivalLife = 0.0;
  static const double _kTrailInterval = 0.035;
  double _sinceLastTrail = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnPos = position.clone();
    _liftedPos = _spawnPos - Vector2(0, _liftPx);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_delayElapsed < _startDelay) {
      _delayElapsed += dt;
      return;
    }
    _life += dt;

    if (_arrived) {
      _arrivalLife += dt;
      if (_arrivalLife >= _kArrivalBounceDuration) {
        removeFromParent();
      }
      return;
    }

    if (_life < kBonusLiftDurationSec) {
      final t = Curves.easeOut
          .transform((_life / kBonusLiftDurationSec).clamp(0.0, 1.0));
      position = Vector2(
        _spawnPos.x + (_liftedPos.x - _spawnPos.x) * t,
        _spawnPos.y + (_liftedPos.y - _spawnPos.y) * t,
      );
      return;
    }

    if (_life < _kPreFlyDuration) {
      position = _liftedPos.clone();
      if (!_waterSpawned) {
        _waterSpawned = true;
        parent?.add(BonusWaterBurst(
          position: _liftedPos.clone(),
          baseRadius: _radius,
          particleCount: _waterParticleCount,
        ));
      }
      return;
    }

    if (flyTarget != null) {
      final flyLife = _life - _kPreFlyDuration;
      final t = Curves.easeInOut.transform(
        (flyLife / _kFlyDuration).clamp(0.0, 1.0),
      );
      position = Vector2(
        _liftedPos.x + (flyTarget!.x - _liftedPos.x) * t,
        _liftedPos.y + (flyTarget!.y - _liftedPos.y) * t,
      );

      _sinceLastTrail += dt;
      if (_sinceLastTrail >= _kTrailInterval) {
        _sinceLastTrail = 0.0;
        parent?.add(TrailDot(
          position: position.clone(),
          radius: _radius * 0.4,
          color: kBonusBlueLighter,
        ));
      }

      if (flyLife >= _kFlyDuration) {
        _arrived = true;
        onImpact?.call();
      }
    } else {
      final floatLife = _life - _kPreFlyDuration;
      position = Vector2(_liftedPos.x, _liftedPos.y - floatLife * 40);
      if (floatLife >= _kFloatDuration) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_delayElapsed < _startDelay) return;

    final travelScale = _growScale * 0.85;

    double scaleMul;
    double alpha;

    if (_arrived) {
      scaleMul = travelScale;
      alpha = 1.0 - _arrivalLife / _kArrivalBounceDuration;
    } else if (_life < kBonusLiftDurationSec) {
      final t = Curves.easeOut
          .transform((_life / kBonusLiftDurationSec).clamp(0.0, 1.0));
      scaleMul = 1.0 + (_growScale - 1.0) * t;
      alpha = (_life / kBonusLiftDurationSec).clamp(0.0, 1.0);
    } else if (_life < _kPreFlyDuration) {
      final t = ((_life - kBonusLiftDurationSec) / kBonusWaterDurationSec)
          .clamp(0.0, 1.0);
      scaleMul = _growScale - (_growScale - travelScale) * t;
      alpha = 1.0;
    } else if (flyTarget != null) {
      final flyLife = _life - _kPreFlyDuration;
      final flyT = (flyLife / _kFlyDuration).clamp(0.0, 1.0);
      final pulse = 1.0 + sin(flyLife * 18) * 0.08;
      scaleMul = travelScale * pulse;
      alpha = flyT < 0.7 ? 1.0 : (1.0 - (flyT - 0.7) / 0.3).clamp(0.0, 1.0);
    } else {
      final floatLife = _life - _kPreFlyDuration;
      final t = (floatLife / _kFloatDuration).clamp(0.0, 1.0);
      scaleMul = travelScale;
      alpha = 1.0 - t;
    }

    var r = _radius * scaleMul;

    var scaleX = 1.0;
    var scaleY = 1.0;
    if (_arrived) {
      final t = (_arrivalLife / _kArrivalBounceDuration).clamp(0.0, 1.0);
      final squash = sin(t * pi);
      scaleX = 1.0 + squash * 0.5;
      scaleY = 1.0 - squash * 0.35;
      r *= 1.0 + t * 0.6;
    }

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Face latérale (extrusion 3D) sous l'icône, dans le même repère
    // squash/stretch — même écrasement isométrique que le reste du plateau.
    _drawHexSideDepth(canvas, Offset.zero, r, r * 0.28, kBonusBlueLight, alpha,
        squashY: kIsoScaleY);

    drawHex(canvas, Offset.zero, r,
        paint: Paint()
          ..color = kBonusBlueLight.withValues(alpha: alpha)
          ..style = PaintingStyle.fill);
    drawHex(canvas, Offset.zero, r * 0.75,
        paint: Paint()
          ..color = kBonusBlueLighter.withValues(alpha: alpha * 0.7)
          ..style = PaintingStyle.fill);
    // Fin liseré clair sur le bord supérieur pour un léger effet de biseau.
    _drawHexTopRim(canvas, Offset.zero, r, alpha, squashY: kIsoScaleY);

    _textPainter.text = TextSpan(
      text: '+$bonusCount',
      style: TextStyle(
        color: kRewardWhite.withValues(alpha: alpha),
        fontSize: r * 1.0,
        fontWeight: FontWeight.bold,
      ),
    );
    _textPainter.layout();
    _textPainter.paint(
      canvas,
      Offset(-_textPainter.width / 2, -_textPainter.height / 2),
    );
    canvas.restore();
  }
}

// ── Water burst effect ──────────────────────────────────────────────────────

/// Petite éclaboussure d'eau jouée une fois le soulèvement de la particule
/// de gain de tuile terminé, juste avant son envol vers le HUD.
class BonusWaterBurst extends PositionComponent {
  BonusWaterBurst({
    required super.position,
    required double baseRadius,
    required int particleCount,
  })  : _particles = _generateParticles(baseRadius, particleCount),
        super(priority: kTileDepthPriorityPreview + 1);

  final List<BonusParticle> _particles;
  double _life = 0;
  static const double _kDuration = 0.35;

  static List<BonusParticle> _generateParticles(double baseRadius, int count) {
    final rng = Random();
    return List.generate(count, (i) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 16 + rng.nextDouble() * 20;
      return BonusParticle(
        position: Vector2.zero(),
        velocity: Vector2(cos(angle) * speed, sin(angle) * speed * 0.6),
        radius: baseRadius * (0.10 + rng.nextDouble() * 0.12),
        alpha: i.isEven ? 0.8 : 0.6,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity += Vector2(0, 60 * dt);
      p.velocity *= 0.92;
      p.alpha *= max(0.0, 1.0 - dt * 2.2);
      p.radius *= max(0.4, 1.0 - dt * 1.6);
    }
  }

  @override
  void render(Canvas canvas) {
    for (final p in _particles) {
      final color = p.alpha > 0.45 ? kBonusBlueLighter : kRewardWhite;
      drawHex(canvas, Offset(p.position.x, p.position.y), p.radius,
          paint: Paint()
            ..color = color.withValues(alpha: p.alpha)
            ..style = PaintingStyle.fill);
    }
  }
}

// ── Trail dot ───────────────────────────────────────────────────────────────

/// Particule fantôme laissée en traînée derrière une icône volante.
class TrailDot extends PositionComponent {
  TrailDot({
    required super.position,
    required this._radius,
    required this.color,
  })  : super(priority: kTileDepthPriorityPreview);

  final double _radius;
  final Color color;
  double _life = 0.0;
  static const double _kDuration = 0.25;

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _kDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _kDuration).clamp(0.0, 1.0);
    drawHex(canvas, Offset.zero, _radius * (1.0 - t * 0.7),
        paint: Paint()
          ..color = color.withValues(alpha: 0.55 * (1.0 - t))
          ..style = PaintingStyle.fill);
  }
}

// ── Particle data ───────────────────────────────────────────────────────────

/// Donnée d'une particule individuelle.
class BonusParticle {
  BonusParticle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.alpha,
  });

  Vector2 position;
  Vector2 velocity;
  double radius;
  double alpha;
}
