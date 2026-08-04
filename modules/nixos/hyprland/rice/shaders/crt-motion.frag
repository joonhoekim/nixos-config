#version 300 es
//
// crt-motion.frag — ./crt.frag 에 흐르는 것 둘(그레인, 험 바)을 더한 판.
//
// **이건 공짜가 아니다.** 다만 값을 부르는 건 데미지 트래킹이 아니라 debug:vfr 이다.
// VFR 이 켜져 있으면 하이프랜드는 화면에 바뀐 것이 없을 때 프레임을 아예 안 그리고,
// 그러면 아래 `time` 도 같이 멈춘다 — 마우스를 움직여야 험 바가 한 칸 흐르는,
// 고장처럼 보이는 상태가 된다. 그래서 이 셰이더를 걸 때는 debug:vfr = false 가
// 함께 가야 하고, **그 순간부터** 화면이 정지해 있어도 주사율대로 계속 그린다.
// 노트북에서 배터리가 눈에 띄게 주는 건 여기다.
//
// 데미지 트래킹(debug:damage_tracking = 0)은 이 파일만의 대가가 아니다. ./crt.frag
// 도 똑같이 필요하다 — 곡률·색수차·블룸이 자기 픽셀 밖을 읽어서, 바뀐 사각형만
// 다시 합성하면 이웃이 낡기 때문이다. time 유무와는 상관이 없다.
//
// hyprland.lua 의 Mod+Shift+C 는 셋을 순환하며 두 축을 같이 맞춘다:
//   off(둘 다 기본값) → crt.frag(트래킹만 끔) → crt-motion.frag(둘 다 끔)
//
// 값과 함수는 ./crt.frag 와 같다. 한 파일에 #define 으로 갈래를 두지 않은 건,
// time 을 *쓰기만 하면* 위의 대가가 따라오기 때문이다 — 쓰지 않는 갈래를 컴파일러가
// 지워 주기를 기대하는 것보다 파일이 둘인 편이 정직하다.

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;
uniform float time; // 셰이더가 걸린 시점부터의 초. 이 한 줄이 위의 대가를 부른다.

// ── 포인터 ────────────────────────────────────────────────────────────────
// 문서에 없는 유니폼들이다. 0.56 의 renderToOutputInternal() 이 스크린 셰이더에
// 넘긴다(src/render/OpenGL.cpp). 전부 debug:damage_tracking = 0 을 요구하는데,
// 이 파일은 어차피 꺼야 하므로 **추가 비용이 없다**. 조사 기록은 _temp/ricing/.
//
// 좌표는 0..1 정규화, 이 모니터 로컬, 곡률을 먹기 전 텍스처 좌표계다. 그래서
// curve() 를 통과한 uv 와 그대로 비교하는 것이 맞는다.
uniform vec2  pointer_position;

// 클릭 이력. index 0 이 가장 최근이고, 새 클릭이 들어올 때마다 앞으로 밀린다
// (OpenGL.cpp 의 addLastPressToHistory). times 는 그 클릭 이후 흐른 **실제 초**라
// 아래 ANIM_SPEED 와 무관하다.
//
// 크기는 둘 다 32 다 (macros.hpp 의 POINTER_PRESSED_HISTORY_LENGTH). 위치 쪽에는
// 하이프랜드 버그가 하나 있는데, 결과적으로 이 선언에 영향이 없다:
//
//   shader->setUniform2fv(SHADER_POINTER_PRESSED_POSITIONS, pressedPos.size(), ...)
//   //                                       ↑ vec2 개수(32)가 아니라 float 개수(64)
//
// glUniform2fv 의 count 는 vec2 개수라, 64 를 넘기면 128 float 를 읽으려 든다 —
// 버퍼에는 64 개뿐이니 하이프랜드 쪽에서 자기 버퍼 밖을 읽는다(0.56.1 과 main 둘
// 다 그렇다). 다만 **넘치는 원소는 에러가 아니라 무시된다**(OpenGL ES 3.0:
// "values for all array elements beyond the end of the array will be ignored"),
// 그래서 [32] 로 선언하면 앞의 32 개가 그대로 들어오고 나머지는 버려진다.
// [32] 로 걸어 두고 debug:gl_debugging = true 로 확인했다 — GL 에러 없음.
uniform vec2  pointer_pressed_positions[32];
uniform float pointer_pressed_times[32];

#define TAU 6.2831853

