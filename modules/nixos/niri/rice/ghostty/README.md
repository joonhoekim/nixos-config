# ghostty 룩

`config` 는 어느 룩에서나 같은 것(폰트, 팔레트)을 정하고, 바뀌는 것은
`rices/<name>.conf` 조각 하나로 뺐다. `apps/rice-term <name>` 이 고른 조각을
`~/.config/ghostty/rice.conf` 로 복사하고 D-Bus 로 리로드를 시킨다. 재시작도
리빌드도 없고, 열려 있는 창에 바로 적용된다.

```sh
apps/rice-term            # 현재 + 목록
apps/rice-term crt        # 전환
apps/rice-term --next     # 다음 것
apps/rice-term off        # 탈출구
```

## 왜 이렇게 붙나

`config` 맨 아래 한 줄이 전부다:

```
config-file = ?rice.conf
```

`?` 는 파일이 없어도 조용히 넘어가라는 뜻이라, 조각을 한 번도 안 고른 새 머신도
그대로 뜬다. 그리고 ghostty 는 `config-file` 을 **자기를 담은 파일보다 나중에**
읽으므로, 줄 위치와 무관하게 조각이 본체를 이긴다.

셰이더 경로는 조각 기준 상대경로다(`shaders/crt.glsl`). fuzzel 처럼 절대경로를
박아 넣을 필요가 없어서, 레포 파일이 머신 이름을 모르고도 그대로 나간다.

## 지켜야 할 규칙

**모든 조각이 같은 키 집합을 다룬다** — `custom-shader`,
`custom-shader-animation`, `background-opacity`, `window-padding-x/y`. 조각은
앞 조각을 지우지 않고 덮어쓰기만 하므로, 어느 하나에만 있는 키가 생기면
A→B→A 로 돌아왔을 때 원래 값으로 안 돌아온다. `rice/profiles/README.md` 와 같은
이유, 같은 규칙이다.

**색은 조각에서 건드리지 않는다.** `theme = dankcolors` 는 DMS/matugen 이 쓰는
파일이라 프로필을 알아서 따라온다. 조각에 색을 박으면 그게 끊긴다.

## 현재 조각

| | off | glow | crt |
|---|---|---|---|
| 셰이더 | 없음 | `glow.glsl` | `crt.glsl` |
| 곡률·색수차·그릴 | — | 없음 | 있음 |
| 블룸 | — | 16탭 링 | 16탭 나선 + 소프트 니 |
| 애니메이션 루프 | — | 끔 | 켬 (그레인·험 바) |
| 투명도 | 0.94 | 0.94 | 1 |
| 가독성 | 원본 | 사실상 그대로 | 떨어짐 — `FOCUS` 를 낮추면 돌아온다 |

`crt` 는 space_dots(Golden Era) 라이스의 화면 셰이더에서 왔지만, 목표가 완벽
재현이 아니라 감성이라 거칠게 보이는 쪽은 일부러 깎았다. 무엇을 왜 바꿨는지는
`shaders/crt.glsl` 머리말에 있다.

부드러움을 만지는 값은 넷이다. 위에서부터 영향이 크다:

| 값 | 올리면 | 내리면 |
|---|---|---|
| `FOCUS` | 뭉개진다 | 칼같아진다 (글자가 제일 크게 반응) |
| `SCAN_PX` | 줄무늬가 굵고 성겨진다 | 촘촘해지고 모아레가 는다 |
| `SCAN_DEPTH` / `GRILLE` | 줄무늬가 도드라진다 | 존재만 남는다 |
| `GRAIN_PX` | 잡티가 덩어리진다 | 모래알에 가까워진다 |

눈이 피곤한 쪽은 따로 있다. 밝기가 오르내리는 험 바는 **글로우 성분에만**
곱한다 — 본문 글자와 배경의 밝기는 고정이고 번짐만 숨을 쉰다. 화면 전체를
밝혔다 어둡게 하는 게 제일 피곤해서다. 완전히 끄려면 `HUM` 을 0 으로.

