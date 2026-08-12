#version 300 es
//
// crt.frag — 화면 전체에 거는 브라운관. 하이프랜드의 decoration:screen_shader 다.
//
// 니리 때문에 못 하던 그것이다: 렌더링이 다 끝난 화면 한 장을 받아 마지막에 한 번
// 더 그린다. 창 하나가 아니라 바탕·바·창·커서가 전부 같은 유리 뒤로 들어간다.
//
// ── 왜 한 장인가 (전에는 둘이었다) ────────────────────────────────────────
// 얼마 전까지 이 파일과 crt-motion.frag 이 따로 있었다. 흐르는 것(그레인·험 바·
// 클릭 리플)이 든 판과 안 든 판이다. 나눈 이유는 분명했다 — `time` 을 *쓰기만
// 하면* 정지 화면에서도 계속 그려야 해서, 쓰지 않는 갈래를 컴파일러가 지워
// 주기를 기대하는 것보다 파일이 둘인 편이 정직하다고 봤다.
//
// **그 정직함이 실제로는 안 지켜졌다.** 합치기 전에 둘을 대조해 보니:
//
//   curve · gun · focusAt · bloom · stripes · bezel   주석 뺀 코드 차이 0 줄
//   crt.frag 에만 있는 #define                        없음 (motion 쪽이 초집합)
//   FOCUS                                             0.18  vs  0.32   ← 어긋남
//   FOCUS_NEAR                                        0.25  vs  0.28   ← 어긋남
//
// crt-motion.frag 머리말에는 "여기를 고치면 ./crt.frag 도 같이 고쳐야 한다"고
// 적혀 있었다. 적어 두는 것으로는 안 된다는 것이 저 두 줄이다. 복제가 부르는
// 실패는 "언젠가 어긋날 수 있다"가 아니라 이미 일어난 일이었다.
//
// 어긋난 둘은 이 파일 쪽(0.18 / 0.25)으로 맞췄다. 아래 FOCUS 주석이 왜 0.5 에서
// 거기까지 내려왔는지를 적고 있고, motion 쪽 0.32 는 그 판단이 반영되기 전의
// 복사본이었기 때문이다. 손잡이라 화면 보고 되돌리면 된다.
//
// ── 흐르는 것은 손잡이로 끈다 ─────────────────────────────────────────────
// 옛 crt.frag 을 그대로 얻으려면 아래 넷을 0 으로 두면 된다:
//
//   GRAIN 0    HUM 0 · HUM_LIFT 0 · HUM_GLOW 0    RIPPLE_GAIN/LIFT/GLOW 0
//
// 그게 공짜여야 나눌 이유가 없어지므로, 값을 안 치르게 하는 장치가 둘 붙어 있다.
//
// **하나. 유니폼 분기.** 손잡이로 승격된 값은 유니폼이라 컴파일러가 못 접는다 —
// GRAIN 을 0 으로 둬도 그레인 코드는 매 픽셀 돈다. main() 에서 `if (GRAIN > 0.0)`
// 로 감싸 두면 유니폼 하나로 갈리는 분기라 워프가 통째로 같은 쪽으로 가서
// 실제로 안 돈다. 감싸지 않으면 옛 두 파일의 차이(12.1ms → 14.0ms)가 그대로
// 상시 비용이 된다.
//
// **둘. `!motion` 표시.** 재그리기 자동 판정은 원래 소스에 `time` 이 있는지만
// 봤다. 그 판정만으로는 합치는 순간 GRAIN=0 이어도 늘 켬이 되어, 이 파일이
// 가지고 있던 유일한 장점(정지 화면 비용 0)이 사라진다. 그래서 손잡이 옆에
// `!motion` 을 달아 "이게 시간을 여닫는다"고 셰이더가 선언한다 — 표시된 것이
// 전부 0 이면 재그리기를 끈다. 자세한 건 ../../README.md 「손잡이가 시간을
// 여닫는다」.
//
// **리눅스에서는 이 둘이 다 없다.** `!motion` 은 그냥 주석이고 `#define` 은
// 상수라 분기는 컴파일러가 접어 준다(그래서 비용은 거기서도 0 이다). 다만
// 하이프랜드는 `time` 을 쓰는 셰이더에 대해 `debug:vfr = false` 를 요구하므로,
// 값을 0 으로 둔 것과 무관하게 VFR 은 꺼 둬야 한다. 그건 컴포지터의 판단이지
// 이 파일이 어쩔 수 있는 것이 아니다.
//
// hyprland.lua 의 Mod+Shift+C 는 이제 둘을 오간다: off → crt.frag.
// 흐르는 것을 끄고 켜는 것은 셰이더를 갈아 끼우는 일이 아니라 손잡이 일이 됐다.
//
// ── 데미지 트래킹 ─────────────────────────────────────────────────────────
// `debug:damage_tracking = 0` 은 흐르는 것과 무관하게 늘 필요하다. curve()·
// gun()·bloom() 이 자기 픽셀 밖을 읽어서, 바뀐 사각형만 다시 합성하면 그 바깥
// 이웃이 낡기 때문이다. 자세한 건 ~/nixos-config 의 apps/rice-crt 머리말.
//
// ── 뿌리 ─────────────────────────────────────────────────────────────────
// nixos-config 의 ghostty 터미널 셰이더(modules/shared/ghostty/shaders/crt.glsl)
// 를 옮겨왔다. 터미널 창 하나에 걸던 것이라 값이 그대로면 화면 전체에서는 과하다
// — 아래 주석에 어디를 왜 낮췄는지 적어 뒀다.
//
// 그 터미널 셰이더의 뿌리는 다시 space_dots(Golden Era) 라이스에 들어 있던
// **Maxim Samoliuk 의 Hyprland 화면 셰이더(MIT)** 다. 블룸·그레인·깜빡임·색수차·
// 가장자리 처리는 전부 다시 짰지만, 파생인 것은 맞으므로 여기 적어 둔다.
// ../../SHADER-CREDITS.md 참고.
//
// 고치면 저장하는 즉시 반영된다.

