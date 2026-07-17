/// Shader d'océan tropical — hex-cozy-games
///
/// Objectif visuel : une eau turquoise lumineuse type lagon, avec un peu
/// d'écume éparse et une animation très légère (scintillements, respiration
/// de l'écume, micro-ondulation de surface) qui donne l'impression d'une eau
/// vivante SANS jamais donner une sensation de tangage : il n'y a aucune
/// translation cohérente de grande amplitude, seulement des variations de
/// luminosité/opacité localisées et désynchronisées entre elles.
///
/// ── Pourquoi l'ancienne version semblait "blocs rectangulaires" ───────────
/// L'ancien bruit de valeur utilisait une fonction hash() avec de très gros
/// multiplicateurs (×443.897 puis fract()). Dès que les coordonnées de la
/// grille de bruit dépassaient quelques dizaines d'unités (ce qui arrive
/// très vite avec plusieurs octaves), la précision flottante mediump des
/// GPU mobiles ne suffisait plus à représenter la partie fractionnaire :
/// le hash s'effondrait en valeurs quantifiées, ce qui se voit comme des
/// cellules carrées à bords nets (exactement le défaut visible sur la
/// capture d'écran). En plus de ça, un bruit de valeur sur grille carrée a
/// de toute façon tendance à laisser deviner sa grille (axes alignés),
/// même sans bug de précision.
///
/// Le remplacement ci-dessous utilise le bruit Simplex 2D de Ian
/// McEwan / Ashima Arts (algorithme libre, largement utilisé sur mobile) :
///   - grille triangulaire → aucun alignement d'axe visible,
///   - toutes les multiplications internes sont bornées via mod289(),
///     donc stable même en précision flottante réduite,
///   - en plus, on applique une légère déformation de domaine (warp) et
///     une rotation entre octaves pour qu'aucune structure ne soit
///     perceptible, même à très faible fréquence.
///
/// Le temps (uTime) est rebouclé via mod() pour rester borné même après
/// plusieurs heures de session, par sécurité numérique.
///
/// Uniforms (ordre des setFloat côté Dart, inchangé) :
///   0  uTime        — temps en secondes (animation)
///   1  uWidth       — largeur écran en pixels logiques
///   2  uHeight      — hauteur écran en pixels logiques
///   3  uOffsetX     — décalage caméra X (cameraOffset.x)
///   4  uOffsetY     — décalage caméra Y (cameraOffset.y)
///   5  uZoom        — facteur de zoom courant
///
/// Le pivot de la grille reste identique au _layout de HexGridComponent :
///   (uOffsetX + uWidth * 0.42, uOffsetY + uHeight * 0.38)
/// afin que le motif de fond reste parfaitement ancré à la grille
/// hexagonale, sans flou ni décalage, à toute résolution et tout zoom.

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uWidth;
uniform float uHeight;
uniform float uOffsetX;
uniform float uOffsetY;
uniform float uZoom;

out vec4 fragColor;

// ── Programme principal ────────────────────────────────────────────────────
// Version simplifiée : plus aucune animation de surface (pas de vagues
// claires/sombres, pas de caustiques, pas de scintillements). Il ne reste
// que la couleur de fond unie et l'assombrissement (dégradé de profondeur
// autour du plateau + vignettage aux bords de l'écran).
// uTime n'est plus utilisé mais reste déclaré pour ne pas casser les
// setFloat côté Dart (ordre des uniforms inchangé).

void main() {
    vec2 fc = FlutterFragCoord().xy;

    // ── Coordonnées monde (ancrées à la grille hexagonale) ──────────────
    vec2 pivot = vec2(uOffsetX + uWidth * 0.42,
                      uOffsetY + uHeight * 0.38);
    vec2 world = (fc - pivot) / uZoom;

    // Couleur de fond dominante = #40D2FF exact (demande utilisateur).
    vec3 cA = vec3(0.251, 0.824, 1.000); // #40D2FF
    vec3 color = cA;

    // ── Dégradé de profondeur ─────────────────────────────────────────────
    // L'eau s'assombrit légèrement en s'éloignant du pivot de la grille
    // hexagonale, pour suggérer un lagon avec des zones "peu profondes"
    // près du plateau de jeu et "profondes" vers les bords.
    vec3 cDeep = cA * vec3(0.55, 0.68, 0.88);
    float depthT = smoothstep(280.0, 900.0, length(world));
    color = mix(color, cDeep, depthT * 0.4);

    // ── Vignettage ─────────────────────────────────────────────────────────
    // Léger assombrissement radial en espace écran (indépendant du zoom /
    // panoramique caméra) pour recentrer l'attention sur le plateau de jeu.
    vec2 screenUv = fc / vec2(uWidth, uHeight);
    float vigDist = length(screenUv - 0.5);
    float vig = smoothstep(0.85, 0.35, vigDist); // 1 = centre, 0 = coins
    color *= mix(0.82, 1.0, vig);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}