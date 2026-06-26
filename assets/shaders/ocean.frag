/// Shader d'océan + archipel — hex-cozy-games
///
/// Reproduit l'esprit de l'illustration cible (archipel tropical vu du
/// ciel) entièrement de façon procédurale :
///   - Mer turquoise vive avec houle, rides de vent et reflets épars
///   - Îlots procéduraux dispersés dans l'espace monde : rochers bruts
///     (pitons gris) et îles tropicales complètes (roche → jungle → sable)
///   - Halo d'eau peu profonde + frange d'écume autour de chaque îlot
///
/// Comme il n'y a aucun asset bitmap (palmiers, etc. ont été retirés du
/// projet), tout le rendu — formes, couleurs, texture — est généré par le
/// shader, ce qui permet un défilement/zoom infini sans bord visible.
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
/// ce qui garantit que le motif de fond (mer ET îlots) suit la grille
/// parfaitement, sans flou, sans bords visibles, à toutes les résolutions
/// et tous les niveaux de zoom.

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uWidth;
uniform float uHeight;
uniform float uOffsetX;
uniform float uOffsetY;
uniform float uZoom;

out vec4 fragColor;

// ── Bruit de valeur 2D ─────────────────────────────────────────────────────

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),                hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

float fbm(vec2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(3.31, 7.71);
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        v += a * vnoise(p);
        p = p * 2.17 + shift;
        a *= 0.48;
    }
    return v;
}

float fbm4(vec2 p) { return fbm(p, 4); }
float fbm6(vec2 p) { return fbm(p, 6); }

// ── Champ d'îlots procéduraux ───────────────────────────────────────────────
//
// Grille de cellules dans l'espace monde ; chaque cellule a une probabilité
// d'héberger un îlot dont le centre est légèrement décalé (jitter) et dont
// le contour est rendu irrégulier par un bruit angulaire. On ne regarde que
// la cellule courante + ses 8 voisines, donc le coût reste borné.
//
// Sortie via paramètres "out" (plus sûr/portable qu'un struct retourné) :
//   ratio      — distance au centre / rayon de l'îlot (0 = centre, 1 = côte)
//   isTropical — 0 = piton rocheux nu, 1 = île tropicale complète
//   mountain   — bruit de relief (texture roche/végétation)
//   seed       — aléa propre à cet îlot (variation de couleur)
//   ang        — angle polaire (pour les stries de falaise)
const float kCellSize = 300.0;
const float kPresenceThreshold = 0.64; // ~36% des cellules ont un îlot

void nearestIsland(
    vec2 world,
    out float ratio,
    out float isTropical,
    out float mountain,
    out float seed,
    out float ang
) {
    ratio = 1.0e6;
    isTropical = 0.0;
    mountain = 0.0;
    seed = 0.0;
    ang = 0.0;

    vec2 cell = floor(world / kCellSize);

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 ncell = cell + vec2(float(i), float(j));
            float presence = hash(ncell + 0.13);
            if (presence > kPresenceThreshold) {
                float typeHash = hash(ncell + 8.4);
                float isRock = step(typeHash, 0.32);

                vec2 jitter = vec2(hash(ncell + 21.7), hash(ncell + 64.2)) - 0.5;
                vec2 center = (ncell + 0.5 + jitter * 0.55) * kCellSize;

                float baseRadius = mix(85.0, 165.0, hash(ncell + 33.9));
                float radius = mix(baseRadius, baseRadius * 0.38, isRock);

                vec2 rel = world - center;
                float d = length(rel);
                float a = atan(rel.y, rel.x);
                float wob = fbm(vec2(cos(a), sin(a)) * (1.6 + isRock * 1.4) + ncell * 4.0, 3);
                float irregular = radius * (0.74 + 0.46 * wob);
                float r = d / max(irregular, 1.0);

                if (r < ratio) {
                    ratio = r;
                    isTropical = 1.0 - isRock;
                    seed = hash(ncell + 47.1);
                    mountain = fbm(world * 0.018 + ncell * 9.0, 4);
                    ang = a;
                }
            }
        }
    }
}

// ── Programme principal ────────────────────────────────────────────────────