precision highp float; // mediump 면 안 된다 — 2560 같은 픽셀 좌표에서 정밀도가
                       // 한 픽셀보다 굵어져 스캔라인이 뭉개진다.

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform vec2 screen_size; // 이 모니터의 픽셀 크기. fullSize / screenSize 도 같은 값이다.
uniform float time;       // 셰이더가 걸린 시점부터의 초.

// ── 포인터 ────────────────────────────────────────────────────────────────
// 문서에 없는 유니폼들이다. 0.56 의 renderToOutputInternal() 이 스크린 셰이더에
// 넘긴다(src/render/OpenGL.cpp). 전부 debug:damage_tracking = 0 을 요구하는데,
// 이 파일은 어차피 꺼야 하므로 **추가 비용이 없다**. 조사 기록은 _temp/ricing/.
//
// 좌표는 0..1 정규화, 이 모니터 로컬, **곡률을 먹기 전** 텍스처 좌표계다. 그래서
// curve() 를 통과한 uv 와 그대로 비교하는 것이 맞는다 — 커서도 화면과 같이 휘어서
// 텍스처 안에 이미 그려져 있기 때문이다.
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
#define CURVE       0.10              // @0..0.3

// 화면 가장자리가 죽는 폭(픽셀). 곡선을 계단으로 만들지 않을 만큼만.
#define EDGE_SOFT   1.5

// 비네트 지수. pow(밝기, VIGNETTE) 라 *클수록* 가장자리가 깊게 죽고, 0 이면
// 아예 없다 — 지수를 0 에 붙일수록 pow 가 1 로 평평해지기 때문이다.
// 터미널의 0.25 를 그대로 들고 왔더니 화면 전체에서는 너무 셌다. 거기서는
// 가장자리가 창 테두리 바깥의 여백일 뿐이지만 여기서는 바와 트레이가 늘 그
// 자리에 있어서, 어두워지면 안 되는 것들이 어두워진다. 1/5 로 줄인 값이다.
#define VIGNETTE    0.06              // @0..0.5

// ── 광학 ──────────────────────────────────────────────────────────────────
// 초점. 0 이면 원본 그대로, 1 이면 한 픽셀쯤 뭉갠다. 터미널에서는 0.5 였지만
// 여기서는 UI 잔글씨가 화면 전체에 있어서 가독성 대가가 훨씬 크다.
//
// 이 값은 밝기에도 직접 붙는다. 흰 글씨 획은 한두 픽셀이라 이웃이 대부분
// 검정이고, 흐리면 획의 봉우리가 1.0 에서 0.85 쯤으로 내려앉는다 — 그다음에
// 오는 스캔라인·그릴·감마가 전부 그 낮아진 값에 걸린다. "검은 바탕의 흰 글씨가
// 희미하다"의 출발점이 여기다.
//
// **머리말의 어긋난 값 둘 중 하나가 이것이다.** crt-motion.frag 에는 0.32 가
// 남아 있었는데, 그건 위 판단이 나오기 전의 복사본이었다.
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
// 깎아 놓은 값이라 감마를 정통으로 맞는다. 검정을 눌러야 할 일은 위 BLOOM_KEEP
// 이 훨씬 정확하게 한다(원인 자리에서 막으므로). 여기는 마무리다.
#define CONTRAST    1.08              // @0.6..2

