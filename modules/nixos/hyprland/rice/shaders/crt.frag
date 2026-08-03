#version 300 es
//
// crt.frag — 화면 전체에 거는 브라운관. 하이프랜드의 decoration:screen_shader 다.
//
// 니리 때문에 못 하던 그것이다: 렌더링이 다 끝난 화면 한 장을 받아 마지막에 한 번
// 더 그린다. 창 하나가 아니라 바탕·바·창·커서가 전부 같은 유리 뒤로 들어간다.
//
// ── 이 파일과 crt-motion.frag ─────────────────────────────────────────────
// 둘로 나뉜 이유는 취향이 아니라 데미지 트래킹이다. 하이프랜드는 화면에서 실제로
// 바뀐 조각만 다시 그리는데, 화면 셰이더가 `time` 유니폼을 쓰면 매 프레임 그림이
// 달라질 수 있으므로 그 최적화를 통째로 꺼야 한다(debug:damage_tracking = 0).
// 안 끄면 하이프랜드가 오버레이로 경고를 띄우고 time 을 0 으로 고정해 버린다.
//
// 그래서 시간이 필요 없는 것 — 곡률, 초점, 색수차, 블룸, 스캔라인, 그릴, 비네트 —
// 만 여기 있다. 정지 화면에서는 비용이 0 에 수렴한다. 그레인과 험 바처럼 흐르는
// 것은 옆 파일에 있고, 그건 배터리를 먹는다.
//
// ── 뿌리 ─────────────────────────────────────────────────────────────────
// ../../../../shared/ghostty/shaders/crt.glsl 을 옮겨왔다. 터미널 창 하나에 걸던
// 것이라 값이 그대로면 화면 전체에서는 과하다 — 아래 주석에 어디를 왜 낮췄는지
// 적어 뒀다. 셰이더토이 규약(mainImage/iChannel0/iResolution)이 아니라 하이프랜드
// 규약(main/tex/screen_size)이라는 것 말고, 수식은 같다.
//
// 고치면 저장하는 즉시 반영된다. 다시 읽히게 하려면 Mod+Shift+C 로 두 번 돌리거나
//   hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/crt.frag

precision highp float; // mediump 면 안 된다 — 2560 같은 픽셀 좌표에서 정밀도가
                       // 한 픽셀보다 굵어져 스캔라인이 뭉개진다.

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size; // 이 모니터의 픽셀 크기. fullSize / screenSize 도 같은 값이다.

#define TAU 6.2831853

// ── 형태 ──────────────────────────────────────────────────────────────────
// 배럴 왜곡. 터미널에서는 0.18 이었다. 화면 전체에서는 창 테두리와 바가 같이
// 휘어서 같은 값이 훨씬 세게 보이므로 낮춘다.
#define CURVE       0.10

// 화면 가장자리가 죽는 폭(픽셀). 곡선을 계단으로 만들지 않을 만큼만.
#define EDGE_SOFT   1.5

// 비네트 지수. pow(밝기, VIGNETTE) 라 *클수록* 가장자리가 깊게 죽고, 0 이면
// 아예 없다 — 지수를 0 에 붙일수록 pow 가 1 로 평평해지기 때문이다.
// 터미널(../../../../shared/ghostty/shaders/crt.glsl)의 0.25 를 그대로 들고
// 왔더니 화면 전체에서는 너무 셌다. 거기서는 가장자리가 창 테두리 바깥의 여백일
// 뿐이지만 여기서는 바와 트레이가 늘 그 자리에 있어서, 어두워지면 안 되는 것들이
// 어두워진다. 1/5 로 줄인 값이다.
#define VIGNETTE    0.06

// ── 광학 ──────────────────────────────────────────────────────────────────
// 초점. 0 이면 원본 그대로, 1 이면 한 픽셀쯤 뭉갠다. 터미널에서는 0.5 였지만
// 여기서는 UI 잔글씨가 화면 전체에 있어서 가독성 대가가 훨씬 크다.
#define FOCUS       0.32

// 색수차. 화면 가장자리에서 R 과 B 가 벌어지는 폭(픽셀). 가운데는 0 이다.
#define ABERRATION  3.0

// 블룸. 반경(픽셀)과, 어느 밝기부터 어느 폭에 걸쳐 번지기 시작하는지.
//
// **이 셰이더에서 제일 비싼 부분이다** — 픽셀당 16 탭이라 화면 전체로 치면
// 프레임마다 수천만 번의 텍스처 페치가 된다. 통합 그래픽에서 프레임이 모자라면
// 여기부터 줄인다: BLOOM 0.0 이면 루프가 도는 건 같으니 TAPS 를 8 로 낮추거나
// bloom() 호출 줄을 지우는 쪽이 실제로 싸다.
#define BLOOM       0.55
#define BLOOM_PX    5.0
#define BLOOM_CUT   0.22
#define BLOOM_KNEE  0.28
#define BLOOM_TAPS  16

