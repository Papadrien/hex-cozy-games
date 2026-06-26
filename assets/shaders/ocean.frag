/// Shader d'océan semi-réaliste — hex-cozy-games
///
/// Reproduit l'aspect de l'image game_background.png :
///   - Fond océan avec gradient de bleu-vert (teal) profond à clair
///   - Houle large et lente avec crêtes d'écume diffuse
///   - Reflets spéculaires épars (soleil sur l'eau)
///   - Texture de surface fine (rides de vent)
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

    // ── Houle large (basse fréquence) ──────────────────────────────────
    float swell1 = fbm4(uv * 0.6 + vec2(t * 0.12, t * 0.08));
    float swell2 = fbm4(uv * 0.9 + vec2(t * 0.15, t * 0.05) + 50.0);
    float swell = swell1 * 0.65 + swell2 * 0.35;

    // ── Texture fine des rides de vent ─────────────────────────────────
    float ripple = fbm6(world * 0.03 + vec2(t * 0.6, t * 0.3));

    // ── Palette océan réaliste (teinte ~185°, saturation 50-75%) ──────
    // Couleurs extraites de l'image game_background.png :
    //   Profond    #0B5C63  ~vec3(0.043, 0.361, 0.388)
    //   Milieu     #14646C  ~vec3(0.078, 0.392, 0.424)
    //   Mi-clair    #1C94C4  ~vec3(0.110, 0.580, 0.769)
    //   Surface    #1CBCCC  ~vec3(0.110, 0.737, 0.800)
    //   Haut-fond  #AEC8D0  ~vec3(0.682, 0.784, 0.816)
    vec3 cDeep    = vec3(0.043, 0.361, 0.388);
    vec3 cMid     = vec3(0.078, 0.392, 0.424);
    vec3 cLight   = vec3(0.110, 0.580, 0.769);
    vec3 cShallow = vec3(0.110, 0.737, 0.800);
    vec3 cFoam    = vec3(0.682, 0.784, 0.816);

    // Mélange principal via la houle.
    vec3 color = mix(cDeep, cMid, smoothstep(0.20, 0.50, swell));
    color = mix(color, cLight, smoothstep(0.40, 0.65, swell));
    color = mix(color, cShallow, smoothstep(0.58, 0.80, swell));

    // ── Rides de vent (micro-variation haute fréquence) ─────────────────
    float rippleStrength = 0.035;
    color += vec3(
        ripple * rippleStrength,
        ripple * rippleStrength * 0.8,
        ripple * rippleStrength * 0.6
    );

    // ── Crêtes d'écume diffuses ────────────────────────────────────────
    float foamEdge = smoothstep(0.72, 0.88, swell);
    float foamNoise = fbm4(world * 0.025 + vec2(t * 0.3, t * 0.2));
    float foam = foamEdge * smoothstep(0.35, 0.65, foamNoise);
    color = mix(color, cFoam, foam * 0.55);

    // ── Reflets spéculaires (soleil) ────────────────────────────────────
    float spec = fbm6(world * 0.04 + vec2(t * 0.5, t * 0.7));
    float specMask = smoothstep(0.75, 0.92, spec);
    color = mix(color, vec3(1.0, 1.0, 0.95), specMask * 0.30);

    // ── Légère atténuation de la saturation en profondeur ──────────────
    float depthFactor = 1.0 - smoothstep(0.0, 0.40, swell);
    vec3 desat = vec3(dot(color, vec3(0.3, 0.6, 0.1)));
    color = mix(color, desat, depthFactor * 0.25);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
