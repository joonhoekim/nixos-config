// crt.glsl — 브라운관(ghostty custom-shader, Shadertoy 포맷). 뿌리는 Maxim Samoliuk 의 Hyprland 셰이더(MIT,
// _temp/ricing-examples/space_dots/.other/orig.frag)고, 원본과 다른 곳과 그 이유: docs/ghostty-shaders.md
// 고친 뒤 apps/rice/term 을 다시 돌리거나 ctrl+shift+, 로 열린 창에 바로 반영된다.

#define TAU 6.2831853

// 배럴 왜곡. 0 이면 평면, 0.3 쯤이면 어안.
#define CURVE       0.18              // @0..0.4

// 가장자리가 죽는 폭(픽셀). 곡선이 계단이 안 될 만큼만.
#define EDGE_SOFT   1.5

// 비네트 지수. 작을수록 가장자리가 깊게 죽는다.
#define VIGNETTE    0.25              // @0..0.6

// 초점. 0 이면 원본, 1 이면 한 픽셀쯤 뭉갠다 — 부드러움과 글자 흐림에 제일 크게 듣는다.
#define FOCUS       0.5               // @0..1

// 색수차: 가장자리에서 R 과 B 가 벌어지는 폭(픽셀).
#define ABERRATION  4                 // @0..8

// 블룸. 임계값을 칼로 자르면 글자 굵기에 따라 번짐이 튀어서 KNEE 폭만큼 서서히 들어온다.
#define BLOOM       0.9               // @0..1.5
#define BLOOM_PX    5.0               // @1..16
#define BLOOM_CUT   0.22              // @0..1
#define BLOOM_KNEE  0.28              // @0.01..0.6

// 스캔라인 주기(픽셀이라 HiDPI 에서도 같은 굵기)와 깊이. 3 픽셀이면 곡률이 닿는 곳마다 모아레가 된다.
#define SCAN_PX     4.0               // @2..8
#define SCAN_DEPTH  0.15              // @0..0.5

// 인광체 그릴. 스캔라인과 겹치면 방충망처럼 보여서 얕게 둔다.
#define GRILLE      0.07              // @0..0.3
#define GRILLE_PX   3.0

// 움직임 전체의 속도. GRAIN_HZ 와 HUM_SPEED 에 곱해진다.
#define ANIM_SPEED  0.45              // @0.05..2

// 그레인: 세기, 덩어리(픽셀), 초당 새 무늬. 저주파는 grainAt() 이 빼므로 GRAIN_PX 는 질감만 정한다.
// GRAIN_HZ 가 높은 건 깜박임에 가장 민감한 3~15Hz 를 피하려는 것이다(실제 빈도는 × ANIM_SPEED).
#define GRAIN       0.035             // @0..0.15
#define GRAIN_PX    1.5
#define GRAIN_HZ    40.0              // @5..60

// 더하기만 쓰면 잡티가 글자 위에서 묻히고(밝을수록 상대 대비가 작다) 곱하기만 쓰면 검정에서 죽는다.
// 섞어야 배경과 글자에 고르게 얹힌다. GRAIN_MUL 을 0 으로 두면 배경에만 깔린다.
#define GRAIN_ADD   1.0    // 어두운 곳에서의 몫
#define GRAIN_MUL   1.4    // 밝은 곳에서의 몫

// 험 바: 좁은 띠 하나가 굴러 내려간다(한 바퀴 1 / (HUM_SPEED × ANIM_SPEED) 초). 화면 전체에 걸면 깜박임으로 읽힌다.
// 순검정 배경에서는 곱하기가 아무것도 못 하므로 띠를 보이게 하는 건 HUM_LIFT 다.
#define HUM_LIFT    0.02              // @0..0.1 띠 안에서 검정이 뜨는 양 — 이게 있어야 보인다
#define HUM         0.05              // @0..0.3 띠 안에서 밝은 픽셀이 더 밝아지는 비율
#define HUM_GLOW    1.5               // @0..4 띠 안에서 글로우가 번지는 비율
#define HUM_WIDTH   0.10              // @0.02..0.4 띠 높이(화면 높이 비율)
#define HUM_SPEED   0.25              // @0..1 초당 몇 화면분 내려가는지

