// crt.glsl — 브라운관. ghostty 의 custom-shader(Shadertoy 포맷)로 돈다.
//
// 목표는 완벽 재현이 아니라 감성이다. 그래서 진짜 CRT 에 있는 것 중에서도
// 거칠게 보이는 것은 일부러 약하게 두거나 지운다 — 눈이 "저건 흉내다"라고
// 느끼는 지점은 대개 세기가 아니라 결이 거친 데서 온다.
//
// 뿌리는 Maxim Samoliuk 의 Hyprland 화면 셰이더(MIT, _temp/ricing-examples/
// space_dots/.other/orig.frag)지만 터미널용으로 다시 짰다. 원본과 다른 곳:
//
//   블룸    원본은 24방향 × 4단계 = 픽셀당 96탭이다. 저자 본인도 그걸 감당
//           못 해서 activate.sh 에서 패널을 1024x768 로 떨어뜨렸다. 여기서는
//           골든앵글 나선 16탭에 가우시안 가중이다 — 방향을 링으로 돌면 밝은
//           글자 둘레에 별 모양 결이 남는데, 나선은 그게 안 생긴다.
//   그레인  원본은 픽셀마다 백색 잡음을 새로 뽑는다. 그러면 모래를 뿌린 것처럼
//           보이고 주사율이 곧 속도가 된다. 여기서는 격자에서 뽑아 보간한 값
//           노이즈를, 초당 GRAIN_HZ 번 갱신하되 그 사이도 이어 붙인다.
//   깜빡임  원본은 sin(60.0 * time) 이라 주사율을 상수로 박아야 하고 틀리면
//           밝기가 널뛴다(원본 주석의 경고 그대로다). 여기서는 천천히 굴러
//           내려가는 험 바다 — 주사율과 무관하다.
//   색수차  원본은 화면 전체에 고정폭이다. 여기서는 가운데가 0 이고 가장자리로
//           갈수록 벌어진다. 실제 전자총 정렬 오차가 그렇고, 본문을 읽는
//           가운데가 덜 흐려진다.
//   가장자리 원본은 곡률 바깥을 if 로 잘라낸다. 그러면 곡선이 계단으로 남는다.
//           여기서는 한 픽셀 반에 걸쳐 부드럽게 죽인다.
//
// 값은 전부 아래 #define 에 모아뒀다. 고치고 저장한 뒤 apps/rice-term 을 다시
// 돌리거나 ctrl+shift+, 를 누르면 열려 있는 창에 바로 반영된다.

#define TAU 6.2831853

// ── 형태 ──────────────────────────────────────────────────────────────────
// 배럴 왜곡. 0 이면 평면, 0.3 쯤이면 어안이다.
#define CURVE       0.13

// 화면 가장자리가 죽는 폭(픽셀). 곡선을 계단으로 만들지 않을 만큼만 있으면 된다.
#define EDGE_SOFT   1.5

// 비네트 지수. 작을수록 가장자리가 깊게 죽는다.
#define VIGNETTE    0.28

// ── 광학 ──────────────────────────────────────────────────────────────────
// 초점. 진짜 브라운관은 픽셀 경계가 칼같지 않다. 0 이면 원본 그대로, 1 이면
// 한 픽셀쯤 뭉갠다. 부드러움에 제일 크게 기여하는 값이고, 글자가 흐려지는
// 것도 여기가 제일 크다.
#define FOCUS       0.35

// 색수차. 화면 가장자리에서 R 과 B 가 벌어지는 폭(픽셀).
#define ABERRATION  1.1

// 블룸. 반경(픽셀), 그리고 어느 밝기부터 번지기 시작해서 어느 폭에 걸쳐
// 완전히 번지는지. 임계값을 칼로 자르면 글자 굵기에 따라 번짐이 튀어서,
// KNEE 폭만큼 서서히 들어오게 했다.
#define BLOOM       0.90
#define BLOOM_PX    9.0
#define BLOOM_CUT   0.22
#define BLOOM_KNEE  0.28

// ── 줄무늬 ────────────────────────────────────────────────────────────────
// 스캔라인 주기(픽셀)와 깊이. 주기를 픽셀로 잡아야 HiDPI 에서도 같은 굵기다.
// 3 픽셀이면 한 주기에 표본이 세 개뿐이라 곡률이 닿는 곳마다 모아레가 되므로
// 4 로 벌리고 깊이를 낮췄다.
#define SCAN_PX     4.0
#define SCAN_DEPTH  0.15

// 인광체 그릴. R/G/B 서브픽셀 줄무늬. 스캔라인과 겹치면 방충망처럼 보여서
// 존재만 느껴질 만큼 얕게 둔다.
#define GRILLE      0.07
#define GRILLE_PX   3.0

// ── 움직임 ────────────────────────────────────────────────────────────────
// 시간에 걸린 것 전부의 속도. 아래 GRAIN_HZ 와 HUM_SPEED 에 곱해지므로 이 한
// 줄만 바꾸면 움직임 전체가 같은 비율로 느려지고 빨라진다.
#define ANIM_SPEED  0.30

// 아날로그 그레인. 세기, 덩어리 크기(픽셀), 새 무늬를 뽑는 초당 횟수.
// 덩어리를 픽셀보다 크게 잡아야 모래알이 아니라 잡티로 보인다.
#define GRAIN       0.045
#define GRAIN_PX    2.5
#define GRAIN_HZ    24.0

// 험 바 — 전원 주파수와 수직 주사가 어긋나서 생기는 밝기 띠. 세기와 이동 속도.
#define HUM         0.020
#define HUM_SPEED   0.12

// ── 색 ────────────────────────────────────────────────────────────────────
// 스캔라인과 그릴이 깎아낸 만큼 되돌린다.
#define BRIGHTNESS  1.16