void main() {
    vec2 fc = FlutterFragCoord().xy;

    // ── Coordonnées monde (ancrées à la grille hexagonale) ──────────────
    vec2 pivot = vec2(uOffsetX + uWidth * 0.42,
                      uOffsetY + uHeight * 0.38);
    vec2 world = (fc - pivot) / uZoom;

    const float kScale = 0.0042;
    vec2 uv = world * kScale;

    float t = uTime * 0.02;

    // ── Recherche de l'îlot le plus proche ──────────────────────────────
    float islRatio, islTropical, islMountain, islSeed, islAngle;
    nearestIsland(world, islRatio, islTropical, islMountain, islSeed, islAngle);

    // ── Houle large (basse fréquence) ──────────────────────────────────
    float swell1 = fbm4(uv * 0.6 + vec2(t * 0.12, t * 0.08));
    float swell2 = fbm4(uv * 0.9 + vec2(t * 0.15, t * 0.05) + 50.0);
    float swell = swell1 * 0.65 + swell2 * 0.35;

    // ── Texture fine des rides de vent ─────────────────────────────────
    float ripple = fbm6(world * 0.03 + vec2(t * 0.6, t * 0.3));

    // ── Palette océan vive (turquoise tropical, cf. illustration cible) ─
    vec3 cDeep    = vec3(0.043, 0.376, 0.541);  // ~#0A6089
    vec3 cMid     = vec3(0.071, 0.498, 0.663);  // ~#137FA9
    vec3 cLight   = vec3(0.137, 0.659, 0.804);  // ~#23A8CD
    vec3 cShallow = vec3(0.290, 0.812, 0.831);  // ~#4ACFD4
    vec3 cFoam    = vec3(0.85, 0.94, 0.93);

    vec3 water = mix(cDeep, cMid, smoothstep(0.20, 0.50, swell));
    water = mix(water, cLight, smoothstep(0.40, 0.65, swell));
    water = mix(water, cShallow, smoothstep(0.58, 0.80, swell));

    // ── Rides de vent (micro-variation haute fréquence) ─────────────────
    float rippleStrength = 0.035;
    water += vec3(
        ripple * rippleStrength,
        ripple * rippleStrength * 0.8,
        ripple * rippleStrength * 0.6
    );

    // ── Crêtes d'écume diffuses (pleine mer) ─────────────────────────────
    float foamEdge = smoothstep(0.72, 0.88, swell);
    float foamNoise = fbm4(world * 0.025 + vec2(t * 0.3, t * 0.2));
    float foam = foamEdge * smoothstep(0.35, 0.65, foamNoise);
    water = mix(water, cFoam, foam * 0.55);

    // ── Reflets spéculaires (soleil) ────────────────────────────────────
    float spec = fbm6(world * 0.04 + vec2(t * 0.5, t * 0.7));
    float specMask = smoothstep(0.75, 0.92, spec);
    water = mix(water, vec3(1.0, 1.0, 0.95), specMask * 0.28);

    // ── Halo d'eau peu profonde + frange d'écume au pied des îlots ───────
    float shallowBand = smoothstep(0.90, 1.05, islRatio) *
                         (1.0 - smoothstep(1.05, 1.7, islRatio));
    float shoreFoam = smoothstep(0.93, 1.0, islRatio) *
                       (1.0 - smoothstep(1.0, 1.10, islRatio));
    vec3 cShallowGlow = vec3(0.62, 0.93, 0.90);
    water = mix(water, cShallowGlow, shallowBand * 0.55);
    water = mix(water, vec3(1.0), shoreFoam * 0.45);

    // ── Couleurs des îlots ────────────────────────────────────────────────
    vec3 cRockDark  = vec3(0.32, 0.29, 0.25);
    vec3 cRockLight = vec3(0.60, 0.56, 0.48);
    vec3 rock = mix(cRockDark, cRockLight, clamp(islMountain * 1.4 - 0.15, 0.0, 1.0));
    float crevice = fbm4(vec2(cos(islAngle), sin(islAngle)) * 6.0 + islSeed * 40.0);
    rock *= mix(0.84, 1.06, crevice);

    vec3 cJungleDark  = vec3(0.13, 0.32, 0.12);
    vec3 cJungleLight = vec3(0.34, 0.54, 0.21);
    float clump = fbm4(world * 0.045 + islSeed * 23.0);
    vec3 jungle = mix(cJungleDark, cJungleLight, clump);

    vec3 cSand = vec3(0.93, 0.87, 0.70);
    vec3 sand = cSand * mix(0.92, 1.04, fbm4(world * 0.06 + islSeed * 7.0));

    // Île tropicale : piton rocheux central -> jungle -> plage de sable.
    float peakT = smoothstep(0.0, 0.22, islRatio);
    vec3 tropicalLand = mix(rock, jungle, peakT);
    float sandT = smoothstep(0.60, 0.82, islRatio);
    tropicalLand = mix(tropicalLand, sand, sandT);

    // Piton rocheux nu : roche du centre au bord, légèrement assombrie
    // près de la ligne d'eau (roche mouillée).
    vec3 spireLand = rock * mix(1.0, 0.85, smoothstep(0.70, 1.0, islRatio));

    vec3 land = mix(spireLand, tropicalLand, islTropical);

    // Ombre de contact discrète à la ligne de rivage.
    float shoreShadow = smoothstep(0.80, 0.96, islRatio);
    land = mix(land, land * 0.8, shoreShadow * 0.6);

    // ── Fusion finale terre / mer selon la distance à l'îlot ─────────────
    float waterness = smoothstep(0.94, 1.20, islRatio);
    vec3 color = mix(land, water, waterness);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