// 스캔라인과 그릴이 깎아낸 만큼 되돌린다. 둘이 겹치는 골에서는 0.83 배까지
// 내려가므로 이 보정은 실재한다 — 잠깐 1.0 으로 뒀다가 흰 글씨가 희미해졌다.
#define BRIGHTNESS  1.12              // @0.6..1.8

// 인광체 색. vec3(1.0) 이면 팔레트 그대로다. 이 한 줄로 룩이 하나 더 나온다 —
// 호박색 vec3(1.15, 0.85, 0.45), 녹색 vec3(0.65, 1.20, 0.70).
#define TINT        vec3(1.0)


// ── 움직임 ────────────────────────────────────────────────────────────────
// 여기부터가 옛 crt-motion.frag 이다. `!motion` 이 붙은 것이 시간을 여닫는
// 손잡이고, 그것들이 전부 0 이면 재그리기가 꺼져서 정지 화면 비용이 0 이 된다
// (머리말 참고).
//
// ANIM_SPEED 에는 `!motion` 을 안 단다. 이걸 0 으로 둬도 그레인 무늬와 험 바는
// 그 자리에 그대로 있고(멈춘 것이지 없어진 게 아니다), 클릭 리플은 실제 초로
// 도니까 계속 움직인다 — "아무것도 안 움직인다"의 조건이 아니다.
#define ANIM_SPEED  0.45              // @0.05..2

// 아날로그 그레인. 세기, 덩어리 크기(픽셀), 새 무늬를 뽑는 초당 횟수.
// grainAt() 이 저주파 성분을 빼기 때문에 GRAIN_PX 는 질감만 정하고 화면 전체가
// 밝아졌다 어두워지는 깜박임과는 무관하다. GRAIN_HZ 가 높은 것도 그래서다 —
// 사람이 깜박임에 제일 민감한 3~15Hz 대역을 피한다.
#define GRAIN       0.030             // @0..0.15 !motion
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
//
// 셋 다 `!motion` 인 것은 어느 하나만 0 이 아니어도 띠가 보이기 때문이다.
#define HUM_LIFT    0.015             // @0..0.1 !motion 띠 안에서 검정이 뜨는 양 — 이게 있어야 보인다
#define HUM         0.04              // @0..0.3 !motion 띠 안에서 밝은 픽셀이 더 밝아지는 비율
#define HUM_GLOW    1.2               // @0..4 !motion 띠 안에서 블룸이 번지는 비율
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
#define RIPPLE_GAIN 0.35              // @0..1.5 !motion
#define RIPPLE_LIFT 0.05              // @0..0.3 !motion
#define RIPPLE_GLOW 1.5               // @0..4 !motion
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

// 화면비를 곱해 두지 않으면 가로로 늘어난 타원이 된다 — uv 는 양축이 0..1 이라
// 같은 거리라도 가로가 화면비만큼 넓다. 기준을 세로로 잡는 건 반지름 값들이
// 모니터를 바꿔도 같은 크기로 보이게 하려는 것이다.
vec2 aspect() {
    return vec2(screen_size.x / screen_size.y, 1.0);
}

// 이 픽셀에서 쓸 초점 흐림. 커서에 가까울수록 FOCUS_NEAR 쪽으로 간다.
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