// 인광체 색. vec3(1.0) 이면 터미널 팔레트 그대로다. 이 한 줄만 바꾸면 새 룩이
// 하나 나온다 — 호박색 vec3(1.15, 0.85, 0.45), 녹색 vec3(0.65, 1.20, 0.70).
#define TINT        vec3(1.0)


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// 밴딩 없는 해시(Dave Hoskins 계열). sin(dot(...)) 쪽은 좌표가 커지면 무늬가
// 반복돼서, 잡티가 아니라 격자처럼 보인다 — 부드러움을 깨는 흔한 원인이다.
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
    return mix(mix(hash(i,                   seed), hash(i + vec2(1.0, 0.0), seed), f.x),
               mix(hash(i + vec2(0.0, 1.0),  seed), hash(i + vec2(1.0, 1.0), seed), f.x), f.y);
}

// 전자총 셋을 따로 쏘고(가운데에서 어긋남이 0), 거기에 초점 흐림을 섞는다.
// 대각 4탭 텐트라 7탭이면 끝난다.
vec3 gun(vec2 uv, vec2 px) {
    vec2 drift = (uv - 0.5) * ABERRATION * px * 2.0;
    vec3 sharp = vec3(
        texture(iChannel0, uv + drift).r,
        texture(iChannel0, uv).g,
        texture(iChannel0, uv - drift).b
    );

    vec2 r = px * 0.8;
    vec3 soft = texture(iChannel0, uv + vec2( r.x,  r.y)).rgb
              + texture(iChannel0, uv + vec2(-r.x, -r.y)).rgb
              + texture(iChannel0, uv + vec2( r.x, -r.y)).rgb
              + texture(iChannel0, uv + vec2(-r.x,  r.y)).rgb;

    return mix(sharp, soft * 0.25, FOCUS);
}

// 골든앵글 나선 16탭. 반경을 sqrt 로 잡아야 표본이 면적에 고르게 퍼진다.
vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / 16.0);
        float a  = fi * 2.39996323;          // 황금각
        float w  = exp(-r * r * 1.8);        // 가우시안 가중
        vec3  c  = texture(iChannel0, uv + vec2(cos(a), sin(a)) * r * BLOOM_PX * px).rgb;
        float l  = dot(c, vec3(0.2126, 0.7152, 0.0722));
        sum  += c * smoothstep(BLOOM_CUT, BLOOM_CUT + BLOOM_KNEE, l) * w;
        wsum += w;
    }
    return sum / wsum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 px = 1.0 / iResolution.xy;
    vec2 uv = curve(fragCoord * px);

    vec3 col = gun(uv, px);
    col += bloom(uv, px) * BLOOM;

    // 스캔라인과 그릴은 곡면 좌표로 재므로 화면과 같이 휜다.
    vec2 pix = uv * iResolution.xy;

    // 한 화면 픽셀 안에 줄무늬가 얼마나 들어가는지. 반 주기를 넘으면 애초에
    // 표현할 수 없어서 모아레만 남는다 — 그런 곳에서는 줄무늬를 서서히 지운다.
    // 곡률이 강한 가장자리가 특히 그렇다. 없는 편이 지저분한 것보다 낫다.
    float scanAA   = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.y) / SCAN_PX);
    float grilleAA = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.x) / GRILLE_PX);

    col *= 1.0 - SCAN_DEPTH * scanAA * (0.5 + 0.5 * sin(pix.y * TAU / SCAN_PX));

    float gp = pix.x * TAU / GRILLE_PX;
    vec3 mask = 0.5 + 0.5 * vec3(sin(gp), sin(gp + TAU / 3.0), sin(gp + TAU * 2.0 / 3.0));
    col *= 1.0 - GRILLE * grilleAA * mask;

    // 그레인은 GRAIN_HZ 로 계단을 밟되, 계단 사이를 smoothstep 으로 이어 붙인다.
    // 새 무늬로 툭 갈아치우면 그게 눈에 걸리는 지글거림이 된다.
    float t  = iTime * ANIM_SPEED;
    float ts = t * GRAIN_HZ;
    float g  = mix(vnoise(fragCoord / GRAIN_PX, floor(ts)),
                   vnoise(fragCoord / GRAIN_PX, floor(ts) + 1.0),
                   smoothstep(0.0, 1.0, fract(ts)));
    col += (g - 0.5) * GRAIN;

    col *= 1.0 + HUM * sin((uv.y + t * HUM_SPEED) * TAU);

    // uv 가 화면 밖이면 곱이 음수라 pow 가 NaN 을 뱉는다. 하드 컷을 없앤 자리를
    // 여기서 막는다.
    vec2 e = uv * (1.0 - uv.yx);
    col *= smoothstep(0.0, 1.0, clamp(pow(max(e.x * e.y, 0.0) * 30.0, VIGNETTE), 0.0, 1.0));

    // 화면 가장자리. 하드 컷 대신 EDGE_SOFT 픽셀에 걸쳐 죽인다. 덤으로 위쪽
    // fwidth 가 분기 밖에 있게 되어 미분값이 정의된다.
    vec2 d = min(uv, 1.0 - uv) * iResolution.xy;
    col *= smoothstep(0.0, 1.0, clamp(min(d.x, d.y) / EDGE_SOFT, 0.0, 1.0));

    col *= BRIGHTNESS * TINT;

    // 알파는 1 이다. 곡률로 잘라낸 가장자리가 창 밖으로 비쳐 보이면 유리 안쪽이
    // 아니라 구멍처럼 보인다 — 그래서 crt.conf 는 background-opacity 도 1 이다.
    fragColor = vec4(col, 1.0);
}
