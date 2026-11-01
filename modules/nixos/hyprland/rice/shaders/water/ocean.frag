#version 300 es
//
// ocean.frag — 파도치는 바다. 화면 전체가 너울에 실린다.
//
// 상시용이 아니다 — REFRACT 7 px 에서는 커서 어긋남이 명백하고 글자도 겨우 읽힌다.
// 공유하는 결정은 ./still.frag, 너울(사인)·잔물결(FBM)·깊이: docs/hyprland-shaders.md

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time;

// ── 너울 ──────────────────────────────────────────────────────────────────
// 큰 파의 촘촘함. 낮을수록 파장이 길다. 3 아래로 내리면 화면에 파가 한둘밖에
// 안 들어와서 파도가 아니라 화면이 통째로 기우는 것처럼 보인다.
#define SWELL       3.4               // @1..12

// 큰 파의 세기.
#define SWELL_AMP   1.00              // @0..2

// 흐르는 속도. 0 이면 너울이 얼어붙고, 시간을 타는 것이 이 값 하나뿐이라
// 재그리기도 같이 꺼진다 (`!motion` — ../../README.md 참고).
//
// 잔물결은 아래에서 이 값의 2.2 배로 돈다 — 짧은 파가 빠른 것이
// 실제 물결의 분산 관계와 방향이 같고, 같은 속도로 돌리면 두 겹이 한 덩어리로
// 붙어 움직여서 층이 안 보인다.
#define SPEED       0.35              // @0..1.5:0.01 !motion

// ── 잔물결 ────────────────────────────────────────────────────────────────
// 너울 위에 얹는 FBM 의 세기와 촘촘함. 0 이면 매끈한 기름 같은 너울만 남는다.
#define CHOP        0.55              // @0..1
#define CHOP_SCALE  9.0               // @2..30

// 옥타브. 상수여야 해서 표시를 안 단다. 너울이 큰 결을 이미 맡고 있어서 여기는
// 셋이면 된다 — 넷째 옥타브는 굴절 폭보다 잔결이 작아져 안 보이고 값만 낸다.
#define OCTAVES     3

// ── 굴절 ──────────────────────────────────────────────────────────────────
// 물 너머가 밀려 보이는 폭(픽셀). 위 머리말대로 이 값이 이 파일을 상시용이
// 아니게 만든다. 일하면서 걸어 두려면 3 아래로 내리거나 ./still.frag 로.
#define REFRACT     7.0               // @0..16
#define EDGE_FADE   0.03              // REFRACT 가 큰 만큼 접는 폭도 넓다

// ── 글자 지키기 ───────────────────────────────────────────────────────────
// 뜻과 이유는 ./still.frag 의 같은 자리에 있다. 굴절이 큰 만큼 기본을
// 거의 끝까지 올려 둔다 — 그래도 이 파일에서는 글자가 완전히 서지는 않는다.
// 밀림이 접히는 구간(PRESERVE_PX)보다 파장이 길어서, 글자 밭 전체가 함께
// 천천히 움직이는 것까지는 안 막힌다.
#define PRESERVE    0.88              // @0..1
#define PRESERVE_PX 8.0               // @2..16
#define BUSY_TAPS   8
#define BUSY_LO     0.06
#define BUSY_HI     0.30

// ── 마루 ──────────────────────────────────────────────────────────────────
// 마루에 이는 흰 거품. 임계값을 높게, 무릎을 좁게 잡아야 마루만 걸린다 —
// 넓히면 물 전체가 뿌옇게 들리고, ../crt/crt.frag 의 BLOOM_CUT 이 0.22 였을 때와
// 똑같은 실패다(번져야 할 것이 아니라 화면 전체가 밝아진다).
//
// 잔물결을 한 번 곱해서 거품이 매끈한 띠가 아니라 부서진 자국으로 남게 한다.
#define FOAM        0.35              // @0..1
#define FOAM_CUT    0.62
#define FOAM_KNEE   0.22

// 윤슬. 기울기가 빛 쪽으로 누운 자리만 튄다. 바다는 잔잔한 물보다 기울기가
// 커서 같은 TIGHT 로도 훨씬 넓게 걸리므로, 여기서는 더 좁게 잡아 둔다.
#define SHINE       0.30              // @0..1
#define SHINE_TIGHT 40.0              // @2..120

// 빛의 방향. y 는 아래쪽이 양수라(v_texcoord 가 좌상단 원점) 이 값은 왼쪽 위다.
#define LIGHT       normalize(vec3(-0.30, -0.42, 1.0))

// ── 색 ────────────────────────────────────────────────────────────────────
// 물빛을 섞는 정도(수면 쪽). 깊은 쪽은 아래 DEPTH 가 여기에 더 얹는다.
#define TINT_MIX    0.16              // @0..0.6

// 손잡이가 아니다 — vec3 는 유니폼 하나에 안 들어간다(Sources/Knobs.swift).
// 고치고 저장하면 바로 반영된다.
#define TINT        vec3(0.28, 0.60, 0.92)

