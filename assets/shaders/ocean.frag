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

// ── Bruit Simplex 2D (Ian McEwan / Ashima Arts, domaine public MIT) ───────
// Toutes les opérations de hachage sont bornées par mod289(), ce qui évite
// l'effondrement de précision responsable des "blocs" de l'ancien shader.

vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }

vec3 permute(vec3 x) { return mod289(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187,
                         0.366025403784439,
                        -0.577350269189626,
                         0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);

    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                    + i.x + vec3(0.0, i1.x, 1.0));

    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// Rotation fixe appliquée entre chaque octave : casse toute corrélation
// résiduelle entre octaves successives (évite le moindre motif visible).
const mat2 kOctaveRot = mat2(0.8775826, 0.4794255, -0.4794255, 0.8775826);

float fbm(vec2 p, int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 6; i++) {
        if (i >= octaves) break;
        sum += amp * snoise(p);
        p = kOctaveRot * p * 2.02 + 0.073;
        amp *= 0.55;
    }
    return sum; // approximativement dans [-1.05, 1.05]
}

// ── Programme principal ────────────────────────────────────────────────────

void main() {
    vec2 fc = FlutterFragCoord().xy;

    // ── Coordonnées monde (ancrées à la grille hexagonale) ──────────────
    vec2 pivot = vec2(uOffsetX + uWidth * 0.42,
                      uOffsetY + uHeight * 0.38);
    vec2 world = (fc - pivot) / uZoom;

    const float kScale = 0.03;
    vec2 uv = world * kScale;

    // Sécurité numérique : on reboucle la coordonnée de bruit sur une très
    // grande période (équivalente à ~250 000 px de panoramique caméra,
    // jamais atteinte en jeu) afin de rester insensible à la précision
    // flottante même après une très longue session de jeu / un plateau
    // très étendu.
    uv = mod(uv + 100.0, 200.0) - 100.0;

    // Temps rebouclé pour la même raison (stabilité numérique long-terme).
    float time = mod(uTime, 6000.0);

    // ── Vitesses volontairement très lentes ─────────────────────────────
    // Rien ne doit "voyager" de façon cohérente sur tout l'écran : c'est ce
    // qui donnerait une impression de tangage. Seules des variations
    // locales (scintillement, respiration) sont perceptibles.
    const float kAnimSpeedMultiplier = 5.0;
    float tBase   = time * 0.0035 * kAnimSpeedMultiplier;
    float tWarp   = time * 0.0060 * kAnimSpeedMultiplier;

    // ── Déformation de domaine (léger flot d'eau) ────────────────────────
    // Warp un peu plus marqué que la version précédente (quasi nulle) pour
    // que la surface donne l'impression de bouger réellement, sans aller
    // jusqu'à une translation cohérente de grande amplitude (pas de
    // "tangage").
    float warpX = snoise(uv * 0.35 + vec2(tWarp, 0.0)) * 0.15;
    float warpY = snoise(uv * 0.35 + vec2(0.0, tWarp) + 3.7) * 0.15;
    vec2 uvWarped = uv + vec2(warpX, warpY);

    // ── Forme de base : caustiques d'eau ──────────────────────────────────
    // Remplace l'ancien bruit unique seuillé (qui donnait des taches
    // arrondies statiques, façon pelage de vache — pas très "eau") par deux
    // champs de FBM à échelle/rotation différentes, chacun passé dans un
    // sinus. Le produit des deux ondes ne s'illumine que là où elles
    // s'alignent : on obtient de fines veines qui s'étirent, ondulent et se
    // déplacent — beaucoup plus proche de reflets de caustiques sous l'eau.
    vec2 uvA = uvWarped * 0.5;
    vec2 uvB = mat2(0.5, -0.866, 0.866, 0.5) * uvWarped * 0.62;

    float fA = fbm(uvA + vec2(tBase, tBase * 0.4), 3);
    float fB = fbm(uvB - vec2(tBase * 0.6, tBase * 0.9), 3);

    float wave1 = sin(fA * 6.2831853 + tBase * 2.0);
    float wave2 = sin(fB * 6.2831853 - tBase * 2.6);
    float caustic = wave1 * wave2; // ∈ [-1, 1] — veines là où les deux ondes s'alignent

    // Deux couleurs proches → variation quasi imperceptible, juste vivante.
    // Couleurs inchangées : seules les formes et l'animation ont changé.
    vec3 cA = vec3(0.38, 0.86, 0.88); // #61DBE0 turquoise clair
    vec3 cB = vec3(0.47, 0.92, 0.92); // #78EBEB turquoise très clair
    vec3 color = mix(cA, cB, smoothstep(0.55, 0.95, caustic));

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}