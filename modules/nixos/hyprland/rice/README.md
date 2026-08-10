# 화면 셰이더

렌더링이 끝난 화면 한 장에 프래그먼트 셰이더를 한 번 더 건다. 바탕도 바도 창도
커서도 전부 같은 유리 뒤로 들어간다. 하이프랜드의 `decoration:screen_shader` 이고,
니리에 없는 훅이라 이 세션이 이 레포에 있는 이유가 된다(`../default.nix`).

```sh
apps/rice-crt                        지금 걸린 것과 목록
apps/rice-crt crt/crt                한 장
apps/rice-crt water/still print/paper  즉석 체인 — 순서대로 겹친다
apps/rice-crt chain/bad-signal        저장해 둔 체인
apps/rice-crt --save 이름             지금 체인에 이름 붙이기
apps/rice-crt --next                 목록 순환 (Mod+Shift+C 와 같다)
apps/rice-crt off                    탈출구
```

런처에서는 `Mod+space` → `:` → **화면 셰이더 고르기**. 갈래 → 값으로 한 단 접혀
있고, 거기서 칸을 더하거나 체인에 이름을 붙일 수도 있다. 값 조절은 DMS 설정
패널의 슬라이더이고 뒤판은 `apps/rice-knobs` 다.

```
shaders/
├── crt/          crt.frag
├── water/        still.frag  river.frag  ocean.frag
├── cyberpunk/    neon.frag  glitch.frag
└── print/        paper.frag

chains/           bad-signal
```

한때 `cyberpunk/rain.frag`(빗방울) · `print/riso.frag`(리소 망점) ·
`print/dither.frag`(게임보이 4색)이 더 있었다. 실기에서 보고 지웠다 — 셋 다 본문을
못 읽게 만드는데 그 대가로 얻는 룩이 값어치가 없었다. 지운 판단의 근거는 아래
「값이 곱이라는 것」이 아니라 순전히 눈이다. 맥 쪽(`~/git/global-shader-for-macos`)
에는 아직 남아 있다.

폴더가 곧 갈래 이름이고, 그게 그대로 부르는 이름의 앞부분이 된다 — `crt/crt`.
런처의 접기도 이 모양 그대로다. 파일이 서넛일 때는 한 단에 늘어놓는 게 맞았지만
열둘이 되면서 갈렸다 — 이름을 하나씩 읽어야 무엇인지 알 수 있는 목록은 목록이
아니다.

`../../../shared/ghostty/shaders/` 의 터미널 셰이더도 `term/<이름>` 으로 칸이
된다. 복사본을 만들지 않으려는 것이고, 창 하나에 걸던 룩을 화면 전체로 올려 볼
수 있는 것은 덤이다. 다만 고스티 전용 유니폼(`iCurrentCursor` 등)을 읽는 것은
못 쓴다 — 하이프랜드가 그 값을 안 준다. 목록에서 아예 빠진다.

## 규약

셰이더 파일은 하이프랜드 규약을 그대로 쓴다.

| | |
|---|---|
| `tex` | 화면 한 장. (0,0) 이 좌상단 |
| `screen_size` | 이 화면의 픽셀 크기 |
| `pointer_position` | 커서. 0..1, 좌상단 원점 |
| `time` | 건 뒤로 흐른 초 |
| `pointer_pressed_positions[32]` | 최근 클릭. `[0]` 이 가장 최근 |
| `pointer_pressed_times[32]` | 그 클릭 **이후** 흐른 초 |

셰이더토이 규약(`mainImage` · `iChannel0` · `iResolution` · `iTime` · `iMouse` ·
`iFrame`)으로 쓴 파일도 칸이 된다. `apps/rice-chain` 이 껍데기를 둘러서 위
이름으로 접어 준다 — 터미널 셰이더가 그쪽이다.

## 체인