// 아래로 갈수록 짙어지는 정도. 0 이면 화면 전체가 같은 깊이다.
#define DEPTH       0.35              // @0..1

// 깊은 쪽에서 붉은 채널이 빠지는 정도. 물에서 긴 파장이 먼저 흡수되는 것이라
// DEPTH 와 따로 두었다 — 짙기만 올리고 색은 안 틀고 싶을 때가 있다.
#define ABSORB      0.30              // @0..1

#define BRIGHTNESS  1.04              // @0.6..1.4


vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

// ./still.frag 의 같은 함수.
vec3 wave(vec2 p, vec2 k, float speed, float amp, float t) {
    float ph = dot(p, k) + t * speed;
    return vec3(amp * sin(ph), amp * k * cos(ph));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 유한차분이 아닌 이유는 ./river.frag 의 같은 함수.
vec3 noised(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u  = f * f * (3.0 - 2.0 * f);
    vec2 du = 6.0 * f * (1.0 - f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    float k1 = b - a, k2 = c - a, k3 = a - b - c + d;
    return vec3(a + k1 * u.x + k2 * u.y + k3 * u.x * u.y,
                du.x * (k1 + k3 * u.y),
                du.y * (k2 + k3 * u.x));
}

// 배율 2.03 과 주파수 곱의 이유는 ./river.frag 의 같은 함수.
vec3 fbmd(vec2 p) {
    vec3  s = vec3(0.0);
    float amp = 0.5, freq = 1.0;
    for (int i = 0; i < OCTAVES; i++) {
        vec3 n = noised(p * freq);
        s.x  += amp * n.x;
        s.yz += amp * freq * n.yz;
        amp  *= 0.5;
        freq *= 2.03;
    }
    return s;
}

// 파수는 서로 정수배가 아니고 대체로 같은 쪽으로 간다(흩어지면 물이 끓는 것처럼 보인다).
vec3 swell(vec2 p, float t) {
    return wave(p, vec2( 1.00,  0.26), 1.00, 1.00, t)
         + wave(p, vec2( 0.71,  0.63), 0.79, 0.62, t)
         + wave(p, vec2( 1.23, -0.41), 1.27, 0.35, t);
}

// 평균·나선 탭인 이유는 ./still.frag 의 같은 함수.
float busy(vec2 uv, vec2 px) {
    const vec3 W = vec3(0.2126, 0.7152, 0.0722);
    float c = dot(texture(tex, uv).rgb, W);
    float e = 0.0;
    for (int i = 0; i < BUSY_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(BUSY_TAPS));
        float a  = fi * 2.39996323;
        vec2  o  = vec2(cos(a), sin(a)) * r * PRESERVE_PX * px;
        e += abs(dot(texture(tex, uv + o).rgb, W) - c);
    }
    return smoothstep(BUSY_LO, BUSY_HI, e / float(BUSY_TAPS));
}

void main() {
    vec2 px = 1.0 / screen_size;
    vec2 uv = v_texcoord;
    vec2 a  = aspect();

    vec3 s = swell(uv * a * SWELL, time * SPEED) * SWELL_AMP;
    vec3 c = fbmd(uv * a * CHOP_SCALE + vec2(time * SPEED * 2.2, 0.0));

    // 잔물결 기울기엔 촘촘함이 곱해져 있어, 나누지 않으면 CHOP 을 올릴 때 잔결이 너울을 덮는다.
    float h = s.x + CHOP * c.x;
    vec2  g = s.yz + CHOP * c.yz / CHOP_SCALE;

    vec2  f = smoothstep(0.0, EDGE_FADE, uv) * smoothstep(0.0, EDGE_FADE, 1.0 - uv);
    float fade = f.x * f.y;
    if (PRESERVE > 0.001) fade *= 1.0 - busy(uv, px) * PRESERVE;

    // 마루가 저절로 뾰족해진다(기울기 방향 밀림 = 게르스트너 파의 수평 밀림).
    vec2 off = -g * REFRACT * px * fade;
    vec3 col = texture(tex, uv + off).rgb;

    float depth = uv.y;
    col = mix(col, col * TINT * 1.35, TINT_MIX + DEPTH * depth * 0.6);
    col.r *= 1.0 - ABSORB * depth;

    // 마루의 거품. 잔물결을 한 번 곱해서 매끈한 띠가 아니라 부서진 자국이 된다.
    float crest = smoothstep(FOAM_CUT, FOAM_CUT + FOAM_KNEE, h);
    col += FOAM * crest * smoothstep(0.35, 0.75, c.x);

    vec3 n = normalize(vec3(-g, 1.0));
    col += SHINE * pow(max(dot(n, LIGHT), 0.0), SHINE_TIGHT);

    col *= BRIGHTNESS;

    // 화면 셰이더의 결과는 그대로 프레임버퍼로 가므로 알파는 1 이다.
    fragColor = vec4(col, 1.0);
}