// ── crt.frag 와 같은 값들 ─────────────────────────────────────────────────
// 여기를 고치면 ./crt.frag 도 같이 고쳐야 한다. 하이프랜드의 스크린 셰이더는
// 전처리를 안 거쳐서 #include 가 없다 — applyScreenShader() 가 파일을 그대로
// createProgram() 에 넘긴다. 공유할 방법이 없어서 복제다.
#define CURVE       0.10              // @0..0.3
#define EDGE_SOFT   1.5
#define VIGNETTE    0.06              // @0..0.5
#define FOCUS       0.32              // @0..0.6
#define FOCUS_NEAR  0.28              // @0..1
#define FOCUS_RADIUS 0.13              // @0.02..0.4
#define ABERRATION  3.0               // @0..8
#define BLOOM       0.32              // @0..1
#define BLOOM_PX    5.0               // @1..16
#define BLOOM_CUT   0.45              // @0..1
#define BLOOM_KNEE  0.25              // @0.01..0.6
#define BLOOM_TAPS  16
#define BLOOM_KEEP  0.35              // @0..1
#define SCAN_PX     4.0               // @2..8
#define SCAN_DEPTH  0.12              // @0..0.5
#define GRILLE      0.06              // @0..0.3
#define GRILLE_PX   3.0
#define CONTRAST    1.08              // @0.6..2
#define BRIGHTNESS  1.12              // @0.6..1.8
#define TINT        vec3(1.0)

// ── 움직임 ────────────────────────────────────────────────────────────────
// 시간에 걸린 것 전부의 속도. 아래 GRAIN_HZ 와 HUM_SPEED 에 곱해지므로 이 한 줄만
// 바꾸면 움직임 전체가 같은 비율로 느려지고 빨라진다.
#define ANIM_SPEED  0.45              // @0.05..2

// 아날로그 그레인. 세기, 덩어리 크기(픽셀), 새 무늬를 뽑는 초당 횟수.
// grainAt() 이 저주파 성분을 빼기 때문에 GRAIN_PX 는 질감만 정하고 화면 전체가
// 밝아졌다 어두워지는 깜박임과는 무관하다. GRAIN_HZ 가 높은 것도 그래서다 —
// 사람이 깜박임에 제일 민감한 3~15Hz 대역을 피한다.
#define GRAIN       0.030             // @0..0.15
#define GRAIN_PX    1.5
#define GRAIN_HZ    40.0              // @5..60

// 잡티를 어디에 얹을지의 배분. 더하기만 쓰면 밝은 곳에서 묻히고, 곱하기만 쓰면
// 검정에서 사라진다(검정 × 무엇이든 검정). 섞어야 화면 전체에 고르게 얹힌다.
#define GRAIN_ADD   1.0    // 어두운 곳에서의 몫
#define GRAIN_MUL   1.4    // 밝은 곳에서의 몫

// 험 바 — 전원 주파수와 수직 주사가 어긋나서 생기는 밝기 띠. 화면 전체를 훑는
// 사인이 아니라 좁은 띠 하나가 천천히 굴러 내려간다. 어느 순간에도 화면의
// HUM_WIDTH 만큼만 영향을 받으므로, 눈이 "화면이 변한다"가 아니라 "무언가가
// 지나간다"로 읽는다. 한 바퀴에 1 / (HUM_SPEED × ANIM_SPEED) 초.
//
// 터미널(순검정 배경)보다 값이 낮다. 데스크톱은 벽지와 창으로 이미 밝아서 같은
// 세기면 띠가 훨씬 도드라진다.
#define HUM_LIFT    0.015             // @0..0.1 띠 안에서 검정이 뜨는 양 — 이게 있어야 보인다
#define HUM         0.04              // @0..0.3 띠 안에서 밝은 픽셀이 더 밝아지는 비율
#define HUM_GLOW    1.2               // @0..4 띠 안에서 블룸이 번지는 비율
#define HUM_WIDTH   0.10              // @0.02..0.4 띠 높이(화면 높이 비율)
#define HUM_SPEED   0.25              // @0..1 초당 몇 화면분 내려가는지

// 클릭 리플 — 누른 자리에서 퍼져 나가는 링 하나. 험 바와 같은 문법으로 얹으므로
// 값의 뜻도 같다(GAIN 은 밝은 픽셀의 몫, LIFT 는 검정의 몫, GLOW 는 블룸 배율).
//
// 브라운관에서 이게 어색하지 않은 건 전자빔이 지나간 자리가 순간 밝아지는 것과
// 문법이 같아서다. 실제 브라운관에 클릭이라는 개념은 없지만, 화면이 무언가에
// 반응해 한 번 밝아지는 것 자체는 이 유리가 늘 하는 일이다.
//
// 시간은 pointer_pressed_times 에서 오고 그건 실제 초라, ANIM_SPEED 를 안 먹는다.
// 입력에 대한 반응이 화면 애니메이션 속도를 따라가면 손과 어긋나서 늦게 느껴진다.
#define RIPPLE_SEC  0.55              // @0.1..2 한 번이 사라지기까지의 초
#define RIPPLE_MAX  0.20              // @0.02..0.6 다 퍼졌을 때의 반지름(화면 높이 비율)
#define RIPPLE_W    0.030             // @0.005..0.15 링의 두께. 얇을수록 물결, 두꺼울수록 번쩍임이 된다
#define RIPPLE_GAIN 0.35              // @0..1.5
#define RIPPLE_LIFT 0.05              // @0..0.3
#define RIPPLE_GLOW 1.5               // @0..4
// 최근 몇 개까지 겹쳐 볼지. 이력은 32 개지만 RIPPLE_SEC 안에 그만큼 누를 일이
// 없고, 루프는 픽셀마다 도는 비용이다.
#define RIPPLE_TAPS  6


vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 bulge = abs(uv.yx) * CURVE;
    uv += uv * bulge * bulge;
    return uv * 0.5 + 0.5;
}

// 밴딩 없는 해시(Dave Hoskins 계열). sin(dot(...)) 쪽은 좌표가 커지면 무늬가
// 반복돼서, 잡티가 아니라 격자처럼 보인다.
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
    return mix(mix(hash(i,                  seed), hash(i + vec2(1.0, 0.0), seed), f.x),
               mix(hash(i + vec2(0.0, 1.0), seed), hash(i + vec2(1.0, 1.0), seed), f.x), f.y);
}

// 하이패스 그레인. 잔 노이즈에서 네 배 굵은 노이즈를 빼면 넓은 면적의 평균이 0 에
// 수렴한다 — 화면이 통째로 밝아졌다 어두워지는 성분이 그 저주파였다.
float grainAt(vec2 p, float seed) {
    return vnoise(p / GRAIN_PX, seed) - vnoise(p / (GRAIN_PX * 4.0), seed + 7.0);
}

// 화면비를 곱해 두지 않으면 가로로 늘어난 타원이 된다. 기준을 세로로 잡는 건
// 반지름 값들이 모니터를 바꿔도 같은 크기로 보이게 하려는 것이다. ./crt.frag 의
// focusAt() 과 같은 이유이고, 아래 ripples() 도 같은 보정을 쓴다.
vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

// 이 픽셀에서 쓸 초점 흐림. 커서 둘레만 조인다 (./crt.frag 의 같은 함수).
float focusAt(vec2 uv) {
    vec2 d = (uv - pointer_position) * aspect();
    float near = exp(-dot(d, d) / (FOCUS_RADIUS * FOCUS_RADIUS));
    return mix(FOCUS, FOCUS * FOCUS_NEAR, near);
}

// 최근 클릭들이 이 픽셀에 남기는 세기의 합. 0 이면 아무 일도 없다.
float ripples(vec2 uv) {
    float acc = 0.0;
    vec2  a   = aspect();

    for (int i = 0; i < RIPPLE_TAPS; i++) {
        float age = pointer_pressed_times[i];
        // 한 번도 안 누른 자리는 컴포지터가 뜬 뒤로 흐른 시간이 들어와서 아주 크다.
        // 그래서 별도의 "비어 있음" 표시가 없어도 이 한 줄로 걸러진다.
        if (age > RIPPLE_SEC) continue;

        float k = age / RIPPLE_SEC;             // 0 → 1
        float r = length((uv - pointer_pressed_positions[i]) * a);

        // 반지름만 자라고 두께는 유지한다. 두께까지 같이 키우면 링이 아니라
        // 점점 커지는 원반이 되어, 화면 절반이 밝아지는 순간이 생긴다.
        //
        // pow(x, 2.0) 이 아니라 곱하기다. GLSL 의 pow 는 밑이 음수면 정의되지
        // 않는데, 여기 밑은 링 안쪽에서 음수다 — 험 바가 같은 자리에서 같은
        // 이유로 곱하기를 쓴다.
        float e = (r - k * RIPPLE_MAX) / RIPPLE_W;
        acc += exp(-e * e) * (1.0 - k);
    }
    return acc;
}

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

vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < BLOOM_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(BLOOM_TAPS));
        float a  = fi * 2.39996323;
        float w  = exp(-r * r * 1.8);
        vec3  c  = texture(tex, uv + vec2(cos(a), sin(a)) * r * BLOOM_PX * px).rgb;
        float l  = dot(c, vec3(0.2126, 0.7152, 0.0722));
        sum  += c * smoothstep(BLOOM_CUT, BLOOM_CUT + BLOOM_KNEE, l) * w;
        wsum += w;
    }
    return sum / wsum;
}

