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
///
/// ── Vagues concentriques émanant du plateau ───────────────────────────────
/// Le plateau hexagonal est traité comme un objet qui flotte sur l'eau et
/// génère des anneaux concentriques fins et lumineux, centrés sur son pivot,
/// qui se propagent vers l'extérieur (phase = distance*fréquence -
/// temps*vitesse, passée dans pow(cos, N) pour un trait net plutôt qu'une
/// bande épaisse). Une enveloppe exponentielle décroissante avec la distance
/// au plateau atténue à la fois ces anneaux et l'activité générale des
/// caustiques : l'eau est vive près du plateau et devient progressivement
/// plus calme/lisse en s'en éloignant. Un très léger jitter du rayon (quelques
/// pixels) casse la perfection géométrique des cercles sans créer de forme en
/// pétales.

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

    // kScale contrôle la taille des veines de caustiques en pixels écran.
    // Valeur réduite (0.03 → 0.014) car en dézoomant, on voit davantage
    // d'unités monde à l'écran : sans cette réduction, les veines
    // paraissent fines/grêlées dès que la caméra n'est pas au zoom max
    // (c'est ce qui rendait le rendu très "mouchetures" en jeu réel).
    const float kScale = 0.014;
    vec2 uv = world * kScale;

    // Sécurité numérique : on reboucle la coordonnée de bruit sur une très
    // grande période (équivalente à ~250 000 px de panoramique caméra,
    // jamais atteinte en jeu) afin de rester insensible à la précision
    // flottante même après une très longue session de jeu / un plateau
    // très étendu.
    uv = mod(uv + 100.0, 200.0) - 100.0;

    // Temps rebouclé pour la même raison (stabilité numérique long-terme).
    float time = mod(uTime, 6000.0);

    // ── Vagues concentriques émanant du plateau ──────────────────────────
    // Le plateau (au pivot, donc à world = 0) est la source des vagues :
    // leur phase dépend de la distance au pivot, si bien qu'elles forment
    // des anneaux concentriques qui se propagent vers l'extérieur au cours
    // du temps (comme les ondes créées par un objet flottant sur l'eau).
    // Anneaux fins et nets (pas des bandes épaisses) : on passe un cosinus
    // dans pow(max(., 0), kRippleSharpness), qui n'allume qu'un mince trait
    // autour de chaque crête et laisse le reste à zéro.
    const float kRippleSpacing   = 130.0; // distance entre deux anneaux successifs (px monde)
    const float kRippleFreq      = 6.2831853 / kRippleSpacing;
    const float kRippleSpeed     = 2.6;   // vitesse angulaire de propagation (rad/s)
    const float kRippleFalloff   = 700.0; // distance caractéristique d'atténuation (px monde)
    const float kRippleSharpness = 6.0;   // plus grand = anneaux plus fins

    float boardDist = length(world);

    // Très légère irrégularité du rayon (quelques px), pour que les anneaux
    // ne soient pas des cercles mathématiquement parfaits — l'amplitude est
    // volontairement faible (petite devant kRippleSpacing) pour ne PAS créer
    // de forme en pétales/étoile, juste un tremblement à peine perceptible.
    float angle = atan(world.y, world.x);
    float radiusJitter = snoise(vec2(cos(angle), sin(angle)) * 3.0 + time * 0.02) * 4.0;

    float ringPhase = (boardDist + radiusJitter) * kRippleFreq - time * kRippleSpeed;
    float ringLine = pow(max(cos(ringPhase), 0.0), kRippleSharpness);

    // Enveloppe d'atténuation : proche du plateau = anneaux marqués et
    // activité vive, loin = eau qui s'apaise progressivement. `rippleEnvelope`
    // module aussi bien les anneaux concentriques que l'activité générale
    // des caustiques ci-dessous (moins de "vagues" en s'éloignant du plateau).
    float rippleEnvelope = exp(-boardDist / kRippleFalloff);


    // ── Vitesses ──────────────────────────────────────────────────────────
    // Volontairement modérées : rien ne doit "voyager" de façon cohérente
    // sur tout l'écran (ce qui donnerait une impression de tangage), mais
    // un peu plus vif qu'avant pour que la surface paraisse réellement
    // vivante — voir aussi [waveMask] plus bas pour le mouvement local des
    // petites vagues.
    const float kAnimSpeedMultiplier = 7.5;
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
    //
    // Étirement anisotrope : sans lui, les veines restent assez isotropes
    // (mouchetures ~rondes, visibles sur la capture d'écran d'origine). En
    // étirant le domaine selon un axe (×1.9) avant de calculer le FBM, les
    // veines s'allongent en bandes qui rappellent mieux de vraies caustiques
    // sous l'eau. L'axe d'étirement tourne très lentement dans le temps pour
    // qu'aucune direction fixe ne devienne perceptible/répétitive.
    float stretchAngle = time * 0.006;
    mat2 stretchRot = mat2(cos(stretchAngle), -sin(stretchAngle),
                            sin(stretchAngle),  cos(stretchAngle));
    vec2 uvStretched = stretchRot * uvWarped;   // vers le repère tournant
    uvStretched.y *= 1.9;                       // étirement sur l'axe tournant
    uvStretched = transpose(stretchRot) * uvStretched; // retour au repère monde

    vec2 uvA = uvStretched * 0.5;
    vec2 uvB = mat2(0.5, -0.866, 0.866, 0.5) * uvStretched * 0.62;

    float fA = fbm(uvA + vec2(tBase, tBase * 0.4), 3);
    float fB = fbm(uvB - vec2(tBase * 0.6, tBase * 0.9), 3);

    float wave1 = sin(fA * 6.2831853 + tBase * 2.0);
    float wave2 = sin(fB * 6.2831853 - tBase * 2.6);
    float caustic = wave1 * wave2; // ∈ [-1, 1] — veines là où les deux ondes s'alignent

    // ── Petites vagues locales : apparition / déplacement / disparition ──
    // Un champ FBM basse fréquence sert de masque d'intensité aux veines de
    // caustiques ci-dessus. Ce masque dérive doucement dans une direction
    // (driftUv) ET évolue dans le temps (troisième terme), si bien que
    // chaque petite "vague" se déplace légèrement puis s'estompe pendant
    // qu'une autre apparaît ailleurs — plutôt qu'un scintillement figé sur
    // place. Le déplacement reste lent et local (pas de translation globale
    // cohérente) pour ne jamais donner d'impression de tangage.
    vec2 driftUv = uvWarped * 0.24 + vec2(tBase * 0.4, -tBase * 0.28);
    float waveLife = fbm(driftUv + vec2(0.0, time * 0.07), 3);
    float waveMask = smoothstep(-0.35, 0.5, waveLife);

    // Le masque module l'intensité des veines (0.45 → 1.25) : plage relevée
    // par rapport à l'ancienne version pour que les vagues claires ressortent
    // plus souvent et plus franchement, sans jamais disparaître totalement
    // (garde un peu de vie partout).
    // Second facteur (0.3 → 1.0 via rippleEnvelope) : l'activité des
    // caustiques elle-même s'atténue en s'éloignant du plateau, en plus des
    // anneaux concentriques explicites plus bas — l'eau au loin reste
    // légèrement vivante mais nettement plus calme.
    float causticVisible = caustic * mix(0.45, 1.25, waveMask) * mix(0.3, 1.0, rippleEnvelope);

    // Couleur de fond dominante = #40D2FF exact (demande utilisateur).
    // L'éclat des caustiques ("vagues claires") est éclairci nettement plus
    // que cA (quasi blanc-cyan) afin de rester bien visible même sur le
    // nouveau fond bleu nuit tealisé de l'UI — l'ancienne variante cB était
    // trop proche de cA en luminosité et devenait quasi invisible.
    // Seuil resserré (0.55 → 0.85, contre 0.45 → 0.9 avant) : transition plus
    // courte donc veines plus nettes/contrastées, moins "brumeuses".
    vec3 cA = vec3(0.251, 0.824, 1.000); // #40D2FF — couleur de fond
    vec3 cB = mix(cA, vec3(1.0), 0.55);  // éclat très lumineux, presque blanc
    vec3 color = mix(cA, cB, smoothstep(0.55, 0.85, causticVisible));

    // ── Dégradé de profondeur ─────────────────────────────────────────────
    // L'eau s'assombrit et se sature légèrement en s'éloignant du pivot de
    // la grille hexagonale, pour suggérer un lagon avec des zones "peu
    // profondes" près du plateau de jeu et "profondes" vers les bords —
    // au lieu d'un aplat uniforme. Distance calculée en pixels monde
    // (avant mise à l'échelle du bruit), rayon choisi pour que la zone
    // proche du plateau reste quasiment inchangée.
    vec3 cDeep = cA * vec3(0.55, 0.68, 0.88); // plus sombre, légèrement plus froid/saturé
    float depthT = smoothstep(280.0, 900.0, length(world));
    color = mix(color, cDeep, depthT * 0.4);

    // ── Taches sombres ────────────────────────────────────────────────────
    // Même champ et même animation que les taches claires ci-dessus
    // (causticVisible, dérivé du même fbm/temps) : les taches sombres
    // bougent, apparaissent et disparaissent exactement comme les taches
    // claires, juste un ton plus foncé. Le seuil (0.80 → 0.97) est plus
    // étroit et plus extrême que celui des taches claires (0.55 → 0.95),
    // ce qui les rend environ deux fois moins fréquentes à l'écran.
    // Seuil resserré et décalé (0.85 → 0.96, contre 0.80 → 0.97 avant) et
    // ton plus sombre (×0.72 contre ×0.80) : bords plus nets, contraste
    // plus marqué avec les veines claires ci-dessus.
    vec3 cDark = cA * 0.72;
    float darkMask = smoothstep(0.85, 0.96, causticVisible);
    color = mix(color, cDark, darkMask);

    // ── Anneaux concentriques du plateau ──────────────────────────────────
    // Trait fin et lumineux uniquement (pas de contrepartie sombre) :
    // pondéré par rippleEnvelope, les anneaux sont nets et bien visibles
    // près du plateau et s'effacent progressivement en s'en éloignant,
    // exactement comme les ondes réelles d'un objet flottant sur l'eau.
    color = mix(color, cB, ringLine * rippleEnvelope * 0.6);

    // ── Scintillements (glints) ───────────────────────────────────────────
    // Petits points lumineux ponctuels façon reflets de soleil sur l'eau,
    // distincts des veines de caustiques ci-dessus : bruit à fréquence
    // nettement plus haute, seuillé très haut pour ne garder qu'une poignée
    // de pixels brillants à la fois, animé rapidement pour un clignotement
    // vif et discontinu (pas une simple dérive comme le reste de l'eau).
    // Fréquence compensée (×3.4 → ×7.5) pour que les points de scintillement
    // gardent la même taille apparente qu'avant la réduction de kScale
    // (sinon ils grossiraient en même temps que les veines de caustiques
    // et perdraient leur aspect "point ponctuel").
    vec2 glintUv = uvWarped * 7.5 + vec2(tBase * 1.6, -tBase * 2.1);
    float glintNoise = snoise(glintUv) * snoise(glintUv * 1.7 + vec2(5.2, -1.3));
    float glint = smoothstep(0.90, 0.99, glintNoise);
    color = mix(color, vec3(1.0), glint * 0.85);

    // ── Vignettage ─────────────────────────────────────────────────────────
    // Léger assombrissement radial en espace écran (pas en espace monde,
    // donc indépendant du zoom/panoramique caméra) pour recentrer l'attention
    // sur le plateau de jeu. Reste discret : au plus ~18% d'assombrissement
    // dans les coins, rien au centre.
    vec2 screenUv = fc / vec2(uWidth, uHeight);
    float vigDist = length(screenUv - 0.5);
    float vig = smoothstep(0.85, 0.35, vigDist); // 1 = centre, 0 = coins
    color *= mix(0.82, 1.0, vig);

    // ── Sortie ────────────────────────────────────────────────────────────
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}