`decoration:screen_shader` 는 **한 장만 받는다.** 상류도 여러 장을 겹치는 기능을
안 만들고 "합쳐서 써라"로 답해 왔다(hyprwm/Hyprland#14101).

그래서 `apps/rice-chain` 이 전처리기로 한 파일에 접는다. 칸마다 껍데기를 앞뒤에
두르고 파일 내용을 **그대로** 사이에 끼운다 — 이름을 갈라 놓고, 뒷칸의 `tex` 를
앞칸의 출력으로 바꿔치기한다. **셰이더 소스는 한 글자도 안 고쳐진다.** 그래야
같은 파일이 혼자 걸릴 때도, 맥에서도 그대로 돈다.

잘못 접히면 컴파일 에러로 죽는다. 조용히 다른 그림이 나오는 길이 없다.

### 값이 곱이라는 것

**이것이 이 방식의 유일한 진짜 제약이다.** 맥 판은 칸마다 화면 한 장을 만들어
넘기므로 비용이 **합**이지만, 여기는 인라인이라 **곱**이다 — 뒷칸이 `tex` 를 N 번
읽으면 앞칸이 픽셀당 N 번 돈다.

측정값 (픽셀당 `texture()` 평가 횟수, `apps/rice-chain --cost`):

```
crt/crt           23      cyberpunk/neon    21      print/paper        5
water/still       10      cyberpunk/glitch   3      term/glow          1
water/river       10
water/ocean       10
```

```
water/still → print/paper    =  50    쓸 수 있다
cyberpunk/neon → glitch      =  63    아슬아슬하게 들어간다
crt/crt → cyberpunk/neon     ≈ 483    못 쓴다
```

곱이라 순서를 바꿔도 안 준다. 한도(64)를 넘으면 `apps/rice-chain` 이 거절하고,
런처의 "칸 더하기" 목록에는 애초에 안 뜬다.

한 탭짜리가 `term/glow` 하나뿐인 것이 지금의 제약이다. 예전에는 `print/riso` 와
`print/dither` 가 그 자리에 있어서 `crt/crt` 뒤에도 무엇이든 붙일 수 있었는데,
둘을 지우면서 제일 무거운 `crt/crt`(23) 은 `term/glow` 하고만 겹칠 수 있게 됐다.
룩을 잃은 대가가 아니라 **곱셈의 대가**라, 새 셰이더를 들일 때 탭 수를 먼저 보는
편이 낫다.

여기 있는 것은 탭 수뿐이고 **프레임 시간은 안 쟀다.** 탭 수는 셰이더가 화면을 몇
번 읽는지일 뿐이라 실제 비용의 전부가 아니다 — 다만 이 셰이더들에서는 그게 가장
크게 갈리는 축이라 한도의 기준으로 삼았다.

## 계속 그릴지는 셰이더가 정한다

셰이더가 시간을 읽으면 화면이 안 바뀌어도 계속 그려야 흐른다. 안 읽으면 안 그리는
게 맞다. 이 판단이 `debug:vfr` 이고, **배터리 비용 전부가 여기 붙어 있다.**

```
crt/crt            켬    0 으로 두면 끈다: GRAIN HUM* RIPPLE_*
water/still        켬    0 으로 두면 끈다: SPEED CLICK
water/river        켬    0 으로 두면 끈다: FLOW
water/ocean        켬    0 으로 두면 끈다: SPEED
cyberpunk/glitch   켬    0 으로 두면 끈다: DENSITY
cyberpunk/neon     끔
print/paper        끔
term/glow          끔
```

물 셋은 셋 다 켬으로 갈린다. **여기에는 선택지가 없다** — 안 움직이면 물이 아니다.

**체인에서는 한 칸이라도 켬이면 전체가 켬이다.** 시간을 읽는 칸이 안 흐르면 그
칸만 멈추는 게 아니라 고장으로 보이기 때문이고, 그래서 이 판정은 겹쳐 쓸 때
**파일을 고르는 일**이 된다.

`debug:damage_tracking` 은 이것과 무관하게, 셰이더가 걸리면 무조건 0 이다. 자기
픽셀 밖을 읽는 셰이더는 부분 재합성과 같이 못 산다 — 바뀐 사각형만 다시 합성하면
그 바깥 이웃이 낡아서 움직이는 것 둘레에 잔상이 남고, `fwidth()` 는 사각형
경계에서 불연속이라 이음매가 생긴다. 둘을 한동안 하나로 묶어 뒀다가 증상을 둘 다
겪었다 — `../../../../docs/postmortems/2026-08-04-hyprland-crt.md`.

## 손잡이가 시간을 여닫는다

위 표의 오른쪽 칸이 이것이다. 재그리기 판정을 `time` 유니폼이 있는지로만 하면
`crt/crt` 은 영영 켬이다 — 그런데 그레인·험 바·클릭 파문을 전부 0 으로 내린
`crt/crt` 은 정지 셰이더고, 그때는 VFR 을 켜 두는 것이 맞다.

그래서 셰이더가 `@범위` 옆에 **`!motion`** 으로 스스로 선언한다:

```glsl
#define GRAIN       0.030             // @0..0.15 !motion
#define BLOOM       0.32              // @0..1:0.01
```

표시된 손잡이가 하나라도 0 이 아니면 흐르는 것이고, 전부 0 이면 그 자리에서
끔이 된다. 표시가 하나도 없는데 `time` 을 읽으면 켬이다. 판정은
`apps/rice-chain --motion`, 그걸 보고 축을 맞추는 것은 `apps/rice-crt` 다.

`@` 표시는 슬라이더 선언이기도 하다. 붙은 것만 손잡이가 되고, 설명은 바로 위
주석 덩어리와 `@범위` 뒤에 남은 글자를 쓴다. 새 셰이더를 넣어도 스크립트는 안
고친다 — `apps/rice-knobs`.

## 승격이 안 되는 셰이더

`BLOOM_TAPS` 나 `GLOW_TAPS` 처럼 루프 횟수를 정하는 `#define` 에는 `@` 표시를
안 단다. 슬라이더로 만질 값이 아니기 때문인데, 이유가 둘이다.

하나는 뜻이다. 탭 수는 "얼마나"가 아니라 셰이더의 **모양**이라, 값을 밀면 룩이
부드럽게 변하는 게 아니라 다른 셰이더가 된다.

또 하나는 `apps/rice-chain` 이 그 값을 **정적으로 읽어야 한다**는 것이다. 체인
비용이 곱이라 탭 수를 미리 세야 하고, 루프 횟수를 못 읽으면 세는 것을 포기하고
실패를 낸다. 모르는 값을 1 로 치면 무거운 조합이 조용히 통과하기 때문이다.

(맥 레포에 같은 이름의 절이 있는데 거기서는 뜻이 다르다 — GLSL 을 MSL 로 옮길 때
상수로 승격되지 않는 것 이야기다. 이쪽에는 그 변환이 없다.)

## 그 밖에

- **`tex` 를 읽지 못하면 이 파일들은 성립하지 않는다.** 곡률·굴절·블룸·색수차는
  전부 자기 픽셀 **밖**을 읽는다. 맥 레포의 README 에 방식별 대가 표가 있는데,
  거기서 감마 LUT 과 블렌드 오버레이가 탈락하는 것이 이 이유다. 하이프랜드에서는
  컴포지터가 화면을 직접 넘겨주므로 그 선택 자체가 없다.
- **합성본은 캐시에 산다.** `${XDG_CACHE_HOME:-~/.cache}/rice/shaders/`. 손잡이를
  고치면 원본이 바뀌므로 걸 때마다 다시 접는다(`apps/rice-crt --reload`). 통째로
  지워도 다음에 걸 때 다시 만들어진다.
- **컴파일 실패는 하이프랜드가 안 알려 준다.** 셰이더를 걸어 두고 다음 프레임에
  컴파일하며, 실패해도 `hyprctl` 은 ok 를 돌려주고 로그에도 안 남는다(0.56.1
  실측). 그래서 이 세션은 `glslang` 을 깔아 두고 `apps/rice-chain` 이 걸기 전에
  한 번 돌린다.
- **화면이 알아볼 수 없게 되면** 다른 tty 에서든 눈 감고든 `apps/rice-crt off`.
- **설정은 선언적이지 않다.** `./shaders` 와 `./chains` 는 없을 때만 `$HOME` 으로
  시드된다(`../default.nix`). 라이싱 중에 고친 값이 rebuild 로 날아가지 않게
  하려는 것이고, 되받아 레포에 넣는 것은 `apps/rice-save` 다.
