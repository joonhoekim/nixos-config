#version 300 es
//
// crt.frag — 화면 전체에 거는 브라운관. 하이프랜드의 decoration:screen_shader 다.
//
// 니리 때문에 못 하던 그것이다: 렌더링이 다 끝난 화면 한 장을 받아 마지막에 한 번
// 더 그린다. 창 하나가 아니라 바탕·바·창·커서가 전부 같은 유리 뒤로 들어간다.
//
// ── 이 파일과 crt-motion.frag ─────────────────────────────────────────────
// 둘로 나뉜 이유는 취향이 아니라 debug:vfr 이다. 하이프랜드는 VFR 이 켜져 있으면
// 화면에 바뀐 것이 없을 때 프레임을 아예 안 그린다. `time` 유니폼을 쓰는 셰이더는
// 거기서 멈춰서 마우스를 움직여야 한 칸씩 흐르므로, 흐르는 것이 있는 셰이더는
// VFR 을 꺼야 하고 — 그때부터 정지 화면도 주사율대로 계속 그린다.
//
// 그래서 시간이 필요 없는 것 — 곡률, 초점, 색수차, 블룸, 스캔라인, 그릴, 비네트 —
// 만 여기 있다. 이 파일은 VFR 을 켜 둔 채로 돌 수 있어서 정지 화면 비용이 0 에
// 수렴한다. 그레인과 험 바처럼 흐르는 것은 옆 파일에 있고, 그건 배터리를 먹는다.
//
// 데미지 트래킹은 이 갈래와 무관하게 둘 다 꺼야 한다(debug:damage_tracking = 0).
// 아래 curve()·gun()·bloom() 이 자기 픽셀 밖을 읽기 때문이다 — 바뀐 사각형만 다시
// 합성하면 그 바깥 이웃이 낡는다. 자세한 건 ../../../../../apps/rice-crt 머리말.
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

// 커서 위치. 0..1 로 정규화돼 있고, 이 모니터 안에서의 좌표다(멀티 모니터에서
// 각 출력이 자기 좌표를 받는다). **곡률을 먹기 전 텍스처 좌표계**라, 아래에서
// curve() 를 통과한 uv 와 직접 비교하는 것이 맞는다 — 커서도 화면과 같이 휘어서
// 텍스처 안에 이미 그려져 있기 때문이다.
//
// 이 유니폼은 문서에 없다. 0.56 의 renderToOutputInternal() 이 스크린 셰이더에
// 넘기는 것 중 하나이고(src/render/OpenGL.cpp), 클릭 이력까지 딸려 온다 —
// 그쪽은 ./crt-motion.frag 에서 쓴다. 조사 기록은 _temp/ricing/ 에 있다.
//
// **debug:damage_tracking = 0 일 때만 값이 들어온다.** 아니면 (0,0) 으로 고정되고
// 하이프랜드가 셰이더를 걸 때 경고 오버레이를 띄운다. 이 파일은 어차피 곡률·
// 색수차·블룸 때문에 트래킹을 꺼야 하므로 추가로 치르는 값은 없다. `time` 과 달리
// VFR 은 건드리지 않는다 — 커서가 움직이면 그 자체가 다시 그릴 이유가 된다.
uniform vec2 pointer_position;

#define TAU 6.2831853

// ── 형태 ──────────────────────────────────────────────────────────────────
// 배럴 왜곡. 터미널에서는 0.18 이었다. 화면 전체에서는 창 테두리와 바가 같이
// 휘어서 같은 값이 훨씬 세게 보이므로 낮춘다.
//
// 0.20 까지 올려 봤다가 되돌렸다. 유리는 더 그럴듯해지지만 대가가 둘이다.
// 하나는 잘림 — curve() 는 화면을 밖으로 밀기만 하고 줄이지는 않아서 귀퉁이의
// 4% 쯤이 베젤 아래로 들어간다(밀림이 uv.x²·uv.y² 에 붙어 있어 가장자리
// *가운데*는 그대로다). 오버스캔으로 막을 수는 있다.
//
// 막을 수 없는 쪽이 진짜 이유다: **커서가 보이는 자리와 실제로 눌리는 자리가
// 벌어진다.** 커서는 텍스처에 그려진 뒤 화면과 같이 휘는데 포인터 좌표는 안
// 휘기 때문이고, 맞추려면 셰이더가 아니라 컴포지터 쪽에서 보정해야 한다.
// 곡률을 올리려면 그 보정이 먼저다.
#define CURVE       0.1               // @0..0.3

// 화면 가장자리가 죽는 폭(픽셀). 곡선을 계단으로 만들지 않을 만큼만.
#define EDGE_SOFT   1.5

