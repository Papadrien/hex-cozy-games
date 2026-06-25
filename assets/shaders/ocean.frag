/// Shader d'océan procédural — hex-cozy-games
///
/// Reproduit le style illustré/cartoon de l'image de référence :
///   - Grandes taches de couleur organiques en cyan-turquoise
///   - Petits traits d'écume blancs effilés et épars
///   - Pas d'effets réalistes : style plat, lavis aquarelle doux
///
/// Uniforms (ordre des setFloat côté Dart) :
///   0  uTime        — temps en secondes (animation)
///   1  uWidth       — largeur écran en pixels logiques
///   2  uHeight      — hauteur écran en pixels logiques
///   3  uOffsetX     — décalage caméra X (cameraOffset.x)
///   4  uOffsetY     — décalage caméra Y (cameraOffset.y)
///   5  uZoom        — facteur de zoom courant
///
/// Le pivot de la grille est identique au _layout de HexGridComponent :
///   (uOffsetX + uWidth * 0.42, uOffsetY + uHeight * 0.38)
/// Tout fragment est projeté en coordonnées monde via ce pivot et uZoom,
/// ce qui garantit que le motif de fond suit la grille parfaitement,
/// sans flou, sans bords visibles, à toutes les résolutions et tous les
/// niveaux de zoom.

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uWidth;
uniform float uHeight;
uniform float uOffsetX;
uniform float uOffsetY;
uniform float uZoom;

out vec4 fragColor;

// ── Bruit de valeur 2D ─────────────────────────────────────────────────────

/// Hash pseudo-aléatoire 2D → scalaire dans [0, 1).
float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

/// Bruit de valeur bilinéaire, résultat dans [0, 1].
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Courbe de lissage C2 pour éviter les artefacts de grille.
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),                hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

/// Brownian motion fractal (4 octaves) — donne des formes organiques.
float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = p * 2.17 + vec2(3.31, 7.71); // décalage pour éviter l'auto-corrélation
        a *= 0.48;
    }
    return v;
}

// ── Programme principal ────────────────────────────────────────────────────

void main() {
    vec2 fc = FlutterFragCoord().xy;

    // ── Coordonnées monde (ancrées à la grille hexagonale) ──────────────
    // Le pivot suit exactement HexGridComponent._layout.origin :
    //   origin = (cameraOffset.x + W*0.42, cameraOffset.y + H*0.38)
    vec2 pivot = vec2(uOffsetX + uWidth * 0.42,
                      uOffsetY + uHeight * 0.38);
    vec2 world = (fc - pivot) / uZoom;

    // Facteur d'échelle global du motif.
    // 1 uv ≈ 240 unités monde ≈ 5 tuiles hex (kHexSize = 48).
    // Les grandes taches font ~0.5–1.2 uv → elles occupent quelques tuiles.
    const float kScale = 0.0042;
    vec2 uv = world * kScale;

    float t = uTime * 0.016; // animation très lente : ~1 cycle/min

    // ── Motif de couleur principal (domain warp 1 passe) ────────────────
    // Le domain warp courbe les UV pour obtenir des formes organiques
    // non-répétitives, comme un lavis peint à la main.
    vec2 warp = vec2(
        fbm4(uv + vec2(0.0,  0.0) + t * 0.9),
        fbm4(uv + vec2(5.23, 1.31) + t * 0.7)
    );
    float colorField = fbm4(uv + 0.85 * warp + t * 0.35);

    // ── Palette ocean illustrée (teinte ~188°, saturation 66–78%) ───────
    //   Profond    #0FA3C7  vec3(0.059, 0.639, 0.780)
    //   Milieu     #1CC0D8  vec3(0.110, 0.753, 0.847)
    //   Surface    #3DD3E7  vec3(0.239, 0.827, 0.906)
    //   Brillant   #72E5F3  vec3(0.447, 0.898, 0.953)
    vec3 cDeep   = vec3(0.059, 0.639, 0.780);
    vec3 cMid    = vec3(0.110, 0.753, 0.847);
    vec3 cLight  = vec3(0.239, 0.827, 0.906);
    vec3 cBright = vec3(0.447, 0.898, 0.953);

    // Transitions en smoothstep → look illustré (transitions nettes mais sans
    // bords durs).
    vec3 color = mix(cDeep,  cMid,    smoothstep(0.25, 0.48, colorField));
    color       = mix(color, cLight,  smoothstep(0.44, 0.63, colorField));
    color       = mix(color, cBright, smoothstep(0.60, 0.76, colorField));

    // ── Lavis fin (texture de pinceau très subtile) ──────────────────────
    // Un bruit haute fréquence léger pour briser l'aspect trop synthétique
    // et rappeler la texture d'aquarelle numérique.
    float brushA = vnoise(world * 0.018 + vec2(t * 0.55, t * 0.28));
    float brushB = vnoise(world * 0.028 + vec2(t * 0.33, t * 0.61));
    float brush  = (brushA * 0.55 + brushB * 0.45 - 0.5) * 0.055;
    color += vec3(brush * 0.9, brush, brush * 1.05); // légère teinte cyan

    // ── Traits d'écume (blanc, épars, légèrement animés) ────────────────
    // Deux couches de bruit thresholdé → petites taches allongées blanches
    // rappelant les reflets/crêtes du style illustré de l'image de référence.

    // Couche 1 : traits plus courts et fréquents
    vec2 foamUV1 = world * 0.024 + vec2(t * 0.38, t * 0.14);
    float f1 = vnoise(foamUV1);
    float f1b = vnoise(foamUV1 * 1.8 + vec2(4.17, 2.31));
    float foam1 = smoothstep(0.74, 0.82, f1 * 0.55 + f1b * 0.45);

    // Couche 2 : traits légèrement plus grands pour la variété
    vec2 foamUV2 = world * 0.014 + vec2(t * 0.22, t * 0.31);
    float f2 = vnoise(foamUV2);
    float f2b = vnoise(foamUV2 * 2.1 + vec2(7.83, 5.12));
    float foam2 = smoothstep(0.76, 0.83, f2 * 0.6 + f2b * 0.4);

    float foamMask = max(foam1, foam2 * 0.8);
    // Couleur écume : blanc légèrement bleuté, comme dans l'image de référence.
    color = mix(color, vec3(0.87, 0.97, 1.0), foamMask * 0.70);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
