#version 300 es
//
// still.frag — 잔잔한 수면. 화면 전체가 얕은 물 밑으로 들어간다.
//
// 물 셋의 기준 파일이다(셋이 공유하는 결정은 여기만 적는다). 설계: docs/hyprland-shaders.md
// 밀린 uv 가 화면 밖으로 나가면 clampToEdge 로 테두리 한 줄이 늘어나므로 EDGE_FADE 에서 밀림만 접는다.

precision highp float; // mediump 면 정밀도가 한 픽셀보다 굵어져 밀림이 계단으로 끊긴다.

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;

// 이 한 줄 때문에 정지 화면에서도 재그리기가 켜진다.
uniform float time;

// [0] 이 가장 최근, times 는 그 클릭 이후 흐른 초.
uniform vec2  pointer_pressed_positions[32];
uniform float pointer_pressed_times[32];

// ── 결 ────────────────────────────────────────────────────────────────────
// 잔물결의 촘촘함. 화면 세로를 몇 개의 파가 지나가는지에 가깝다. 24 까지 올리면
// 물이 아니라 마름모 격자로 보이기 시작한다 — 파장이 굴절 폭에 가까워지면
// 이웃한 골과 마루가 같은 픽셀로 접히기 때문이다.
#define RIPPLE      6.0               // @1..24

// 흐르는 속도. 0 이면 무늬가 얼어붙는다.
//
// 이 값과 아래 CLICK 둘 다 0 이어야 재그리기가 꺼진다 — 여기를 0 으로 둬도
// 클릭 물결은 실제 초로 돌기 때문이다. 그래서 표시가 둘에 다 붙어 있다
// (`!motion` — ../../README.md 「손잡이가 시간을 여닫는다」).
#define SPEED       0.20              // @0..1.5:0.01 !motion

// 잔결. 위 두 겹(긴 파)에 얹는 짧은 파의 세기. 0 이면 큰 파만 남아 유리처럼
// 매끈하고, 1 이면 바람이 스친 것처럼 자잘해진다.
#define CHOP        0.35              // @0..1

// ── 굴절 ──────────────────────────────────────────────────────────────────
// 물 너머가 밀려 보이는 폭(픽셀). **이 셰이더에서 제일 중요한 값이다.**
//
// 1.6 인 이유는 위 머리말의 커서 어긋남이다. 3 을 넘기면 물은 그럴듯해지지만
// 커서가 가리키는 자리와 실제 자리가 눈에 띄게 벌어지고, 글자도 읽는 동안
// 흔들린다. 상시로 걸어 두고 일할 수 있는 상한이 이 근처였다.
#define REFRACT     1.6               // @0..8

// 밀림을 0 으로 접는 가장자리 폭(0..1). 2% 면 2940 폭에서 60 픽셀쯤이라
// REFRACT 8 도 밖을 안 읽는다. 손잡이로 안 뺀 건 이게 취향이 아니라
// clampToEdge 를 막는 고정값이기 때문이다.
#define EDGE_FADE   0.02

// ── 글자 지키기 ───────────────────────────────────────────────────────────
// 잔글씨가 몰린 자리에서 밀림을 접는 정도. 0 이면 화면 전체가 똑같이 흔들린다.
//
// 참고한 xatuke/screenshader 의 underwater.frag 는 굴절한 색에 **원본 색을
// 되섞어서** 글자를 지킨다. 그러면 글자 둘레만 물빛이 벗겨져 네모난 자국이
// 남는다. 여기서는 색이 아니라 **밀림 자체를 줄인다** — 글자는 제자리에 서고
// 물빛은 화면 전체에 고르게 남는다. 원본을 따로 읽을 일도 없어서 페치도 하나
// 덜 든다.
//
// 접는 자리가 부드러워야 하는 것이 핵심이다. 글자 획에서만 밀림을 빼면 한 글자
// 안에서 획과 속이 다르게 밀려서 글자가 **찢어진다** — 흔들리는 것보다 나쁘다.
// 그래서 아래 busy() 는 PRESERVE_PX 반경의 나선 탭으로 뭉뚱그린 값을 낸다.
#define PRESERVE    0.70              // @0..1