// 커서 꼬리 — 이 셰이더의 유일한 시간적 잔상. ghostty 는 현재 프레임 하나만 주지만 커서는
// 직전 위치(iPreviousCursor)와 바뀐 시각(iTimeCursorChange)을 따로 준다.
#define TRAIL       0.55              // @0..1.5 세기. 0 이면 끔
#define TRAIL_SEC   0.22              // @0.05..1 꼬리가 사라지는 데 걸리는 시간(초)
#define TRAIL_W     1.0               // @0.5..3 꼬리 두께. 1 이면 커서 크기 그대로, 1.5 면 반 배 굵게
#define TRAIL_GLOW  0.8               // @0..3 꼬리 둘레 번짐 반경(커서 반경 배수)

// 스캔라인과 그릴이 깎아낸 만큼 되돌린다.
#define BRIGHTNESS  1.14              // @0.6..1.8

// 인광체 색. 호박색 vec3(1.15, 0.85, 0.45), 녹색 vec3(0.65, 1.20, 0.70).
#define TINT        vec3(1.0)


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// Dave Hoskins 계열 해시. sin(dot(...)) 해시는 좌표가 커지면 무늬가 반복돼 격자처럼 보인다.
float hash(vec2 p, float seed) {
    vec3 v = fract(vec3(p.x, p.y, p.x) * 0.1031 + seed * 0.1731);
    v += dot(v, v.yzx + 33.33);
    return fract((v.x + v.y) * v.z);
}

float vnoise(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i,                   seed), hash(i + vec2(1.0, 0.0), seed), f.x),
               mix(hash(i + vec2(0.0, 1.0),  seed), hash(i + vec2(1.0, 1.0), seed), f.x), f.y);
}

// 하이패스: 네 배 굵은 노이즈를 빼서 넓은 면적의 평균을 0 으로 — 그 저주파가 화면 전체 깜박임으로 보인다.
float grainAt(vec2 p, float seed) {
    return vnoise(p / GRAIN_PX, seed) - vnoise(p / (GRAIN_PX * 4.0), seed + 7.0);
}

// 전자총 셋(가운데에서 어긋남 0)에 대각 4탭 초점 흐림을 섞는다 — 모두 7탭.
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

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// ghostty 규약: xy 는 커서의 왼쪽 위 모서리(Y 가 위로 자라는 좌표계), zw 는 폭·높이.
vec3 cursorTrail(vec2 p) {
    vec2 cur = vec2(iCurrentCursor.x  + iCurrentCursor.z  * 0.5,
                    iCurrentCursor.y  - iCurrentCursor.w  * 0.5);
    vec2 prv = vec2(iPreviousCursor.x + iPreviousCursor.z * 0.5,
                    iPreviousCursor.y - iPreviousCursor.w * 0.5);

    // 깜빡임·색 변화에도 iTimeCursorChange 가 갱신된다 — 실제로 움직였을 때만 그려야 제자리 맥동이 없다.
    float moved = smoothstep(1.0, 4.0, length(cur - prv));

    float age  = clamp((iTime - iTimeCursorChange) / TRAIL_SEC, 0.0, 1.0);
    float fade = (1.0 - age) * (1.0 - age);

    // 조건이 유니폼만으로 정해져 화면 전체가 같은 쪽으로 분기하므로(워프 분기 없음) 일찍 나가도 안전하다.
    // 커서가 멈춰 있으면 TRAIL_SEC 뒤부터 늘 여기로 빠진다.
    if (TRAIL * fade * moved <= 0.0) return vec3(0.0);

    // 커서 반폭/반높이로 나눈 공간에서 재야 꼬리가 커서와 같은 비율이 된다. 반경 하나(min)로 재면
    // 세로로 긴 블록 커서에서 가느다란 지렁이가 나온다.
    vec2 half_ = max(iCurrentCursor.zw * 0.5 * TRAIL_W, vec2(1.0));
    float d = sdSegment(p / half_, prv / half_, cur / half_) - 1.0;

    float core = 1.0 - smoothstep(0.0, 0.35, d);           // 지나간 궤적 자체
    float halo = exp(-max(d, 0.0) / TRAIL_GLOW);           // 그 둘레 번짐

    return iCurrentCursorColor.rgb * (core * 0.55 + halo * 0.45) * TRAIL * fade * moved;
}

