#version 300 es
//
// river.frag — 흐르는 강. 화면 전체가 한 방향으로 흘러간다.
//
// 셋이 공유하는 결정 — 왜 굴절인지, 가장자리(clampToEdge)와 글자를 어떻게
// 다루는지, 커서와 배터리에서 무엇을 못 고치는지 — 는 ./still.frag
// 머리말에 있다. 여기는 다른 점만 적는다.
//
// ── 잔물결과 무엇이 다른가 ────────────────────────────────────────────────
// 셋 다 "높이의 기울기만큼 uv 를 민다"는 같은 알맹이를 쓴다. 강을 강으로 만드는
// 것은 그 높이를 만드는 방식 셋이다.
//
// **하나. 방향이 있다.** ./still.frag 는 사인 넷이 서로 마주 보며 제자리에서
// 어른거리지만, 강은 무늬 전체가 한 쪽으로 밀려간다. 사인으로는 이게 안 된다 —
// 사인을 밀면 무늬가 통째로 미끄러지는 게 눈에 보여서 물이 아니라 스크롤하는
// 벽지가 된다. 그래서 여기부터 FBM 이다. 노이즈는 밀어도 무늬가 계속 새로 생겨서
// 미끄러지는 게 안 보인다.
//
// **둘. 늘어나 있다.** 흐르는 물의 결은 흐름 방향으로 길게 늘어진다. STRETCH 가
// 노이즈 좌표를 흐름 축으로만 눌러서 그 이방성을 만든다. 이게 없으면 방향만
// 있고 결이 둥글어서 "흐르는 안개"처럼 보인다.
//
// **셋. 휘어 있다.** 강은 곧게 흐르지 않는다. WARP 가 낮은 주파수의 결을 따라
// 좌표를 밀어서(도메인 워프) 소용돌이와 굽이를 만든다. FBM 을 두 번 재는 값이
// 여기서 나가지만, 이게 없으면 결이 나란한 줄무늬라 강이 아니라 빗질 자국이다.
//
// ── 기울기는 해석적으로 ───────────────────────────────────────────────────
// FBM 의 기울기를 유한차분으로 내면 FBM 을 세 번 재야 한다. 아래 noised() 는
// 값과 기울기를 **한 번에** 돌려주므로 한 번이면 된다. 삼차 보간의 도함수를
// 그대로 쓴 것이라 차분과 달리 근사도 아니고 계단도 없다.
//
// 그래서 이 파일의 픽셀당 비용은 FBM 두 번 = 노이즈 여덟 번 = 해시 32 번이다.
// 전부 ALU 라 ../crt/crt.frag 의 픽셀당 20여 회 텍스처 페치보다 싸게 나올 것으로
// 보지만, ../../README.md 의 대가 표에 실제로 잰 값이 있어야 한다.

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

// 값 노이즈와 그 기울기를 한 번에. (값, ∂/∂x, ∂/∂y).
//
// 삼차 보간 u = f²(3-2f) 의 도함수 du = 6f(1-f) 를 그대로 쓴다. 유한차분과
// 달리 근사가 아니라서 표본을 더 뜰 필요가 없고, 차분 간격이 남기는 계단도
// 안 생긴다 — 굴절은 기울기를 직접 쓰므로 그 계단이 화면에 그대로 보인다.
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

// 옥타브를 쌓는다. 기울기에도 주파수를 곱해 줘야 연쇄법칙이 맞는다 —
// 안 곱하면 잔결의 기울기가 큰 결에 묻혀서 결이 있는데 안 밀리는 물이 된다.
//
// 배율이 2.0 이 아니라 2.03 인 것은, 정확히 2 배면 옥타브들의 격자가 같은
// 자리에서 겹쳐서 격자 무늬가 비쳐 보이기 때문이다.
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

// 흐름 좌표계에서 잰 강의 높이와, 그 기울기를 uv 좌표계로 되돌린 것.
//
// 좌표 변환을 행렬 대신 내적 둘로 쓴 이유는 mat2 의 열 우선 규약에서 부호를
// 틀리기 쉬워서다. 여기서는 q.x 가 흐름 방향 성분, q.y 가 그 직교 성분인 게
// 눈에 보인다. 기울기를 되돌리는 것도 같은 두 축으로 되짚으면 된다 —
// 회전은 직교변환이라 역이 전치다.
vec3 river(vec2 uv, float t) {
    vec2 dir  = vec2(cos(ANGLE), sin(ANGLE));
    vec2 perp = vec2(-dir.y, dir.x);

    vec2 p = uv * aspect() * SCALE;
    vec2 q = vec2(dot(p, dir), dot(p, perp));
    q.x /= STRETCH;            // 흐름 방향으로 늘인다
    q.x -= t;                  // 흐른다

    // 굽이. 낮은 주파수 결의 **등고선을 따라** 민다(기울기를 90도 돌린 방향).
    // 등고선을 따라 밀어야 소용돌이가 되고, 기울기 방향으로 밀면 결이 그냥
    // 뭉개진다.
    vec3 base = fbmd(q * 0.5);
    vec2 qw = q + WARP * vec2(base.z, -base.y);

    vec3 h = fbmd(qw);

    // 기울기를 q 로, 다시 uv 로 되돌린다. 늘인 만큼 x 성분도 되돌려야 한다.
    // 워프의 기울기까지 정확히 따라가려면 야코비안이 하나 더 붙지만, 굴절에
    // 필요한 것은 결의 방향이지 미분의 정확한 값이 아니라 여기서 끊는다.
    vec2 gq = vec2(h.y / STRETCH, h.z);
    return vec3(h.x, dir * gq.x + perp * gq.y);
}

// 이 자리가 얼마나 잔글씨로 붐비는가. 최대가 아니라 평균인 이유, 탭이 나선인
// 이유는 ./still.frag 의 같은 함수에 적어 뒀다.
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

    // 마루에만 얹는 스트리크. 결이 흐름 방향으로 늘어나 있으므로 높이만 잘라도
    // 선으로 나온다 — 방향을 따로 줄 필요가 없다.
    col += STREAK * smoothstep(STREAK_CUT, STREAK_CUT + STREAK_KNEE, s.x);

    col *= BRIGHTNESS;
    fragColor = vec4(col, 1.0);
}
