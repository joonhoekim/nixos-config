#version 300 es
//
// neon.frag — 네온 간판. 밝기가 아니라 **채도**로 고른다.
//
// ../crt/crt.frag 의 bloom() 과 탭 모양은 같은데 고르는 기준이 다르다. 거기서는
// 휘도로 골랐고 그게 맞았다 — 브라운관에서 번지는 것은 인광체가 밝게 탄 자리다.
// 네온은 다르다. 흰 창과 흰 글씨는 아무리 밝아도 간판이 아니고, 어두운 바탕
// 위의 **짙은 색** — 프롬프트 색, 문법 강조색, 아이콘의 원색 — 이 타는 것이다.
//
// 그래서 여기서는 채도로 고른다. 그 한 줄이 이 파일의 전부다. 회색 UI 판때기는
// 밝아도 안 걸리고, 어두운 자주색 한 점은 안 밝아도 걸린다. 휘도로 고르는 블룸을
// 세게 걸어 놓고 "왜 화면 전체가 들려 올라가지" 하던 것이 `crt.frag` 의
// BLOOM_CUT 0.22 였고(그 파일 머리말 참고), 여기서는 애초에 그 축이 아니다.
//
// ── 겹쳐 쓰라고 만든 파일이다 ─────────────────────────────────────────────
// 혼자 걸어도 되지만 체인 뒤칸에 두는 것이 제 자리다(../../README.md 「체인」).
//
//   global-shader shaders/crt/crt.frag shaders/cyberpunk/neon.frag        브라운관 네온
//   global-shader shaders/cyberpunk/neon.frag shaders/cyberpunk/glitch.frag  간판이 튄다
//
// **그래서 깜빡임을 안 넣었다.** 간판이라면 깜빡여야 할 것 같지만, `time` 을
// 한 번이라도 읽으면 재그리기가 켜져서 정지 화면에서도 주사율대로 GPU 를 쓴다
// (../../README.md 「계속 그릴지는 셰이더가 정한다」). 겹쳐 쓰는 파일은 그 값을
// 혼자 정할 수 없다 — `crt.frag` 뒤에 걸면 그쪽이 애써 지킨 "정지 화면 공짜"가
// 이 파일 하나 때문에 날아간다. 깜빡임이 필요하면 ./glitch.frag 을 뒤에 붙이면
// 되고, 그때는 값을 치르겠다는 결정이 그 파일을 고르는 행동에 이미 들어 있다.

precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size;

// ── 무엇이 타는가 ─────────────────────────────────────────────────────────
// 이 채도부터 이 폭에 걸쳐 타기 시작한다. 0.18 이면 터미널의 강조색과 아이콘은
// 걸리고 회색 판때기·흰 글씨·바탕 사진의 옅은 색은 안 걸린다.
//
// 0.08 까지 내려 봤다가 되돌렸다. 사진 배경화면이 통째로 걸려서 화면 전체가
// 뿌옇게 빛나는데, 그건 네온이 아니라 그냥 안개다.
#define CHROMA_CUT  0.18              // @0..0.6
#define CHROMA_KNEE 0.14              // @0.01..0.4

// 너무 어두운 색은 뺀다. 꺼져 있는 간판은 안 빛나야 한다 — 이게 없으면 어두운
// 테마의 짙은 남색 배경이 통째로 후보가 된다.
#define LUMA_FLOOR  0.10              // @0..0.5

// ── 어떻게 타는가 ─────────────────────────────────────────────────────────
// 후광의 세기와 반경(픽셀). 반경이 `crt.frag` 의 BLOOM_PX(5) 보다 훨씬 큰 것은
// 네온관 둘레의 빛무리가 글자 획의 번짐보다 넓기 때문이다.
#define GLOW        0.85              // @0..2
#define GLOW_PX     14.0              // @2..40

// 나선 탭 수. 상수여야 해서 표시를 안 단다(../../README.md 「승격이 안 되는 셰이더」).
// 반경이 넓은 만큼 `crt.frag` 의 16 보다 촘촘해야 표본 사이가 안 벌어진다.
#define GLOW_TAPS   20

// 번지는 빛의 채도를 한 번 더 올린다. 실제 네온관 둘레의 빛은 관 자체보다
// 색이 옅은데, 화면에서는 그러면 그냥 흐릿한 얼룩으로 보인다. 색을 세워 둬야
// "빛이 샌다"로 읽힌다 — 사실보다 읽히는 쪽을 골랐다.
#define GLOW_SAT    1.45              // @1..2.5