// 비네트 지수. pow(밝기, VIGNETTE) 라 *클수록* 가장자리가 깊게 죽고, 0 이면
// 아예 없다 — 지수를 0 에 붙일수록 pow 가 1 로 평평해지기 때문이다.
// 터미널(../../../../shared/ghostty/shaders/crt.glsl)의 0.25 를 그대로 들고
// 왔더니 화면 전체에서는 너무 셌다. 거기서는 가장자리가 창 테두리 바깥의 여백일
// 뿐이지만 여기서는 바와 트레이가 늘 그 자리에 있어서, 어두워지면 안 되는 것들이
// 어두워진다. 1/5 로 줄인 값이다.
#define VIGNETTE    0.06              // @0..0.5

// ── 광학 ──────────────────────────────────────────────────────────────────
// 초점. 0 이면 원본 그대로, 1 이면 한 픽셀쯤 뭉갠다. 터미널에서는 0.5 였지만
// 여기서는 UI 잔글씨가 화면 전체에 있어서 가독성 대가가 훨씬 크다.
//
// 이 값은 밝기에도 직접 붙는다. 흰 글씨 획은 한두 픽셀이라 이웃이 대부분
// 검정이고, 흐리면 획의 봉우리가 1.0 에서 0.85 쯤으로 내려앉는다 — 그다음에
// 오는 스캔라인·그릴·감마가 전부 그 낮아진 값에 걸린다. "검은 바탕의 흰 글씨가
// 희미하다"의 출발점이 여기다.
#define FOCUS       0.18              // @0..0.6

// 커서 둘레에서 남길 흐림의 비율과 그 범위(화면 *높이* 기준). 0.25 면 그 자리만
// FOCUS 의 1/4 로 또렷해진다.
//
// 유리 전체를 선명하게 하면 브라운관이 아니게 되고, 전체를 흐리게 두면 잔글씨가
// 안 읽힌다. 보고 있는 자리만 맞추면 둘 다 된다 — 실제 브라운관에는 없는 동작
// 이지만, 전자총의 초점이 화면 가운데에서 가장 좋다는 것의 연장으로 보면 결이
// 아주 어긋나지도 않는다. FOCUS_NEAR 를 1.0 으로 두면 이 기능이 꺼진다.
#define FOCUS_NEAR  0.25              // @0..1
#define FOCUS_RADIUS 0.13              // @0.02..0.4

// 색수차. 화면 가장자리에서 R 과 B 가 벌어지는 폭(픽셀). 가운데는 0 이다.
#define ABERRATION  3.0               // @0..8

// 블룸. 반경(픽셀)과, 어느 밝기부터 어느 폭에 걸쳐 번지기 시작하는지.
//
// **이 셰이더에서 제일 비싼 부분이다** — 픽셀당 16 탭이라 화면 전체로 치면
// 프레임마다 수천만 번의 텍스처 페치가 된다. 통합 그래픽에서 프레임이 모자라면
// 여기부터 줄인다: BLOOM 0.0 이면 루프가 도는 건 같으니 TAPS 를 8 로 낮추거나
// bloom() 호출 줄을 지우는 쪽이 실제로 싸다.
//
// BLOOM_CUT 이 0.22 였을 때는 회색 UI 판때기가 통째로 임계값을 넘어서, 번져야
// 할 것(밝은 글자)이 아니라 화면 전체가 들려 올라갔다. 그게 "너무 밝고 대비가
// 없다"의 절반이다. 임계값을 중간톤 위로 올리고 세기를 줄였다 — 이제 흰 글자와
// 강조색만 번진다.
#define BLOOM       0.32              // @0..1
#define BLOOM_PX    5.0               // @1..16
#define BLOOM_CUT   0.45              // @0..1
#define BLOOM_KNEE  0.25              // @0.01..0.6
#define BLOOM_TAPS  16

// 이 밝기부터는 블룸을 자기 자신에게 얹지 않는다. 1.0 이면 예전처럼 전부 얹힌다.
//
// 나머지 절반이 여기 있었다. 블룸은 더하기라, 흰 창처럼 넓고 밝은 면에서는 이미
// 1.0 근처인 값에 또 더해져 프레임버퍼에서 잘려 나간다 — 밝은 곳이 통째로
// 뭉개지는 게 그것이다. 밝은 픽셀에서 블룸을 빼면 그 면은 자기 밝기를 지키고,
// 번짐은 둘레의 어두운 픽셀에만 남는다.
//
// 사실에도 이쪽이 가깝다. 브라운관에서 눈에 보이는 것은 발광면 자체가 아니라
// 그 둘레로 새어 나오는 빛이다. 검은 바탕의 흰 글씨에서는 획이 자기 밝기를
// 지키고 둘레에만 후광이 생기므로, 오히려 글씨가 더 또렷하게 뜬다.
#define BLOOM_KEEP  0.35              // @0..1

