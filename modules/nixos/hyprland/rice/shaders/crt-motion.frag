#version 300 es
//
// crt-motion.frag — ./crt.frag 에 흐르는 것 둘(그레인, 험 바)을 더한 판.
//
// **이건 공짜가 아니다.** `time` 유니폼을 쓰는 화면 셰이더는 매 프레임 그림이
// 달라질 수 있으므로 하이프랜드의 데미지 트래킹과 같이 못 산다. 그래서 이 셰이더를
// 걸 때는 debug:damage_tracking = 0 이 함께 가야 하고(안 그러면 하이프랜드가
// 오버레이 경고를 띄우고 time 을 0 으로 고정한다), 그 순간부터 화면은 아무것도
// 안 바뀌어도 매 프레임 통째로 다시 그려진다. 노트북에서 배터리가 눈에 띄게 준다.
//
// hyprland.lua 의 Mod+Shift+C 는 셋을 순환하며 이 둘을 같이 맞춘다:
//   off → crt.frag(트래킹 켠 채) → crt-motion.frag(트래킹 끔)
//
// 값과 함수는 ./crt.frag 와 같다. 한 파일에 #define 으로 갈래를 두지 않은 건,
// time 을 *쓰기만 하면* 위의 대가가 따라오기 때문이다 — 쓰지 않는 갈래를 컴파일러가
// 지워 주기를 기대하는 것보다 파일이 둘인 편이 정직하다.

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time; // 셰이더가 걸린 시점부터의 초. 이 한 줄이 위의 대가를 부른다.

#define TAU 6.2831853

// ── crt.frag 와 같은 값들 ─────────────────────────────────────────────────
#define CURVE       0.10
#define EDGE_SOFT   1.5
#define VIGNETTE    0.06
#define FOCUS       0.32
#define ABERRATION  3.0
#define BLOOM       0.55
#define BLOOM_PX    5.0
#define BLOOM_CUT   0.22
#define BLOOM_KNEE  0.28
#define BLOOM_TAPS  16
#define SCAN_PX     4.0
#define SCAN_DEPTH  0.12
#define GRILLE      0.06
#define GRILLE_PX   3.0
#define BRIGHTNESS  1.12
#define TINT        vec3(1.0)

// ── 움직임 ────────────────────────────────────────────────────────────────
// 시간에 걸린 것 전부의 속도. 아래 GRAIN_HZ 와 HUM_SPEED 에 곱해지므로 이 한 줄만
// 바꾸면 움직임 전체가 같은 비율로 느려지고 빨라진다.
#define ANIM_SPEED  0.45

// 아날로그 그레인. 세기, 덩어리 크기(픽셀), 새 무늬를 뽑는 초당 횟수.
// grainAt() 이 저주파 성분을 빼기 때문에 GRAIN_PX 는 질감만 정하고 화면 전체가
// 밝아졌다 어두워지는 깜박임과는 무관하다. GRAIN_HZ 가 높은 것도 그래서다 —
// 사람이 깜박임에 제일 민감한 3~15Hz 대역을 피한다.
#define GRAIN       0.030
#define GRAIN_PX    1.5
#define GRAIN_HZ    40.0

// 잡티를 어디에 얹을지의 배분. 더하기만 쓰면 밝은 곳에서 묻히고, 곱하기만 쓰면
// 검정에서 사라진다(검정 × 무엇이든 검정). 섞어야 화면 전체에 고르게 얹힌다.
#define GRAIN_ADD   1.0    // 어두운 곳에서의 몫
#define GRAIN_MUL   1.4    // 밝은 곳에서의 몫

// 험 바 — 전원 주파수와 수직 주사가 어긋나서 생기는 밝기 띠. 화면 전체를 훑는
// 사인이 아니라 좁은 띠 하나가 천천히 굴러 내려간다. 어느 순간에도 화면의
// HUM_WIDTH 만큼만 영향을 받으므로, 눈이 "화면이 변한다"가 아니라 "무언가가
// 지나간다"로 읽는다. 한 바퀴에 1 / (HUM_SPEED × ANIM_SPEED) 초.
//
// 터미널(순검정 배경)보다 값이 낮다. 데스크톱은 벽지와 창으로 이미 밝아서 같은
// 세기면 띠가 훨씬 도드라진다.
#define HUM_LIFT    0.015  // 띠 안에서 검정이 뜨는 양 — 이게 있어야 보인다
#define HUM         0.04   // 띠 안에서 밝은 픽셀이 더 밝아지는 비율
#define HUM_GLOW    1.2    // 띠 안에서 블룸이 번지는 비율
#define HUM_WIDTH   0.10   // 띠 높이(화면 높이 비율)
#define HUM_SPEED   0.25   // 초당 몇 화면분 내려가는지


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// 밴딩 없는 해시(Dave Hoskins 계열). sin(dot(...)) 쪽은 좌표가 커지면 무늬가
// 반복돼서, 잡티가 아니라 격자처럼 보인다.
float hash(vec2 p, float seed) {
    vec3 v = fract(vec3(p.x, p.y, p.x) * 0.1031 + seed * 0.1731);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}

// 값 노이즈. 격자에서 뽑아 부드럽게 이어 붙이므로 픽셀 단위 모래알이 아니라
// GRAIN_PX 크기의 덩어리가 된다.
float vnoise(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i,                  seed), hash(i + vec2(1.0, 0.0), seed), f.x),
               mix(hash(i + vec2(0.0, 1.0), seed), hash(i + vec2(1.0, 1.0), seed), f.x), f.y);
}