// 효과 하나를 화면에 얹는다. gain 은 밝은 픽셀에서의 몫, lift 는 검정에서의 몫이다.
// 한쪽만 쓰면 반드시 한쪽에서 안 보인다(위 GRAIN_ADD/GRAIN_MUL 주석 참고).
vec3 modulate(vec3 col, float amount, float gain, float lift) {
    return col * (1.0 + amount * gain) + vec3(amount * lift);
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

    float t = time * ANIM_SPEED;

    // ── 흐르는 것들 ──────────────────────────────────────────────────────
    // 셋 다 유니폼 분기 뒤에 있다. 손잡이가 0 이면 **실제로 안 돈다** —
    // 유니폼 하나로 갈리는 분기라 워프가 통째로 같은 쪽으로 가기 때문이다.
    // 이 분기가 없으면 GRAIN=0 으로 둬도 그레인 코드가 매 픽셀 돌아서, 옛
    // 두 파일의 차이가 그대로 상시 비용이 된다(머리말 참고).
    //
    // 승격이 꺼져 있거나 리눅스에서는 이 값들이 그냥 상수라 컴파일러가 접는다.
    // 어느 쪽이든 비용은 0 이다.

    // 험 바 위치. fract 로 감고, 감긴 좌표에서의 최단 거리로 띠를 만든다.
    float humBar = 0.0;
    if (HUM + HUM_LIFT + HUM_GLOW > 0.0) {
        float humY = fract(uv.y + t * HUM_SPEED);
        float humD = min(humY, 1.0 - humY);
        humBar = exp(-(humD * humD) / (HUM_WIDTH * HUM_WIDTH));
    }

    // 최근 클릭들. 험 바와 같은 자리에 얹히므로 여기서 같이 구해 둔다.
    float rip = 0.0;
    if (RIPPLE_GAIN + RIPPLE_LIFT + RIPPLE_GLOW > 0.0) {
        rip = ripples(uv);
    }

    // 블룸 쪽을 훨씬 세게 민다. 띠가 지날 때 밝은 것 둘레가 확 번지는 게
    // 브라운관에서 실제로 눈에 띄는 부분이다. 리플도 같은 배율을 탄다 — 누른
    // 자리에서 밝은 것들이 한 번 확 번지는 게 링 자체보다 먼저 눈에 들어온다.
    //
    // **이 곱하기가 체인으로 쪼갤 수 없는 이유다.** 험 바와 리플을 뒷칸으로
    // 떼면 그 칸은 합성된 색만 보고 블룸 항을 못 만지므로, 눈에 제일 띄는
    // 이 번짐이 통째로 사라진다.
    float humGlow = 1.0 + HUM_GLOW * humBar + RIPPLE_GLOW * rip;

    vec3 col = gun(uv, px, focusAt(uv));

    // 밝은 픽셀은 자기 밝기를 지키고, 번짐은 둘레의 어두운 픽셀에만 얹힌다.
    // 험 바와 리플이 미는 것도 이 문 뒤에 있다 — 흰 창 위에서 띠가 지날 때
    // 화면이 통째로 잘려 나가는 것을 막는다.
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col += bloom(uv, px) * BLOOM * humGlow * (1.0 - smoothstep(BLOOM_KEEP, 1.0, lum));

    col = stripes(col, pix);

    // 그레인은 GRAIN_HZ 로 계단을 밟되, 계단 사이를 smoothstep 으로 이어 붙인다.
    // 새 무늬로 툭 갈아치우면 그게 눈에 걸리는 지글거림이 된다. 좌표는 곡면이
    // 아니라 화면 픽셀이다 — 잡티는 유리 앞이 아니라 유리 자체에 있다.
    if (GRAIN > 0.0) {
        float ts = t * GRAIN_HZ;
        float g  = mix(grainAt(gl_FragCoord.xy, floor(ts)),
                       grainAt(gl_FragCoord.xy, floor(ts) + 1.0),
                       smoothstep(0.0, 1.0, fract(ts)));
        col = modulate(col, g * GRAIN, GRAIN_MUL, GRAIN_ADD);
    }

    // 띠 밖은 humBar 가 0 이라 아무 일도 일어나지 않는다.
    col = modulate(col, humBar, HUM, HUM_LIFT);
    col = modulate(col, rip, RIPPLE_GAIN, RIPPLE_LIFT);

    // 명암은 더하기(블룸·그레인·리플)가 전부 끝난 뒤여야 한다. 들어 올린 검정을
    // 도로 누르는 것이 목적이라, 앞에 두면 아무 일도 안 한 셈이 된다. 비네트
    // (bezel) 앞인 건 반대 이유다 — 가장자리가 죽는 것은 이미 곱하기라 여기서
    // 또 깎을 필요가 없다. max() 는 그레인이 검정 근처를 음수로 밀 수 있어서다
    // — pow(음수, 소수)는 NaN 이다.
    col = pow(max(col, 0.0), vec3(CONTRAST));

    col  = bezel(col, uv);
    col *= BRIGHTNESS * TINT;

    // 화면 셰이더의 결과는 그대로 프레임버퍼로 간다. 곡률 바깥은 위에서 검정으로
    // 죽여 뒀고, 거기가 그대로 브라운관 베젤이 된다 — 그러니 알파는 항상 1 이다.
    fragColor = vec4(col, 1.0);
}