// 이 밝기부터는 후광을 자기 자신에게 안 얹는다. `crt.frag` 의 BLOOM_KEEP 과
// 같은 이유와 같은 뜻이다 — 더하기라서, 이미 1.0 근처인 면에 또 더하면 잘려
// 나가고 그 면이 통째로 뭉개진다. 네온관의 심 자체는 자기 밝기를 지키고 후광은
// 둘레의 어두운 픽셀에만 남아야 관이 관으로 보인다.
#define GLOW_KEEP   0.55              // @0..1

// ── 바탕 ──────────────────────────────────────────────────────────────────
// 네온은 어두운 데서 산다. 채도가 낮은 픽셀만 눌러서 대비를 만든다 — 전체를
// 누르면 간판까지 같이 어두워져서 아무 일도 안 한 것과 같아진다.
#define DARKEN      0.22              // @0..0.6

// 눌린 바탕에 얹는 밤 색. vec3 는 손잡이가 안 된다(Sources/Knobs.swift) —
// 고치고 저장하면 바로 반영된다.
#define NIGHT       vec3(0.62, 0.70, 1.00)

#define BRIGHTNESS  1.04              // @0.6..1.6


// 채도폭. HSV 의 S(= (mx-mn)/mx) 가 아니라 mx-mn 이다.
//
// S 로 재면 어두운 색에서 터진다 — (0.02, 0.0, 0.0) 같은 거의 검정도 S 가 1 이라,
// 어두운 테마의 배경 잡티가 전부 간판이 된다. 폭으로 재면 "얼마나 짙은 색인가"가
// 그대로 나오고, 어두운 쪽은 LUMA_FLOOR 가 아니라 이 값 자체가 먼저 걸러 준다.
float chroma(vec3 c) {
    return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// 이 픽셀이 간판일 확률. 0 이면 안 타고 1 이면 탄다.
float sign_(vec3 c) {
    return smoothstep(CHROMA_CUT, CHROMA_CUT + CHROMA_KNEE, chroma(c))
         * smoothstep(LUMA_FLOOR, LUMA_FLOOR + 0.12, luma(c));
}

// 골든앵글 나선 탭. 링으로 돌면 방향 수만큼 별 모양 결이 남고 나선은 안 남는다
// (../crt/crt.frag 의 bloom() 과 같은 이유). 반경을 sqrt 로 잡아야 표본이 면적에
// 고르게 퍼진다.
vec3 halo(vec2 uv, vec2 px) {
    vec3  sum  = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < GLOW_TAPS; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(GLOW_TAPS));
        float a  = fi * 2.39996323;          // 황금각
        float w  = exp(-r * r * 1.6);        // 가우시안 가중
        vec3  c  = texture(tex, uv + vec2(cos(a), sin(a)) * r * GLOW_PX * px).rgb;
        sum  += c * sign_(c) * w;
        wsum += w;
    }
    return sum / wsum;
}

// 채도를 세운다. 회색 쪽으로 당기는 mix 를 1 너머로 밀면 반대로 벌어진다 —
// 별도의 HSV 왕복이 필요 없다.
vec3 saturate_(vec3 c, float k) {
    return max(mix(vec3(luma(c)), c, k), 0.0);
}

void main() {
    vec2 px = 1.0 / screen_size;
    vec2 uv = v_texcoord;

    vec3  src = texture(tex, uv).rgb;
    float s   = sign_(src);

    // 바탕만 누른다. 간판(s=1)인 자리는 안 건드린다.
    vec3 col = src * mix(1.0 - DARKEN, 1.0, s);
    col = mix(col, col * NIGHT, DARKEN * (1.0 - s) * 0.7);

    // 후광. 이미 밝은 자리에는 안 얹는다(GLOW_KEEP).
    vec3 h = saturate_(halo(uv, px), GLOW_SAT);
    col += h * GLOW * (1.0 - smoothstep(GLOW_KEEP, 1.0, luma(col)));

    col *= BRIGHTNESS;

    // 오버레이 레이어가 불투명이라 알파는 버려진다(Sources/Renderer.swift).
    // 체인 중간 칸일 때도 다음 칸이 rgb 만 읽으므로 1 로 둔다.
    fragColor = vec4(col, 1.0);
}
