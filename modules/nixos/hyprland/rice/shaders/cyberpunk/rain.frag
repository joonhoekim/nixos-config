#version 300 es
//
// rain.frag — 유리에 흐르는 빗방울. 화면이 창밖이 된다.
//
// 굴절 알맹이는 ../water/still.frag 셋과 같다 — 높이의 기울기만큼 uv 를 밀어서
// 읽는다. 그러므로 캡처 방식이 아니면 이 파일도 성립하지 않는다(../../README.md
// 의 표). 다른 것은 그 높이가 화면 전체를 덮는 파가 아니라 **점점이 흩어진
// 렌즈**라는 점이다.
//
// ── 물방울이 물방울로 보이려면 배경이 흐려야 한다 ─────────────────────────
// 이게 이 파일에서 제일 중요한 결정이다. 방울만 굴절시키고 배경을 또렷하게
// 두면 유리가 아니라 화면 위에 젤리가 붙은 것처럼 보인다. 유리에 맺힌 물이
// 물로 읽히는 것은 **방울 안이 밖보다 선명하기 때문**이고, 그러려면 밖을
// 흐려야지 안을 더 선명하게 할 방법은 없다(원본보다 선명해질 수는 없다).
//
// 그래서 FOG 가 0 이면 이 셰이더는 실패한다. 값을 아끼려고 끄고 싶어지는
// 자리이므로 여기 적어 둔다 — 끄면 싸지는 게 아니라 안 되는 것이 된다.
//
// ── 셀 격자를 쓰는 이유 ───────────────────────────────────────────────────
// 방울 하나하나를 목록으로 들고 도는 방법도 있지만, 화면을 덮으려면 수백 개가
// 필요하고 픽셀마다 그걸 다 도는 것은 값이 안 맞는다. 좌표를 격자로 잘라서
// **자기 칸과 이웃 몇 칸만** 보면 픽셀당 상수 번으로 끝난다. 대가는 한 칸에
// 방울이 하나뿐이라는 것인데, 크기와 위치를 칸마다 흩어 두면 격자인 것이
// 눈에 안 띈다.
//
// ── 겹쳐 쓰기 ─────────────────────────────────────────────────────────────
//   global-shader shaders/cyberpunk/neon.frag shaders/cyberpunk/rain.frag shaders/cyberpunk/glitch.frag
//
// ./neon.frag 을 **앞에** 두는 것이 맞는다. 간판이 먼저 타고, 그 탄 화면이
// 빗방울에 굴절돼야 창밖의 간판이 된다. 순서를 뒤집으면 굴절된 화면에서
// 채도를 재게 되는데, 방울 가장자리에서 색이 섞여 있어서 간판 판정이 흐려진다.
//
// `time` 을 읽으므로 재그리기 켬이다(../../README.md 참고).

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time;

// ── 유리 ──────────────────────────────────────────────────────────────────
// 방울 밖을 흐리는 정도. 위 머리말대로 이 값이 0 이면 효과가 성립하지 않는다.
#define FOG         0.75              // @0..1

// 흐리는 반경(픽셀). 넓힐수록 창밖이 멀어 보인다. 탭이 넷뿐이라 20 을 넘기면
// 흐림이 아니라 겹친 잔상으로 보이기 시작한다.
#define FOG_PX      4.0               // @1..20

// ── 방울 ──────────────────────────────────────────────────────────────────
// 격자의 촘촘함. 화면 세로에 칸이 몇 개 들어가는가. 방울 크기가 아니라 **간격**을
// 정하는 값이라, 여기를 키우면 방울이 작아지는 게 아니라 많아진다.
#define CELLS       9.0               // @3..30

// 칸에 방울이 있을 확률. 1 이면 모든 칸에 하나씩이라 격자가 눈에 보인다.
#define DROPS       0.62              // @0..1:0.01

// 방울 반지름(칸 기준). 0.5 면 칸을 꽉 채운다.
#define DROP        0.24              // @0.05..0.45

// 방울이 흐르는 속도. 0 이면 맺힌 채로 멈춘다. 시간을 타는 것이 이 값 하나뿐이라
// 0 에서는 재그리기도 같이 꺼진다 — `!motion` 이 그 선언이다
// (../../README.md 「손잡이가 시간을 여닫는다」).
#define FALL        0.35              // @0..2:0.01 !motion

// 흐르는 방울의 비율. 나머지는 그 자리에 맺혀만 있다. 실제 창유리에서 전부
// 흐르지는 않고, 섞여 있어야 흐르는 것이 눈에 띈다.
#define RUNNERS     0.55              // @0..1

// ── 굴절 ──────────────────────────────────────────────────────────────────
// 방울 안에서 배경이 밀리는 폭(픽셀). 방울은 볼록렌즈라 실제로는 뒤집힌 상이
// 맺히지만, 화면 한 장으로는 그걸 못 만든다 — 가운데로 당기는 것으로 흉내 낸다.
#define LENS        26.0              // @0..80