`TRAIL` 은 커서 꼬리다. **이 셰이더에서 시간적인 잔상은 이것 하나뿐이다.**
나머지 글로우는 전부 공간적 번짐이다 — ghostty 가 셰이더에 주는 건
`iChannel0` = 현재 프레임 하나뿐이라 이전 화면을 섞어 꼬리를 남길 방법이 없다.
커서만 예외인 건 직전 위치(`iPreviousCursor`)와 바뀐 시각(`iTimeCursorChange`)을
따로 주기 때문이다. 꼬리는 커서가 **실제로 움직였을 때만** 그린다. 깜빡임이나
색 변화로도 `iTimeCursorChange` 가 갱신되는데, 그때까지 빛나면 제자리에서
맥동하는 꼴이 되어 험 바보다 더 거슬린다.

커서 좌표계에 주의: `iCurrentCursor.xy` 는 Y 가 위로 자라는 좌표계의 왼쪽 위
모서리이고 `zw` 가 폭·높이다. 꼬리가 위아래로 뒤집혀 보이면 `cursorTrail` 의
`- iCurrentCursor.w * 0.5` 를 `+` 로 바꾸면 된다.

## 고치는 자리는 `~/.config` 다

**레포 파일을 고치고 `apps/rice-term` 을 돌리면 아무 일도 일어나지 않는다.**
`rice-term` 이 복사하는 건 `rices/<name>.conf` 뿐이고, 셰이더 파일은 건드리지
않는다. 레포는 시드일 뿐이라 니리 모듈도 **파일이 없을 때만** 넣어 준다 —
이미 있는 `~/.config/ghostty/shaders/crt.glsl` 은 리빌드를 해도 덮이지 않는다.
그래서 ghostty 는 리로드를 성실히 하고도 바뀐 게 없다고 나온다.

편집기가 레포 쪽 파일을 열어 두기 쉬워서 걸리기 좋은 함정이다. 순서는 다른
라이싱 파일과 같다:

```sh
$EDITOR ~/.config/ghostty/shaders/crt.glsl   # 여기서 고치고
apps/rice-term crt                            # 바로 확인
apps/rice-save                                # 마음에 들면 레포로
```

지금 둘이 어긋났는지 보려면 `apps/rice-save --check` 다.

## 새 룩 만들기

셰이더를 새로 짤 필요는 없다. `crt.glsl` 의 `TINT` 한 줄만 바꿔도 호박색
단색 브라운관이 나온다.

```sh
cd ~/.config/ghostty
cp shaders/crt.glsl shaders/amber.glsl     # TINT 를 vec3(1.15, 0.85, 0.45) 로
sed 's|shaders/crt.glsl|shaders/amber.glsl|' rices/crt.conf > rices/amber.conf
apps/rice-term amber                        # 바로 확인
apps/rice-save                              # 마음에 들면 레포에 저장
```

셰이더는 Shadertoy 포맷이다 — `mainImage(out vec4, in vec2)` 를 정의하고
`iChannel0`(현재 터미널 화면), `iResolution`, `iTime` 을 쓴다. ghostty 고유
유니폼(커서 위치·색, `iTimeCursorChange`, `iPalette[256]` 등)까지 있어서
커서에 잔상을 붙이는 것도 된다. 전체 목록은:

```sh
ghostty +show-config --default --docs | grep -B120 '^custom-shader = '
```

## 고장났을 때

셰이더 컴파일 실패는 **설정 에러로 잡히지 않는다.** ghostty 문서가 명시하듯
설정 로딩이 끝난 뒤 렌더 스레드에서 컴파일되므로 `+validate-config` 는 통과하고,
로그에만 남는다. 최악의 경우 창이 새까매진다. `apps/rice-term` 은 존재하지 않는
셰이더 경로까지는 잡아 주지만 컴파일까지는 못 본다.

그 상태에서도 다른 터미널이나 fuzzel(`Mod+D`)에서 `apps/rice-term off` 를 돌리면
돌아온다. 그마저 안 되면 `~/.config/ghostty/rice.conf` 를 지우면 된다 — `?` 덕에
없는 게 정상 상태다.
