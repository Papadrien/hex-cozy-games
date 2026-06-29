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

    const float kScale = 0.01;
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
    float tBase   = time * 0.0035;
    float tWarp   = time * 0.0060;
    float tSwell  = time * 0.0018;  // houle lente basse fréquence
    float tRipple = time * 0.0500;
    float tFoam   = time * 0.0250;
    float tGlint  = time * 0.2200;

    // ── Déformation de domaine ───────────────────────────────────────────
    // Distord légèrement les coordonnées avant le calcul de la forme de
    // base : ça casse définitivement toute trace de structure de grille et
    // donne un aspect fluide/organique à l'eau.
    vec2 warp = vec2(
        fbm(uv * 0.8 + vec2(tWarp, -tWarp * 0.7), 3),
        fbm(uv * 0.8 + vec2(-tWarp * 0.6, tWarp) + 11.3, 3)
    );
    // Houle basse fréquence : ondulation douce des grandes masses de couleur.
    float swellA = snoise(uv * 0.18 + vec2(tSwell, tSwell * 0.5));
    float swellB = snoise(uv * 0.22 + vec2(-tSwell * 0.7, tSwell * 1.1) + 5.7);
    vec2 swell = vec2(swellA, swellB) * 0.28;
    vec2 uvWarped = uv + warp * 0.35 + swell;

    // ── Forme de base : grandes zones de turquoise clair / profond ──────
    float base = fbm(uvWarped * 0.55 + vec2(tBase, tBase * 0.6), 5);
    base = clamp(base * 0.5 + 0.5, 0.0, 1.0); // 0..1

    // ── Palette mer de surface, style illustré ───────────────────────────
    //   Profond   #5AB8C8  — bleu-vert lumineux
    //   Médium    #52CCDA  — bleu-cyan aéré
    //   Lumineux  #6AD8D8  — turquoise vif
    //   Haut-fond #96EAEA  — liseré écume claire
    vec3 cDeep    = vec3(0.353, 0.722, 0.784);
    vec3 cMid     = vec3(0.322, 0.800, 0.855);
    vec3 cLight   = vec3(0.416, 0.847, 0.847);
    vec3 cShallow = vec3(0.588, 0.918, 0.918);

    vec3 color = mix(cDeep, cMid, smoothstep(0.15, 0.45, base));
    color = mix(color, cLight, smoothstep(0.40, 0.70, base));
    color = mix(color, cShallow, smoothstep(0.68, 0.92, base));

    // ── Micro-ondulation de surface ──────────────────────────────────────
    // Grain fin qui anime la texture de l'eau sans déplacer la couleur de
    // fond : juste une variation de luminosité très subtile.
    float ripple = fbm(uvWarped * 6.0 + vec2(tRipple, tRipple * 0.4), 3);
    color += ripple * 0.065;

    // ── Écume légère, éparse et "respirante" ─────────────────────────────
    // Des plaques diffuses, peu nombreuses, dont l'opacité respire
    // doucement (chaque plaque a sa propre phase, dérivée du bruit local,
    // donc rien ne semble se déplacer ensemble dans une direction commune).
    float foamN = fbm(uv * 1.5 + vec2(tFoam, -tFoam * 0.5) + 30.0, 4);
    foamN = clamp(foamN * 0.5 + 0.5, 0.0, 1.0);
    float foamMask = smoothstep(0.66, 0.86, foamN);
    float foamBreathe = 0.80 + 0.20 * sin(tFoam * 2.4 + foamN * 6.2831853);
    vec3 cFoam = vec3(0.93, 0.99, 0.98);
    color = mix(color, cFoam, foamMask * foamBreathe * 0.38);

    // ── Reflets scintillants (soleil sur l'eau) ──────────────────────────
    // Points épars et brillants, qui clignotent individuellement (phase
    // tirée du bruit local) plutôt que de balayer l'écran ensemble.
    float glintN = fbm(uv * 9.0 + vec2(tGlint * 0.3, -tGlint * 0.2) + 70.0, 3);
    glintN = clamp(glintN * 0.5 + 0.5, 0.0, 1.0);
    float glintMask = smoothstep(0.82, 0.95, glintN);
    float glintTwinkle = 0.5 + 0.5 * sin(tGlint * 3.0 + glintN * 12.0);
    color = mix(color, vec3(1.0, 0.99, 0.92), glintMask * glintTwinkle * 0.35);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}