// 효과 하나를 화면에 얹는다. gain 은 밝은 픽셀에서의 몫, lift 는 검정에서의 몫이다.
// 한쪽만 쓰면 반드시 한쪽에서 안 보인다(위 GRAIN_ADD/GRAIN_MUL 주석 참고).
vec3 modulate(vec3 col, float amount, float gain, float lift) {
    return col * (1.0 + amount * gain) + vec3(amount * lift);
}

vec3 stripes(vec3 col, vec2 pix) {
    float scanAA   = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.y) / SCAN_PX);
    float grilleAA = 1.0 - smoothstep(0.25, 0.5, fwidth(pix.x) / GRILLE_PX);

    col *= 1.0 - SCAN_DEPTH * scanAA * (0.5 + 0.5 * sin(pix.y * TAU / SCAN_PX));

    float gp = pix.x * TAU / GRILLE_PX;
    vec3 mask = 0.5 + 0.5 * vec3(sin(gp), sin(gp + TAU / 3.0), sin(gp + TAU * 2.0 / 3.0));
    return col * (1.0 - GRILLE * grilleAA * mask);
}

vec3 bezel(vec3 col, vec2 uv) {
    vec2 e = uv * (1.0 - uv.yx);
    col *= smoothstep(0.0, 1.0, pow(max(e.x * e.y, 0.0) * 30.0, VIGNETTE));

    vec2 d = min(uv, 1.0 - uv) * screen_size;
    return col * smoothstep(0.0, EDGE_SOFT, min(d.x, d.y));
}

void main() {
    vec2 px  = 1.0 / screen_size;
    vec2 uv  = curve(v_texcoord);
    vec2 pix = uv * screen_size;

    float t = time * ANIM_SPEED;

    // 험 바 위치. fract 로 감고, 감긴 좌표에서의 최단 거리로 띠를 만든다.
    float humY   = fract(uv.y + t * HUM_SPEED);
    float humD   = min(humY, 1.0 - humY);
    float humBar = exp(-(humD * humD) / (HUM_WIDTH * HUM_WIDTH));

    // 최근 클릭들. 험 바와 같은 자리에 얹히므로 여기서 같이 구해 둔다.
    float rip = ripples(uv);

    // 블룸 쪽을 훨씬 세게 민다. 띠가 지날 때 밝은 것 둘레가 확 번지는 게
    // 브라운관에서 실제로 눈에 띄는 부분이다. 리플도 같은 배율을 탄다 — 누른
    // 자리에서 밝은 것들이 한 번 확 번지는 게 링 자체보다 먼저 눈에 들어온다.
    float humGlow = 1.0 + HUM_GLOW * humBar + RIPPLE_GLOW * rip;

    vec3 col = gun(uv, px, focusAt(uv));

    // 밝은 픽셀은 자기 밝기를 지키고, 번짐은 둘레의 어두운 픽셀에만 얹힌다.
    // 험 바와 리플이 미는 것도 이 문 뒤에 있다 — 흰 창 위에서 띠가 지날 때
    // 화면이 통째로 잘려 나가는 것을 막는다.
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col += bloom(uv, px) * BLOOM * humGlow * (1.0 - smoothstep(BLOOM_KEEP, 1.0, lum));

    col  = stripes(col, pix);

    // 그레인은 GRAIN_HZ 로 계단을 밟되, 계단 사이를 smoothstep 으로 이어 붙인다.
    // 새 무늬로 툭 갈아치우면 그게 눈에 걸리는 지글거림이 된다. 좌표는 곡면이
    // 아니라 화면 픽셀이다 — 잡티는 유리 앞이 아니라 유리 자체에 있다.
    float ts = t * GRAIN_HZ;
    float g  = mix(grainAt(gl_FragCoord.xy, floor(ts)),
                   grainAt(gl_FragCoord.xy, floor(ts) + 1.0),
                   smoothstep(0.0, 1.0, fract(ts)));
    col = modulate(col, g * GRAIN, GRAIN_MUL, GRAIN_ADD);

    // 띠 밖은 humBar 가 0 이라 아무 일도 일어나지 않는다.
    col = modulate(col, humBar, HUM, HUM_LIFT);
    col = modulate(col, rip, RIPPLE_GAIN, RIPPLE_LIFT);

    // 명암은 더하기(블룸·그레인·리플)가 전부 끝난 뒤여야 한다. 들어 올린 검정을
    // 도로 누르는 것이 목적이라, 앞에 두면 아무 일도 안 한 셈이 된다. max() 는
    // 그레인이 검정 근처를 음수로 밀 수 있어서다 — pow(음수, 소수)는 NaN 이다.
    col = pow(max(col, 0.0), vec3(CONTRAST));

    col  = bezel(col, uv);
    col *= BRIGHTNESS * TINT;

    fragColor = vec4(col, 1.0);
}