// ── 줄무늬 ────────────────────────────────────────────────────────────────
// 스캔라인 주기(픽셀)와 깊이. 주기를 픽셀로 잡아야 HiDPI 에서도 같은 굵기다.
#define SCAN_PX     4.0
#define SCAN_DEPTH  0.12

// 인광체 그릴. R/G/B 서브픽셀 줄무늬. 스캔라인과 겹치면 방충망처럼 보여서
// 존재만 느껴질 만큼 얕게 둔다.
#define GRILLE      0.06
#define GRILLE_PX   3.0

// ── 색 ────────────────────────────────────────────────────────────────────
// 스캔라인과 그릴이 깎아낸 만큼 되돌린다.
#define BRIGHTNESS  1.12

// 인광체 색. vec3(1.0) 이면 팔레트 그대로다. 이 한 줄로 룩이 하나 더 나온다 —
// 호박색 vec3(1.15, 0.85, 0.45), 녹색 vec3(0.65, 1.20, 0.70).
#define TINT        vec3(1.0)


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// 전자총 셋을 따로 쏘고(가운데에서 어긋남이 0), 거기에 초점 흐림을 섞는다.
// 대각 4탭 텐트라 7탭이면 끝난다.
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

// 골든앵글 나선 탭. 반경을 sqrt 로 잡아야 표본이 면적에 고르게 퍼진다. 방향을
// 링으로 돌면 밝은 글자 둘레에 별 모양 결이 남는데, 나선은 그게 안 생긴다.
vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < BLOOM_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(BLOOM_TAPS));
        float a  = fi * 2.39996323;          // 황금각
        float w  = exp(-r * r * 1.8);        // 가우시안 가중
        vec3  c  = texture(tex, uv + vec2(cos(a), sin(a)) * r * BLOOM_PX * px).rgb;
        float l  = dot(c, vec3(0.2126, 0.7152, 0.0722));
        sum  += c * smoothstep(BLOOM_CUT, BLOOM_CUT + BLOOM_KNEE, l) * w;
        wsum += w;
    }
    return sum / wsum;
}

// 스캔라인과 인광체 그릴. 곡면 좌표(pix)로 재므로 화면과 같이 휜다.
vec3 stripes(vec3 col, vec2 pix) {
    // 한 화면 픽셀 안에 줄무늬가 얼마나 들어가는지. 반 주기를 넘으면 애초에
    // 표현할 수 없어서 모아레만 남는다 — 그런 곳에서는 줄무늬를 서서히 지운다.
    // 곡률이 강한 가장자리가 특히 그렇다. 없는 편이 지저분한 것보다 낫다.
    float scanAA   = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.y) / SCAN_PX);
    float grilleAA = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.x) / GRILLE_PX);

    col *= 1.0 - SCAN_DEPTH * scanAA * (0.5 + 0.5 * sin(pix.y * TAU / SCAN_PX));

    float gp = pix.x * TAU / GRILLE_PX;
    vec3 mask = 0.5 + 0.5 * vec3(sin(gp), sin(gp + TAU / 3.0), sin(gp + TAU * 2.0 / 3.0));
    return col * (1.0 - GRILLE * grilleAA * mask);
}

// 유리 안쪽 — 비네트와 화면 가장자리. 곡률 바깥을 if 로 잘라내면 곡선이 계단으로
// 남으므로 EDGE_SOFT 픽셀에 걸쳐 부드럽게 죽인다.
vec3 bezel(vec3 col, vec2 uv) {
    // uv 가 화면 밖이면 곱이 음수라 pow 가 NaN 을 뱉는다. 하드 컷을 없앤 자리를
    // 여기서 막는다.
    vec2 e = uv * (1.0 - uv.yx);
    col *= smoothstep(0.0, 1.0, pow(max(e.x * e.y, 0.0) * 30.0, VIGNETTE));

    vec2 d = min(uv, 1.0 - uv) * screen_size;
    return col * smoothstep(0.0, EDGE_SOFT, min(d.x, d.y));
}

void main() {
    vec2 px  = 1.0 / screen_size;
    vec2 uv  = curve(v_texcoord);

    // 스캔라인과 그릴은 곡면 좌표로 재므로 화면과 같이 휜다.
    vec2 pix = uv * screen_size;

    vec3 col = gun(uv, px);
    col += bloom(uv, px) * BLOOM;
    col  = stripes(col, pix);
    col  = bezel(col, uv);
    col *= BRIGHTNESS * TINT;

    // 화면 셰이더의 결과는 그대로 프레임버퍼로 간다. 곡률 바깥은 위에서 검정으로
    // 죽여 뒀고, 거기가 그대로 브라운관 베젤이 된다 — 그러니 알파는 항상 1 이다.
    fragColor = vec4(col, 1.0);
}
