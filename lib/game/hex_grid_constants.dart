/// Constantes d'animation partagées entre `hex_grid_component.dart`
/// (pose/retrait des tuiles) et `hex_grid_preview.dart` (prévisualisation).
library;

/// Décalage vertical (en pixels écran "plat", avant projection iso) de la
/// tuile en prévisualisation pour la faire paraître "légèrement surélevée"
/// au-dessus du plateau (story 1.5a).
const double kPreviewLiftPx = 10.0;

/// Opacité de la tuile en prévisualisation.
const double kPreviewAlpha = 1.0;

/// Distance (en pixels écran) dont chaque icône de pièce de prévisualisation
/// est à la fois poussée vers l'extérieur (à l'opposé du centre de la tuile
/// en cours de pose) et surélevée (effet 3D), pour qu'elle se détache
/// visuellement de la tuile plutôt que de sembler posée dessus.
const double kPreviewCoinOffsetPx = 20.0;

/// Surélévation supplémentaire (en pixels écran), en plus de [kPreviewLiftPx],
/// de l'icône de tuile bonus centrée sur la prévisualisation — pour qu'elle
/// se détache mieux au-dessus de la tuile plutôt que de sembler posée dessus.
const double kPreviewBonusExtraLiftPx = 8.0;

// ── Animation de pose (descente + léger rebond "flottant") ─────────────────

/// Hauteur de départ de la descente : la tuile posée part de la même
/// élévation que la prévisualisation, pour un enchaînement visuel continu.
const double kDropStartLiftPx = kPreviewLiftPx;

/// Profondeur du dépassement sous l'emplacement final, avant le rebond de
/// remontée (effet "posée dans l'eau, qui flotte légèrement en remontant").
const double kDropBounceOvershootPx = 1.0 / 3;

/// Durée de la phase de descente.
const double kDropDescendDurationSec = 0.10;

/// Durée de la phase de rebond (remontée jusqu'à la position finale).
const double kDropBounceDurationSec = 0.08;

/// Durée de la montée en puissance de l'ondulation du bord bas une fois la
/// tuile arrivée à son emplacement final.
const double kDropWaveRampInDurationSec = 0.45;

// ── Animation d'annulation (retour vers la pile) ────────────────────────────

/// Durée du vol de retour de la tuile annulée vers la pile de prévisualisation.
const double kUndoFlyDurationSec = 0.32;

/// Échelle finale (quasi nulle) atteinte par la tuile juste avant sa
/// disparition dans la pile.
const double kUndoFlyEndScale = 0.12;