// 하이패스 그레인. 잔 노이즈에서 네 배 굵은 노이즈를 빼면 넓은 면적의 평균이 0 에
// 수렴한다 — 화면이 통째로 밝아졌다 어두워지는 성분이 그 저주파였다.
float grainAt(vec2 p, float seed) {
    return vnoise(p / GRAIN_PX, seed) - vnoise(p / (GRAIN_PX * 4.0), seed + 7.0);
}

vec3 gun(vec2 uv, vec2 px) {
    vec2 drift = (uv - 0.5) * ABERRATION * px * 2.0;
    vec3 sharp = vec3(
        texture(tex, uv + drift).r,
        texture(tex, uv).g,
        texture(tex, uv - drift).b
    );

    vec2 r = px * 0.8;
    vec3 soft = texture(tex, uv + vec2( r.x,  r.y)).rgb
              + texture(tex, uv + vec2(-r.x, -r.y)).rgb
              + texture(tex, uv + vec2( r.x, -r.y)).rgb
              + texture(tex, uv + vec2(-r.x,  r.y)).rgb;

    return mix(sharp, soft * 0.25, FOCUS);
}

vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < BLOOM_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(BLOOM_TAPS));
        float a  = fi * 2.39996323;
        float w  = exp(-r * r * 1.8);
        vec3  c  = texture(tex, uv + vec2(cos(a), sin(a)) * r * BLOOM_PX * px).rgb;
        float l  = dot(c, vec3(0.2126, 0.7152, 0.0722));
        sum  += c * smoothstep(BLOOM_CUT, BLOOM_CUT + BLOOM_KNEE, l) * w;
        wsum += w;
    }
    return sum / wsum;
}

// 효과 하나를 화면에 얹는다. gain 은 밝은 픽셀에서의 몫, lift 는 검정에서의 몫이다.
// 한쪽만 쓰면 반드시 한쪽에서 안 보인다(위 GRAIN_ADD/GRAIN_MUL 주석 참고).
vec3 modulate(vec3 col, float amount, float gain, float lift) {
    return col * (1.0 + amount * gain) + vec3(amount * lift);
}

vec3 stripes(vec3 col, vec2 pix) {
    float scanAA   = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.y) / SCAN_PX);
    float grilleAA = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.x) / GRILLE_PX);

    col *= 1.0 - SCAN_DEPTH * scanAA * (0.5 + 0.5 * sin(pix.y * TAU / SCAN_PX));

    float gp = pix.x * TAU / GRILLE_PX;
    vec3 mask = 0.5 + 0.5 * vec3(sin(gp), sin(gp + TAU / 3.0), sin(gp + TAU * 2.0 / 3.0));
    return col * (1.0 - GRILLE * grilleAA * mask);
}

vec3 bezel(vec3 col, vec2 uv) {
    vec2 e = uv * (1.0 - uv.yx);
    col *= smoothstep(0.0, 1.0, pow(max(e.x * e.y, 0.0) * 30.0, VIGNETTE));

    vec2 d = min(uv, 1.0 - uv) * screen_size;
    return col * smoothstep(0.0, EDGE_SOFT, min(d.x, d.y));
}

void main() {
    vec2 px  = 1.0 / screen_size;
    vec2 uv  = curve(v_texcoord);
    vec2 pix = uv * screen_size;

    float t = time * ANIM_SPEED;

    // 험 바 위치. fract 로 감고, 감긴 좌표에서의 최단 거리로 띠를 만든다.
    float humY   = fract(uv.y + t * HUM_SPEED);
    float humD   = min(humY, 1.0 - humY);
    float humBar = exp(-(humD * humD) / (HUM_WIDTH * HUM_WIDTH));

    // 블룸 쪽을 훨씬 세게 민다. 띠가 지날 때 밝은 것 둘레가 확 번지는 게
    // 브라운관에서 실제로 눈에 띄는 부분이다.
    float humGlow = 1.0 + HUM_GLOW * humBar;

    vec3 col = gun(uv, px);
    col += bloom(uv, px) * BLOOM * humGlow;
    col  = stripes(col, pix);

    // 그레인은 GRAIN_HZ 로 계단을 밟되, 계단 사이를 smoothstep 으로 이어 붙인다.
    // 새 무늬로 툭 갈아치우면 그게 눈에 걸리는 지글거림이 된다. 좌표는 곡면이
    // 아니라 화면 픽셀이다 — 잡티는 유리 앞이 아니라 유리 자체에 있다.
    float ts = t * GRAIN_HZ;
    float g  = mix(grainAt(gl_FragCoord.xy, floor(ts)),
                   grainAt(gl_FragCoord.xy, floor(ts) + 1.0),
                   smoothstep(0.0, 1.0, fract(ts)));
    col = modulate(col, g * GRAIN, GRAIN_MUL, GRAIN_ADD);

    // 띠 밖은 humBar 가 0 이라 아무 일도 일어나지 않는다.
    col = modulate(col, humBar, HUM, HUM_LIFT);

    col  = bezel(col, uv);
    col *= BRIGHTNESS * TINT;

    fragColor = vec4(col, 1.0);
}
