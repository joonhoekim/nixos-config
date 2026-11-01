#version 300 es
//
// river.frag — 흐르는 강. 화면 전체가 한 방향으로 흘러간다.
//
// 공유하는 결정은 ./still.frag. 여기는 방향(FBM)·늘어남(STRETCH)·휨(WARP)이 다르다.
// 설계와 비용: docs/hyprland-shaders.md

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time;

// ── 흐름 ──────────────────────────────────────────────────────────────────
// 흐르는 방향(라디안). 0 이 오른쪽, 1.571(π/2) 이 **아래**다 — v_texcoord 가
// 좌상단 원점이라 y 가 아래쪽으로 양수인 것에 주의. 폭포처럼 쓰려면 π/2,
// 강처럼 쓰려면 0 근처.
#define ANGLE       0.35              // @0..6.283:0.01

// 흐르는 속도. 0 이면 무늬가 얼어붙고, 시간을 타는 것이 이 값 하나뿐이라
// 재그리기도 같이 꺼진다 (`!motion` — ../../README.md 참고).
#define FLOW        0.30              // @0..2:0.01 !motion

// 결의 촘촘함.
#define SCALE       5.0               // @1..20

// 흐름 방향으로 늘이는 비율. 1 이면 등방이라 방향이 안 보이고, 8 이면 국수처럼
// 길어진다. 강으로 보이는 구간은 3~5 근처였다.
#define STRETCH     3.5               // @1..8

// 굽이. 낮은 주파수 결을 따라 좌표를 미는 폭. 0 이면 나란한 줄무늬, 1 을 넘기면
// 흐름 방향을 알아볼 수 없게 뭉개진다.
#define WARP        0.35              // @0..1

// 옥타브. 상수여야 해서 표시를 안 단다.
#define OCTAVES     4

// ── 굴절 ──────────────────────────────────────────────────────────────────
// ./still.frag 보다 조금 크다. 강은 애초에 잔잔한 것을 흉내 내지 않으므로
// 흔들림이 그 자리에 있는 게 맞고, 대신 상시로 걸어 두기에는 잔잔한 쪽이 낫다.
#define REFRACT     2.6               // @0..8
#define EDGE_FADE   0.02

// ── 글자 지키기 ───────────────────────────────────────────────────────────
// 뜻과 이유는 ./still.frag 의 같은 자리에 적어 뒀다. 굴절이 큰 만큼
// 기본값을 조금 더 올린다.
#define PRESERVE    0.78              // @0..1
#define PRESERVE_PX 6.0               // @2..16
#define BUSY_TAPS   8
#define BUSY_LO     0.06
#define BUSY_HI     0.30

// ── 표면 ──────────────────────────────────────────────────────────────────
// 수면 스트리크. 흐름 방향으로 누운 결의 마루에만 얹는 흰 선이다. 강에서 빛이
// 부서지는 게 점이 아니라 선인 것은 결이 늘어나 있기 때문이라, 여기서는 따로
// 만들 것 없이 늘어난 높이를 그대로 쓰면 된다.
#define STREAK      0.22              // @0..1

// 스트리크가 시작되는 높이와 폭. 좁게 잡아야 마루만 걸리고, 넓히면 물 전체가
// 뿌옇게 밝아진다.
#define STREAK_CUT  0.55
#define STREAK_KNEE 0.30

// ── 색 ────────────────────────────────────────────────────────────────────
// 강물은 바다보다 탁하고 초록을 띈다. 색을 바꾸려면 TINT 줄을 고치고 저장하면
// 된다(vec3 는 손잡이가 안 된다 — Sources/Knobs.swift).
#define TINT_MIX    0.16              // @0..0.6
#define TINT        vec3(0.45, 0.78, 0.68)

#define BRIGHTNESS  1.02              // @0.6..1.4


vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// (값, ∂/∂x, ∂/∂y). 삼차 보간의 도함수 du = 6f(1-f) 를 그대로 쓴다 — 유한차분의 계단은
// 굴절이 기울기를 직접 써서 화면에 그대로 보인다.
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

// 기울기에도 주파수를 곱해야 연쇄법칙이 맞는다(안 곱하면 잔결이 안 밀린다).
// 배율 2.03: 정확히 2 배면 옥타브 격자가 같은 자리에 겹쳐 격자 무늬가 비친다.
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

// 흐름 좌표계에서 잰 높이와 uv 로 되돌린 기울기. 행렬 대신 내적 둘인 건 mat2 열 우선 규약의
// 부호 실수를 피하려는 것이고, 회전의 역은 전치다.
vec3 river(vec2 uv, float t) {
    vec2 dir  = vec2(cos(ANGLE), sin(ANGLE));
    vec2 perp = vec2(-dir.y, dir.x);

    vec2 p = uv * aspect() * SCALE;
    vec2 q = vec2(dot(p, dir), dot(p, perp));
    q.x /= STRETCH;            // 흐름 방향으로 늘인다
    q.x -= t;                  // 흐른다

    // 등고선을 따라(기울기를 90도 돌려) 민다 — 기울기 방향으로 밀면 결이 뭉개진다.
    vec3 base = fbmd(q * 0.5);
    vec2 qw = q + WARP * vec2(base.z, -base.y);

    vec3 h = fbmd(qw);

    // 늘인 만큼 x 성분도 되돌린다. 워프의 야코비안은 굴절에 필요 없어 생략한다.
    vec2 gq = vec2(h.y / STRETCH, h.z);
    return vec3(h.x, dir * gq.x + perp * gq.y);
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

    vec3 s = river(uv, time * FLOW);
    vec2 g = s.yz;

    vec2  f = smoothstep(0.0, EDGE_FADE, uv) * smoothstep(0.0, EDGE_FADE, 1.0 - uv);
    float fade = f.x * f.y;
    if (PRESERVE > 0.001) fade *= 1.0 - busy(uv, px) * PRESERVE;

    vec2 off = -g * REFRACT * px * fade;
    vec3 col = texture(tex, uv + off).rgb;

    col = mix(col, col * TINT * 1.35, TINT_MIX);

    // 결이 흐름 방향으로 늘어나 있어 높이만 잘라도 선으로 나온다.
    col += STREAK * smoothstep(STREAK_CUT, STREAK_CUT + STREAK_KNEE, s.x);

    col *= BRIGHTNESS;
    fragColor = vec4(col, 1.0);
}