// 방울 가장자리의 흰 테. 유리에 맺힌 물의 윤곽이 보이는 것은 대부분 이 반사다.
#define RIM         0.30              // @0..1

// 가장자리에서 밀림을 0 으로 접는 폭(0..1). clampToEdge 가 테두리를 늘이는 것을
// 막는다 — ../water/still.frag 의 같은 자리와 같은 이유다.
#define EDGE_FADE   0.02

// ── 색 ────────────────────────────────────────────────────────────────────
// 유리 너머의 푸른 기. 손잡이가 아닌 vec3 는 고치고 저장하면 바로 반영된다.
#define TINT_MIX    0.12              // @0..0.5
#define TINT        vec3(0.60, 0.76, 1.00)

#define BRIGHTNESS  1.06              // @0.6..1.6


vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 한 칸의 방울이 이 자리에 남기는 것. (기울기x, 기울기y, 방울 안쪽 정도).
//
// 이웃 칸까지 봐야 하므로 칸 좌표를 밖에서 넘긴다. 자기 칸만 보면 칸 경계를
// 걸친 방울이 반쪽에서 잘려서 격자가 그대로 드러난다.
vec3 drop(vec2 st, vec2 id, float t) {
    float r = hash21(id);
    if (r > DROPS) return vec3(0.0);          // 이 칸은 비었다

    // 칸마다 크기·위치·속도를 흩어 둔다. 안 흩으면 격자가 눈에 보인다.
    float rx    = hash21(id + 13.7);
    float rs    = hash21(id + 41.3);
    float runs  = step(1.0 - RUNNERS, hash21(id + 5.1));

    float rad   = DROP * (0.55 + 0.75 * rs);
    // 흐르는 방울은 칸 안을 위에서 아래로 지나간다. 안 흐르는 것은 제자리.
    float y     = mix(0.5, fract(rs + t * FALL * (0.6 + 0.8 * rx)), runs);
    vec2  c     = id + vec2(0.15 + 0.70 * rx, y);

    vec2  d     = st - c;
    float len   = length(d) + 1e-5;
    float inside = smoothstep(rad, rad * 0.55, len);

    // 반구의 기울기. 가운데에서 0 이고 가장자리로 갈수록 가파르다 — 그래서
    // 방울 가운데는 그대로고 테두리 쪽이 크게 밀린다. 실제 물방울이 그렇다.
    vec2 slope = (d / len) * smoothstep(0.0, rad, len) * inside;

    return vec3(slope, inside);
}

void main() {
    vec2 px = 1.0 / screen_size;
    vec2 uv = v_texcoord;
    vec2 a  = aspect();

    // 셀 좌표. 가로에 화면비를 곱해야 방울이 타원이 안 된다.
    vec2 st = uv * a * CELLS;
    vec2 base = floor(st);

    // 자기 칸과 위아래 이웃. 흐르는 방울은 세로로만 칸을 넘나들므로 가로
    // 이웃까지 볼 필요가 없다 — 그 두 칸이 픽셀당 값의 3분의 1 이다.
    vec3 d0 = drop(st, base + vec2(0.0, -1.0), time);
    vec3 d1 = drop(st, base,                   time);
    vec3 d2 = drop(st, base + vec2(0.0,  1.0), time);

    vec2  slope = d0.xy + d1.xy + d2.xy;
    float ins   = clamp(d0.z + d1.z + d2.z, 0.0, 1.0);

    vec2  f = smoothstep(0.0, EDGE_FADE, uv) * smoothstep(0.0, EDGE_FADE, 1.0 - uv);
    float fade = f.x * f.y;

    // 방울은 가운데로 당긴다 — 볼록렌즈를 화면 한 장으로 흉내 내는 자리다.
    vec2 off = -slope * LENS * px * fade;

    // 방울 밖은 흐리고 안은 또렷하다. 위 머리말의 그 결정이 이 두 줄이다.
    vec3 sharp = texture(tex, uv + off).rgb;

    vec2 b = FOG_PX * px;
    vec3 blur = (texture(tex, uv + vec2( b.x,  b.y)).rgb
               + texture(tex, uv + vec2(-b.x, -b.y)).rgb
               + texture(tex, uv + vec2( b.x, -b.y)).rgb
               + texture(tex, uv + vec2(-b.x,  b.y)).rgb) * 0.25;

    vec3 col = mix(mix(sharp, blur, FOG), sharp, ins);

    // 방울 테. 안쪽 정도가 급하게 변하는 자리라 그 미분을 그대로 쓴다 —
    // 따로 거리 계산을 하지 않아도 윤곽이 나온다.
    col += RIM * ins * (1.0 - ins) * 4.0;

    col = mix(col, col * TINT * 1.3, TINT_MIX);
    col *= BRIGHTNESS;

    fragColor = vec4(col, 1.0);
}
