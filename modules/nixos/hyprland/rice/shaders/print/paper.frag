#version 300 es
//
// paper.frag — 전자잉크. 화면을 종이로 만든다. 읽으려고 만든 룩이다.
//
// 시간을 안 읽어 재그리기가 꺼진다. 가독성 쪽 룩이라 다른 셰이더와 반대로 SHARP 로 날을 세운다.
// 혼자 거는 것이 맞다(앞칸의 색과 빛을 다시 뺀다). 설계: docs/hyprland-shaders.md

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;

// ── 탈색 ──────────────────────────────────────────────────────────────────
// 색을 빼는 정도. 1 이면 완전한 회색조다. 0.9 를 기본으로 둔 것은 문법 강조색이
// 아주 희미하게라도 남는 편이 코드를 읽기에 낫기 때문이다 — 완전히 빼면 주석과
// 문자열이 같은 회색이 된다.
#define GRAY        0.90              // @0..1

// ── 잉크와 종이 ───────────────────────────────────────────────────────────
// 종이의 흰 곳과 잉크의 검은 곳. 위 머리말의 그 둘이다. 사이는 선형으로 편다.
#define PAPER       0.93              // @0.6..1
#define INK         0.12              // @0..0.4

// 종이의 따뜻한 기. 손잡이가 아닌 vec3 는 고치고 저장하면 바로 반영된다.
#define PAPER_TINT  vec3(1.00, 0.98, 0.93)

// 명암. 계조를 좁힌 만큼 가운데를 세워 줘야 글자가 바탕에서 떨어진다.
// pow 지수라 1.0 이면 그대로다.
#define CONTRAST    1.18              // @0.5..2.5

// ── 날 ────────────────────────────────────────────────────────────────────
// 언샵 마스크의 세기. 이웃 넷의 평균과의 차이를 도로 더한다 — 위 머리말대로
// 이 파일에서만 흐림의 반대로 간다.
//
// 0.8 을 넘기면 글자 둘레에 흰 테가 보이기 시작한다. 인쇄물에서는 그걸
// 언샵 헤일로라 하고, 조금은 오히려 또렷해 보이지만 넘치면 티가 난다.
#define SHARP       0.45              // @0..1.5

// 날을 세우는 반경(픽셀). 1 이 본문 획 굵기에 가깝다. 키우면 글자가 아니라
// 창 테두리에 테가 생긴다.
#define SHARP_PX    1.0               // @0.5..4

// ── 결 ────────────────────────────────────────────────────────────────────
// 종이 섬유의 얼룩. 두 겹으로 쌓아서 한 겹짜리 잡티가 아니라 뭉친 결이 되게
// 한다 — 한 겹이면 화면 잡음으로 보이고, 두 겹이면 종이로 보인다.
#define FIBER       0.030             // @0..0.12

// 결의 굵기(픽셀). 이 값이 1 에 가까우면 섬유가 아니라 노이즈다.
#define FIBER_PX    3.0               // @1..12

// 아주 옅은 가장자리 그늘. 전자책 단말의 유리와 테두리가 만드는 것이다.
#define SHADE       0.06              // @0..0.3


float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 종이 결에는 기울기가 필요 없어 값만 낸다.
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i),               hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec2 px  = 1.0 / screen_size;
    vec2 uv  = v_texcoord;
    vec2 pix = uv * screen_size;

    vec3 src = texture(tex, uv).rgb;

    // 언샵 마스크는 탈색 전에 걸어야 색 경계에서도 날이 선다.
    vec2 r = SHARP_PX * px;
    vec3 avg = (texture(tex, uv + vec2( r.x, 0.0)).rgb
              + texture(tex, uv + vec2(-r.x, 0.0)).rgb
              + texture(tex, uv + vec2(0.0,  r.y)).rgb
              + texture(tex, uv + vec2(0.0, -r.y)).rgb) * 0.25;
    vec3 c = src + (src - avg) * SHARP;

    c = mix(c, vec3(luma(c)), GRAY);

    // 명암을 세운 뒤 접는다 — 반대 순서면 좁혀 놓은 구간에 pow 를 걸어 효과가 거의 없다.
    c = pow(clamp(c, 0.0, 1.0), vec3(CONTRAST));
    c = mix(vec3(INK), vec3(PAPER), c);

    // 종이 색. 잉크 쪽은 거의 안 물들고 흰 쪽만 따뜻해지도록, 밝기로 가중한다.
    c *= mix(vec3(1.0), PAPER_TINT, luma(c));

    // 자리마다 고정이라 화면이 안 바뀌면 이것도 안 바뀐다.
    float fib = vnoise(pix / FIBER_PX) * 0.65
              + vnoise(pix / (FIBER_PX * 2.7)) * 0.35;
    c *= 1.0 - FIBER * (fib - 0.5) * 2.0;

    vec2 e = uv * (1.0 - uv);
    c *= 1.0 - SHADE * (1.0 - smoothstep(0.0, 0.06, min(e.x, e.y)));

    fragColor = vec4(c, 1.0);
}
