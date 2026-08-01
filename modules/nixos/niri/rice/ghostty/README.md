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

**진짜 잔광(인광체 지속)은 불가능하다.** ghostty 가 셰이더에 주는 건
`iChannel0` = 현재 프레임 하나뿐이라, 이전 프레임을 섞어 꼬리를 남길 방법이
없다. 여기서 말하는 글로우는 전부 공간적인 번짐이지 시간적인 잔상이 아니다.
(다만 커서만은 예외다 — `iCurrentCursor` / `iPreviousCursor` /
`iTimeCursorChange` 가 있어서 커서 꼬리는 만들 수 있다.)

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
