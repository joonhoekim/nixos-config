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
//
// 이 셋을 고를 때 걸리는 함정이 둘 있고, 서로 반대 방향이다:
//
//   덩어리가 크면  잡음 에너지가 저주파로 몰린다. 넓은 면적이 같이 밝아졌다
//                  어두워지니, 눈은 그걸 질감이 아니라 "화면이 깜박인다"로
//                  읽는다. 부드럽게 만들려고 2.5px 로 키웠다가 이걸 만났다.
//   덩어리가 작으면 픽셀 단위 백색 잡음이 되어 지글거린다. 처음 버전이 그랬다.
//
// 그래서 크기로 줄타기하는 대신 grainAt() 에서 저주파 성분을 아예 빼 버린다.
// 덕분에 GRAIN_PX 는 질감만 정하고, 깜박임과는 무관해진다.
//
// GRAIN_HZ 가 24 → 60 인 것도 같은 이유다. 저주파를 걷어내고 나면 빠른 쪽이
// 필름 그레인에 가깝고, 사람이 깜박임에 가장 민감한 3~15Hz 대역에서도 벗어난다.
// 실제 갱신 빈도는 여기에 ANIM_SPEED 가 곱해진 값이다.
#define GRAIN       0.075
#define GRAIN_PX    1.4
#define GRAIN_HZ    60.0

// 험 바 — 전원 주파수와 수직 주사가 어긋나서 생기는 밝기 띠.
//
// 화면 전체를 밝혔다 어둡게 하면 오래 보기 피곤하다. 그래서 글로우에만 건다:
// 본문 글자와 배경의 밝기는 고정이고, 글자 둘레 번짐과 커서 꼬리만 숨을 쉰다.
// 세기가 앞보다 큰 건 기준이 화면 전체가 아니라 글로우 성분이기 때문이고,
// 실제 화면에서 오르내리는 폭은 전보다 작다. 0 이면 완전히 끈다.
#define HUM         0.10
#define HUM_SPEED   0.12

// ── 커서 잔상 ─────────────────────────────────────────────────────────────
// 진짜 인광체 지속은 만들 수 없다 — ghostty 가 셰이더에 주는 건 현재 프레임
// 하나뿐이라 이전 화면을 섞을 방법이 없다. 커서만 예외다: 직전 위치와 바뀐
// 시각을 유니폼으로 주므로, 지나간 자리에 남는 꼬리는 진짜로 그릴 수 있다.
// 이 셰이더에서 시간적인 잔상은 여기 하나뿐이고 나머지는 전부 공간적 번짐이다.
#define TRAIL       0.55   // 세기. 0 이면 끔
#define TRAIL_SEC   0.22   // 꼬리가 사라지는 데 걸리는 시간(초)
#define TRAIL_W     1.0    // 꼬리 두께. 1 이면 커서 크기 그대로, 1.5 면 반 배 굵게
#define TRAIL_GLOW  0.8    // 꼬리 둘레 번짐 반경(커서 반경 배수)

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

// 하이패스 그레인. 잔 노이즈에서 네 배 굵은 노이즈를 빼면 넓은 면적의 평균이
// 0 에 수렴한다 — 화면이 통째로 밝아졌다 어두워지는 성분이 바로 그 저주파였고,
// 여기서 없애 두면 세기를 올려도 깜박임으로 번지지 않는다. 남는 건 눈이 질감
// 으로 읽는 고주파뿐이다.
//
// 검정 배경에도 보여야 하므로 더하기로 쓴다. 곱하기로 하면 검정 × 무엇이든
// 검정이라 배경에서 그레인이 통째로 사라진다.
float grainAt(vec2 p, float seed) {
    return vnoise(p / GRAIN_PX, seed) - vnoise(p / (GRAIN_PX * 4.0), seed + 7.0);
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

// 점 p 에서 선분 ab 까지의 거리.
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// 커서가 지나간 자리에 남는 꼬리. 좌표는 ghostty 규약대로 xy 가 커서의 -X/+Y
// 모서리(Y 가 위로 자라는 좌표계에서 왼쪽 위)이고 zw 가 폭과 높이다.
vec3 cursorTrail(vec2 p) {
    vec2 cur = vec2(iCurrentCursor.x  + iCurrentCursor.z  * 0.5,
                    iCurrentCursor.y  - iCurrentCursor.w  * 0.5);
    vec2 prv = vec2(iPreviousCursor.x + iPreviousCursor.z * 0.5,
                    iPreviousCursor.y - iPreviousCursor.w * 0.5);

    // 커서가 깜빡이거나 색이 바뀌어도 iTimeCursorChange 는 갱신된다. 그때까지
    // 빛나면 제자리에서 맥동하는 꼴이라 제일 피곤하다 — 실제로 움직였을 때만
    // 그린다. 분기 대신 곱으로 처리해서 아래 fwidth 의 미분이 흐트러지지 않게 한다.
    float moved = smoothstep(1.0, 4.0, length(cur - prv));

    // 나이가 들수록 빠르게 죽는다. 인광체가 지수적으로 꺼지는 것과 비슷하다.
    float age  = clamp((iTime - iTimeCursorChange) / TRAIL_SEC, 0.0, 1.0);
    float fade = (1.0 - age) * (1.0 - age);

    // 거리를 커서 반폭/반높이로 나눈 공간에서 잰다. 그러면 d 의 단위가 "커서
    // 몇 개분"이 되고, 꼬리가 커서와 같은 두께·같은 비율로 끌린다. 예전처럼
    // min(폭,높이) 로 반경 하나를 잡으면 블록 커서(가로 짧고 세로 긴)에서
    // 가로폭에 맞춘 가느다란 지렁이가 나온다.
    vec2 half_ = max(iCurrentCursor.zw * 0.5 * TRAIL_W, vec2(1.0));
    float d = sdSegment(p / half_, prv / half_, cur / half_) - 1.0;

    float core = 1.0 - smoothstep(0.0, 0.35, d);           // 지나간 궤적 자체
    float halo = exp(-max(d, 0.0) / TRAIL_GLOW);           // 그 둘레 번짐

    return iCurrentCursorColor.rgb * (core * 0.55 + halo * 0.45) * TRAIL * fade * moved;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 px = 1.0 / iResolution.xy;
    vec2 uv = curve(fragCoord * px);

    // 스캔라인·그릴·커서 꼬리는 전부 곡면 좌표로 재므로 화면과 같이 휜다.
    vec2 pix = uv * iResolution.xy;

    float t = iTime * ANIM_SPEED;

    // 험 바는 글로우 성분에만 곱한다. 밑의 글자와 배경은 건드리지 않는다.
    float hum = 1.0 + HUM * sin((uv.y + t * HUM_SPEED) * TAU);

    vec3 col = gun(uv, px);
    col += bloom(uv, px) * BLOOM * hum;
    col += cursorTrail(pix) * hum;

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
    float ts = t * GRAIN_HZ;
    float g  = mix(grainAt(fragCoord, floor(ts)),
                   grainAt(fragCoord, floor(ts) + 1.0),
                   smoothstep(0.0, 1.0, fract(ts)));
    col += g * GRAIN;

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