// ── 줄무늬 ────────────────────────────────────────────────────────────────
// 스캔라인 주기(픽셀)와 깊이. 주기를 픽셀로 잡아야 HiDPI 에서도 같은 굵기다.
#define SCAN_PX     4.0               // @2..8
#define SCAN_DEPTH  0.12              // @0..0.5

// 인광체 그릴. R/G/B 서브픽셀 줄무늬. 스캔라인과 겹치면 방충망처럼 보여서
// 존재만 느껴질 만큼 얕게 둔다.
#define GRILLE      0.06              // @0..0.3
#define GRILLE_PX   3.0

// ── 색 ────────────────────────────────────────────────────────────────────
// 명암. pow 지수라 1.0 이면 그대로이고, 클수록 어두운 쪽이 깊어진다. 브라운관의
// 감마가 sRGB 보다 가파른(2.4 대 2.2) 것과 방향이 같다.
//
// **얇게 쓸 것.** 1.35 로 걸어 봤다가 "밝은 곳은 더 밝고 어두운 곳은 너무 어둡다"
// 로 돌아왔다. 이 지수가 1.0 을 안 건드리는 건 맞지만, 여기까지 온 흰 글씨는
// 이미 1.0 이 아니다 — 초점 흐림이 0.85 로, 스캔라인과 그릴이 다시 0.83 배로
// 깎아 놓은 값이라 감마를 정통으로 맞는다. 검정을 눌러야 할 일은 아래
// BLOOM_KEEP 이 훨씬 정확하게 한다(원인 자리에서 막으므로). 여기는 마무리다.
#define CONTRAST    1.08              // @0.6..2

// 스캔라인과 그릴이 깎아낸 만큼 되돌린다. 둘이 겹치는 골에서는 0.83 배까지
// 내려가므로 이 보정은 실재한다 — 잠깐 1.0 으로 뒀다가 흰 글씨가 희미해졌다.
#define BRIGHTNESS  1.12              // @0.6..1.8

// 인광체 색. vec3(1.0) 이면 팔레트 그대로다. 이 한 줄로 룩이 하나 더 나온다 —
// 호박색 vec3(1.15, 0.85, 0.45), 녹색 vec3(0.65, 1.20, 0.70).
#define TINT        vec3(1.0)


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// 이 픽셀에서 쓸 초점 흐림. 커서에 가까울수록 FOCUS_NEAR 쪽으로 간다.
//
// 화면비를 곱해 두지 않으면 가로로 늘어난 타원이 된다 — uv 는 양축이 0..1 이라
// 같은 거리라도 가로가 화면비만큼 넓다. 기준을 세로로 잡는 건 FOCUS_RADIUS 가
// 모니터를 바꿔도 같은 크기로 보이게 하려는 것이다.
float focusAt(vec2 uv) {
    vec2 d = (uv - pointer_position) * vec2(screen_size.x / screen_size.y, 1.0);
    float near = exp(-dot(d, d) / (FOCUS_RADIUS * FOCUS_RADIUS));
    return mix(FOCUS, FOCUS * FOCUS_NEAR, near);
}

// 전자총 셋을 따로 쏘고(가운데에서 어긋남이 0), 거기에 초점 흐림을 섞는다.
// 대각 4탭 텐트라 7탭이면 끝난다.
vec3 gun(vec2 uv, vec2 px, float focus) {
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

    return mix(sharp, soft * 0.25, focus);
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

    vec3 col = gun(uv, px, focusAt(uv));

    // 밝은 픽셀은 자기 밝기를 지키고, 번짐은 둘레의 어두운 픽셀에만 얹힌다.
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col += bloom(uv, px) * BLOOM * (1.0 - smoothstep(BLOOM_KEEP, 1.0, lum));

    col  = stripes(col, pix);

    // 명암은 블룸이 더해진 *뒤*여야 한다. 더하기가 들어 올린 검정을 도로 누르는
    // 것이 목적이라, 앞에 두면 아무 일도 안 한 셈이 된다. 비네트(bezel) 앞인 건
    // 반대 이유다 — 가장자리가 죽는 것은 이미 곱하기라 여기서 또 깎을 필요가 없다.
    col  = pow(max(col, 0.0), vec3(CONTRAST));

    col  = bezel(col, uv);
    col *= BRIGHTNESS * TINT;

    // 화면 셰이더의 결과는 그대로 프레임버퍼로 간다. 곡률 바깥은 위에서 검정으로
    // 죽여 뒀고, 거기가 그대로 브라운관 베젤이 된다 — 그러니 알파는 항상 1 이다.
    fragColor = vec4(col, 1.0);
}