// 곱하기는 검정에서 죽고 더하기는 밝은 곳에서 묻히므로 둘 다 쓴다. gain 은 밝은 픽셀의 몫, lift 는 검정의 몫.
vec3 modulate(vec3 col, float amount, float gain, float lift) {
    return col * (1.0 + amount * gain) + vec3(amount * lift);
}

// 스캔라인과 인광체 그릴. 곡면 좌표(pix)로 재므로 화면과 같이 휜다.
vec3 stripes(vec3 col, vec2 pix) {
    // 한 픽셀에 반 주기 넘게 들어가면(곡률이 강한 가장자리) 모아레만 남으므로 줄무늬를 서서히 지운다.
    float scanAA   = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.y) / SCAN_PX);
    float grilleAA = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.x) / GRILLE_PX);

    col *= 1.0 - SCAN_DEPTH * scanAA * (0.5 + 0.5 * sin(pix.y * TAU / SCAN_PX));

    float gp = pix.x * TAU / GRILLE_PX;
    vec3 mask = 0.5 + 0.5 * vec3(sin(gp), sin(gp + TAU / 3.0), sin(gp + TAU * 2.0 / 3.0));
    return col * (1.0 - GRILLE * grilleAA * mask);
}

// edge 는 곡률 안쪽 1, 바깥 0 인 마스크 — 알파에도 필요해서 밖으로 낸다.
vec3 bezel(vec3 col, vec2 uv, out float edge) {
    // uv 가 화면 밖이면 곱이 음수라 pow 가 NaN 을 뱉는다.
    vec2 e = uv * (1.0 - uv.yx);
    col *= smoothstep(0.0, 1.0, pow(max(e.x * e.y, 0.0) * 30.0, VIGNETTE));

    // if 로 자르지 않아야 fwidth 를 쓰는 stripes 가 분기 밖에 있어 미분값이 정의된다.
    vec2 d = min(uv, 1.0 - uv) * iResolution.xy;
    edge = smoothstep(0.0, EDGE_SOFT, min(d.x, d.y));
    return col * edge;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 px = 1.0 / iResolution.xy;
    vec2 uv = curve(fragCoord * px);

    vec2 pix = uv * iResolution.xy;

    // 포커스 없는 창도 가끔 한 장씩 그려지는데(ghostty 문서의 "deceptive frames"), iTime 이 뛴 채라
    // 뚝뚝 끊겨 보인다. 그래서 시간을 세우고 띠를 지운다.
    float live = float(iFocus > 0);

    float t = iTime * ANIM_SPEED * live;

    float humY   = fract(uv.y + t * HUM_SPEED);
    float humD   = min(humY, 1.0 - humY);
    float humBar = exp(-(humD * humD) / (HUM_WIDTH * HUM_WIDTH)) * live;

    float humGlow = 1.0 + HUM_GLOW * humBar;

    vec3 col = gun(uv, px);
    col += bloom(uv, px) * BLOOM * humGlow;
    col += cursorTrail(pix) * humGlow;

    col = stripes(col, pix);

    // 새 무늬로 툭 갈아치우면 지글거리므로 계단 사이를 smoothstep 으로 잇는다.
    float ts = t * GRAIN_HZ;
    float g  = mix(grainAt(fragCoord, floor(ts)),
                   grainAt(fragCoord, floor(ts) + 1.0),
                   smoothstep(0.0, 1.0, fract(ts)));
    col = modulate(col, g * GRAIN, GRAIN_MUL, GRAIN_ADD);

    col = modulate(col, humBar, HUM, HUM_LIFT);

    float edge;
    col = bezel(col, uv, edge);
    col *= BRIGHTNESS * TINT;

    // 곡률 안쪽만 터미널 알파를 따라가야 background-opacity 가 산다. 바깥까지 비치면 창에 구멍이 뚫린 것처럼
    // 보이므로 1 로 못 박는다 — 불투명한 검정이 곧 베젤이다.
    fragColor = vec4(col, mix(1.0, texture(iChannel0, uv).a, edge));
}