// 글자를 찾는 반경(픽셀). 글자 하나를 통째로 덮을 만큼이어야 위의 찢어짐이
// 안 생긴다. HiDPI 백킹에서 본문 획이 2~3 픽셀이라 6 이면 넉넉하다.
#define PRESERVE_PX 6.0               // @2..16

// 나선 탭 수. 상수여야 해서 표시를 안 단다(../../README.md 「승격이 안 되는 셰이더」).
#define BUSY_TAPS   8

// 몇 부터 몇 까지를 "글자가 있다"로 볼지. 아래 busy() 가 **최대가 아니라 평균**을
// 재는 것과 짝이다 — 창 테두리 하나로는 이 구간을 못 채우고, 획이 촘촘한 자리라야
// 찬다. 최대로 재면 바탕화면의 대비 큰 무늬 하나에도 물이 통째로 꺼진다.
#define BUSY_LO     0.06
#define BUSY_HI     0.30

// ── 클릭 ──────────────────────────────────────────────────────────────────
// 누른 자리에서 퍼지는 물결의 세기. 0 이면 없다.
//
// ../crt/crt-motion.frag 의 ripples() 와 같은 꼴이지만 뜻이 다르다. 거기서 링은
// **밝기**였고 여기서는 **기울기**다 — 물에 던진 돌은 빛나지 않고 민다. 그래서
// 링의 단면을 그대로 쓰지 않고 그 미분을 쓰고, 부호가 안팎으로 갈려서 링 앞뒤가
// 반대로 밀린다. 그게 실제 물결이 하는 일이다.
#define CLICK       0.45              // @0..1 !motion

#define CLICK_SEC   1.6               // 링이 사라지기까지의 초
#define CLICK_MAX   0.45              // 그때까지 자라는 반지름(화면 높이 기준)
#define CLICK_W     0.06              // 링의 두께. 반지름과 달리 안 자란다.
#define CLICK_TAPS  8                 // 이력 32 개를 다 돌 이유가 없다. 상수.

// ── 색 ────────────────────────────────────────────────────────────────────
// 물빛을 섞는 정도. 0.6 을 넘기면 화면이 파래지는 게 아니라 화면이 없어진다.
#define TINT_MIX    0.14              // @0..0.6

// 물빛. 손잡이가 아니다 — vec3 는 유니폼 하나에 안 들어간다(Sources/Knobs.swift).
// 색을 바꾸려면 이 줄을 고치고 저장하면 된다(핫 리로드).
#define TINT        vec3(0.42, 0.72, 0.92)

// 물비늘. 기울기가 빛 쪽으로 누운 자리만 튄다. TIGHT 가 클수록 좁고 날카롭다.
#define SHINE       0.18              // @0..1
#define SHINE_TIGHT 24.0              // @2..80

// 빛의 방향. z 가 화면 밖이고 y 는 아래쪽이 양수라(v_texcoord 가 좌상단 원점),
// 이 값은 왼쪽 위에서 비추는 빛이다.
#define LIGHT       normalize(vec3(-0.30, -0.42, 1.0))

// 굴절과 반짝임이 깎아낸 만큼 되돌린다. 1.0 이면 안 건드린다.
#define BRIGHTNESS  1.02              // @0.6..1.4


vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

// (높이, 기울기x, 기울기y). 기울기가 해석적이라 표본을 더 뜨지 않는다.
vec3 wave(vec2 p, vec2 k, float speed, float amp, float t) {
    float ph = dot(p, k) + t * speed;
    return vec3(amp * sin(ph), amp * k * cos(ph));
}

