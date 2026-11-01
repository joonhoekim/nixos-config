#version 300 es
//
// glitch.frag — 가끔 터지는 신호 오류. 데이터모시와 RGB 분리.
//
// 칸마다 주사위를 굴려 아무 일도 없는 구간이 진짜 0 이 되게 한다(약한 상시 지직거림은 고장으로 보인다).
// 밀림은 fract() 로 감는다(어긋난 띠가 반대편에서 이어지는 게 이 효과다). 체인 마지막 칸용.

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time;

// ── 언제 터지나 ───────────────────────────────────────────────────────────
// 초당 주사위를 몇 번 굴리는가. 높이면 잘게 자주, 낮추면 드물고 길게.
#define RATE        1.0               // @0.1..24

// 그중 몇이 터지는가. 1 이면 늘 터진 상태라 위 머리말의 "아무 일도 안 일어나는
// 구간"이 없어진다 — 그러라고 둔 상한이 아니라 끝까지 밀어 볼 수 있게 둔 것이다.
//
// 0 이면 burst() 가 늘 0 이라 밀림도 찢김도 밝기 튐도 없고, 남는 RGB 분리는
// 시간을 안 탄다 — 정말로 아무것도 안 움직인다. 그래서 `!motion` 이다
// (../../README.md 「손잡이가 시간을 여닫는다」).
#define DENSITY     0.12              // @0..1:0.01 !motion

// 칸 안에서 잦아드는 빠르기. 크면 탁 치고 빠지고, 작으면 칸 끝까지 끈다.
#define DECAY       5.0               // @0.5..16

// ── 어떻게 터지나 ─────────────────────────────────────────────────────────
// 가로 띠 수. 화면을 몇 겹으로 잘라서 따로 밀 것인가.
#define ROWS        28.0              // @4..120

// 띠가 밀리는 폭(화면 폭 기준). 0.08 이면 화면의 8% 다. 이보다 크면 어긋난 게
// 아니라 다른 화면이 끼어든 것처럼 보인다.
#define SHIFT       0.055             // @0..0.3:0.005

// 밀리는 띠의 비율. 1 이면 모든 띠가 밀려서 화면이 통째로 빗질된 것처럼 되고,
// 낮으면 몇 줄만 튄다. 몇 줄만 튀는 쪽이 훨씬 사고처럼 보인다.
#define ROW_HIT     0.35              // @0..1

// ── RGB 분리 ──────────────────────────────────────────────────────────────
// 늘 걸려 있는 색 어긋남(픽셀). 0 이 아닌 것이 이 파일의 성격이다 — 터지지
// 않는 동안에도 화면이 아주 조금 싸구려 신호처럼 보여야, 터졌을 때 그게 같은
// 화면에서 일어난 일로 읽힌다.
#define SPLIT       0.8               // @0..6

// 터졌을 때 그 몇 배가 되는가.
#define SPLIT_BURST 9.0               // @1..30

// ── 찢김 ──────────────────────────────────────────────────────────────────
// 터질 때 한 줄이 통째로 어긋나 흐르는 것. 띠 밀림과 달리 한 자리에만 생기고
// 폭이 훨씬 크다. 0 이면 없다.
#define TEAR        0.55              // @0..1

// 찢긴 줄의 두께(화면 높이 기준).
#define TEAR_H      0.035             // @0.002..0.2:0.001

// 터진 순간 밝기가 튀는 정도. 신호가 끊길 때 실제로 그렇다.
#define FLASH       0.18              // @0..1


float hash11(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// step() 이라 0 이 진짜 0 이다 — smoothstep 이면 상시 지직거림으로 돌아간다.
float burst(float t) {
    float tick = floor(t * RATE);
    float on   = step(1.0 - DENSITY, hash11(tick));
    float k    = fract(t * RATE);
    return on * exp(-k * DECAY);
}

void main() {
    vec2 px = 1.0 / screen_size;
    vec2 uv = v_texcoord;

    float t    = time;
    float tick = floor(t * RATE);
    float amp  = burst(t);

    // 띠 번호에 tick 을 섞어야 칸마다 다른 띠가 걸린다(안 섞으면 늘 같은 줄만 튄다).
    float row  = floor(uv.y * ROWS);
    float r1   = hash21(vec2(row, tick));
    float hit  = step(1.0 - ROW_HIT, r1);
    float dx   = (hash21(vec2(row, tick + 7.0)) - 0.5) * 2.0 * SHIFT * amp * hit;

    // 칸마다 한 자리, 두께 안에 들면 훨씬 크게 민다.
    float ty   = hash11(tick + 3.0);
    float tin  = step(abs(uv.y - ty), TEAR_H * 0.5);
    dx += (hash11(tick + 11.0) - 0.5) * 0.5 * TEAR * amp * tin;

    vec2 suv = vec2(fract(uv.x + dx), uv.y);

    float sp = SPLIT * (1.0 + (SPLIT_BURST - 1.0) * amp) * px.x;
    vec3 col = vec3(
        texture(tex, vec2(fract(suv.x + sp), suv.y)).r,
        texture(tex, suv).g,
        texture(tex, vec2(fract(suv.x - sp), suv.y)).b
    );

    // 밀린 띠에서만 튀게 해서 화면 전체가 번쩍이지 않게 한다.
    col += FLASH * amp * (hit * 0.6 + tin);

    fragColor = vec4(col, 1.0);
}