// 파수는 서로 정수배가 아니고(정수배면 격자로 되풀이된다), 둘은 거의 마주 보게 둔다.
vec3 ripples(vec2 p, float t) {
    return wave(p, vec2( 1.00,  0.31), 1.00, 1.00, t)
         + wave(p, vec2(-0.83,  0.55), 0.83, 0.72, t)
         + wave(p, vec2( 0.47, -1.13), 1.31, 0.38 * CHOP, t)
         + wave(p, vec2(-1.29, -0.71), 1.67, 0.24 * CHOP, t);
}

vec2 clickSlope(vec2 uv) {
    vec2 acc = vec2(0.0);
    vec2 a   = aspect();

    for (int i = 0; i < CLICK_TAPS; i++) {
        float age = pointer_pressed_times[i];
        // 안 누른 자리는 띄운 뒤로 흐른 시간이 들어와 아주 커서 이 한 줄로 걸러진다.
        if (age > CLICK_SEC) continue;

        float k = age / CLICK_SEC;                  // 0 → 1
        vec2  d = (uv - pointer_pressed_positions[i]) * a;
        float r = length(d) + 1e-4;                 // 한가운데의 0 나누기를 막는다
        float e = (r - k * CLICK_MAX) / CLICK_W;

        // 기울기는 exp(-e²) 의 미분 -2e·exp(-e²). 1/CLICK_W 는 일부러 안 곱한다 —
        // 곱하면 CLICK_W 를 줄일 때마다 기울기가 폭발해 CLICK 이 뜻을 잃는다.
        acc += (d / r) * (-2.0 * e * exp(-e * e)) * (1.0 - k) * CLICK;
    }
    return acc;
}

// 잔글씨로 붐비는 정도(0..1). 최대가 아니라 평균이다 — 최대면 창 테두리 하나에도 물이 꺼진다.
// 나선 탭은 링 탭이 남기는 방향 결을 피한다.
float busy(vec2 uv, vec2 px) {
    const vec3 W = vec3(0.2126, 0.7152, 0.0722);
    float c = dot(texture(tex, uv).rgb, W);
    float e = 0.0;
    for (int i = 0; i < BUSY_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(BUSY_TAPS));
        float a  = fi * 2.39996323;                 // 황금각
        vec2  o  = vec2(cos(a), sin(a)) * r * PRESERVE_PX * px;
        e += abs(dot(texture(tex, uv + o).rgb, W) - c);
    }
    return smoothstep(BUSY_LO, BUSY_HI, e / float(BUSY_TAPS));
}

void main() {
    vec2 px = 1.0 / screen_size;
    vec2 uv = v_texcoord;

    vec3  s = ripples(uv * aspect() * RIPPLE, time * SPEED);
    vec2  g = s.yz + clickSlope(uv);

    // clampToEdge 대책.
    vec2  f = smoothstep(0.0, EDGE_FADE, uv) * smoothstep(0.0, EDGE_FADE, 1.0 - uv);
    float fade = f.x * f.y;

    // PRESERVE 가 0 이면 탭을 아예 안 뜬다(유니폼 분기).
    if (PRESERVE > 0.001) fade *= 1.0 - busy(uv, px) * PRESERVE;

    vec2 off = -g * REFRACT * px * fade;
    vec3 col = texture(tex, uv + off).rgb;

    // 물빛은 밖을 안 읽으므로 가장자리에서도 접지 않는다(접으면 테두리만 물이 아니게 된다).
    col = mix(col, col * TINT * 1.35, TINT_MIX);

    // 평평한 물에서도 0.89^24 ≈ 0.06 이 남아 옅은 윤기가 된다.
    vec3 n = normalize(vec3(-g, 1.0));
    col += SHINE * pow(max(dot(n, LIGHT), 0.0), SHINE_TIGHT);

    col *= BRIGHTNESS;

    // 화면 셰이더의 결과는 그대로 프레임버퍼로 가므로 알파는 1 이다.
    fragColor = vec4(col, 1.0);
}
