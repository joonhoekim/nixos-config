# 라이싱 도구 — 스위처, 기준선, 장식, 배치, 메뉴

`apps/rice/` 의 셸 스크립트 가운데 축 전환(프로필·터미널·월페이퍼·배치), 판정 기반(기준선·공통부), 그리고 라이싱
스튜디오와 런처의 뒤판을 모은다. 셰이더 체인·손잡이·저장/복원은 [rice-scripts.md](rice-scripts.md), 시드 규칙은
[rice-seeding.md](rice-seeding.md). macOS 의 `apps/rice/colors` 는 [macos-rice.md](macos-rice.md#appsricecolors).

라이싱은 축 여럿으로 나뉜다. 축마다 스위처가 하나씩 있고, 서로 독립이다.

| 축 | 스위처 | 무엇을 바꾸나 |
|---|---|---|
| 프로필 | `apps/rice/switch` | 니리 형태 + DMS 룩(색·투명도·둥글기) |
| 터미널 | `apps/rice/term` | ghostty 셰이더 |
| 월페이퍼 | `apps/rice/wall` | 벽지(matugen 이면 팔레트까지) |
| 화면 셰이더 | `apps/rice/crt` | 하이프랜드 출력 셰이더 ([rice-scripts.md](rice-scripts.md#appsricecrt--화면-셰이더-걸기)) |
| 배치 | `apps/rice/layout` | 하이프랜드 레이아웃과 그 키 |
| 장식 | `apps/rice/decor` | 하이프랜드 투명도·블러·그림자 |

## 기준선(baseline) — apps/rice/baseline.sh

라이싱 파일이 **마지막으로 동기화된 시점의 내용**을 따로 한 벌 보관해서, 레포와 라이브가 다를 때 "누가 고쳤나"를 답할 수
있게 한다.

쓰는 곳: `apps/rice/save`·`apps/rice/restore` 는 `. "$(dirname "$0")/baseline.sh"`, `modules/shared/rice-seed-helpers.nix`
는 `. ${../../apps/rice/baseline.sh}`. 두 자리에서 같은 파일을 읽는 것이 요점이다 — 판정 규칙이 두 벌이 되면 한쪽만 고친
날 조용히 어긋난다.

### 왜 필요한가

상태가 둘뿐이면(레포, 라이브) "다르다"는 알 수 있어도 누가 고쳤는지는 원리적으로 알 수 없다. 그러면 도구가 추측해야 하고
두 방향 모두 틀린다: 레포에만 더한 것은 이미 설정을 가진 머신에 영영 안 들어가고, 그 상태로 되받으면 라이브에 없는 그것이
레포에서 지워진다.

기준선이 있으면 상태가 셋이 된다:

| 라이브==기준선 | 레포==기준선 | 뜻 | 할 일 |
|---|---|---|---|
| O | O | 아무도 안 고침 | 아무것도 안 함 |
| O | X | 레포만 고침 | 라이브로 밀어넣기 (fast-forward) |
| X | O | 라이브만 고침 | 레포로 되받기 |
| X | X | 양쪽 다 고침 | 멈추고 알린다 |

라이싱 도중 리빌드를 해도 저장 안 한 작업이 안 날아간다 — 밀어넣기는 라이브가 손 안 닿았다고 증명됐을 때(2행)만 일어난다.

### 자리

`$XDG_STATE_HOME/rice/baseline` 아래에 대상 경로에서 `$HOME/` 만 뗀 모양 그대로 쌓는다(설정도 캐시도 아닌, 도구가 다음
판정을 하려고 들고 있는 상태라 state). 예: `~/.config/hypr/hyprland.lua` →
`~/.local/state/rice/baseline/.config/hypr/hyprland.lua`.

지워도 안전하다. 다음 리빌드가 라이브에서 다시 잡고(부트스트랩), 레포와 다르면 알려 준다. 잃는 것은 "누가 고쳤나"를 아는
능력 한 번뿐이다.

### 거르개(filter)

몇몇 파일은 라이브에만 있는 파생 줄을 달고 산다(fuzzel.ini 맨 위의 include — `apps/rice/fuzzel` 이 이 머신의 절대 경로로
붙인다). 그걸 그대로 담으면 스위처가 돌 때마다 "라이브가 바뀌었다"가 되어 판정이 무의미해진다. 그래서 기준선에는 비교에
쓰는 형태(거른 뒤)를 담는다. rice-save 와 rice-restore 가 같은 거르개를 비교에 쓰므로 규칙이 하나로 맞는다.

## 스위처 공통부 — apps/rice/lib.sh

스위처는 축마다 다르지만(프로필은 디렉터리, 터미널 룩은 .conf 파일) 보이는 부분은 같다: 인자 없이 부르면 목록, `--next`
로 순환, 없는 이름이면 목록을 보여주며 거절. 그 공통부가 `lib.sh` 다.

- `. "$(dirname "$0")/lib.sh"` 로 읽는다. `nix run .#rice-switch` 로 돌 때도 이 경로가 맞는다: mkApp 이
  `exec ${self}/apps/<name>` 를 하므로 `$0` 이 스토어 안의 apps 디렉터리이고 형제 파일이 같이 들어 있다 — rice-switch 와
  rice-wall 이 rice-fuzzel 을 부르는 방식과 같은 전제다.
- 쓰는 쪽이 채울 것: `rice_kind`("프로필"처럼 메시지에 들어갈 말), `rice_current_file`(현재 선택을 담은 파일),
  `rice_list()`(이름을 한 줄에 하나씩 정렬해 출력). 그리고 `rice_dispatch "$@"` 를 부르면 `RICE_NAME` 에 전환할 이름이
  담긴다. 목록 출력 같은 갈래는 거기서 처리하고 스크립트를 끝낸다(sourced 라 함수 안 exit 가 스크립트 전체를 끝낸다).
- 없는 이름이면 "그런 거 없다"만이 아니라 목록을 같이 보여준다.
- 배선 줄을 보장하는 `rice_ensure_line` 도 여기 있다([rice-seeding](rice-seeding.md#rice_ensure-배선-한-줄만-보장한다)).

## 프로필 전환 — apps/rice/switch

```sh
apps/rice/switch            # 현재 프로필과 목록
apps/rice/switch frosted    # 전환
apps/rice/switch --next     # 목록 순서대로 다음 것 (키에 바인딩하기 좋다)
```

재시작도 리빌드도 없다. 소비자가 전부 파일을 감시하기 때문이다: niri 는 config.kdl 과 그것이 include 한 파일까지 감시해
즉시 리로드하고, DMS 는 settings.json 에 watchChanges 를 건다(`Common/SettingsData.qml`).

프로필은 `~/.config/rice/profiles/<name>/` 에 두 조각으로 있다(규칙은 `modules/nixos/niri/rice/profiles/README.md`):

- `niri.kdl` → `~/.config/niri/profile.kdl` (통째로 교체). 조각만으로도 유효한 설정이어야 해서 `niri validate` 로 단독
  검증한다.
- `dms.json` → `settings.json` 에 jq 병합(오버레이). settings.json 에는 룩과 무관한 머신 상태(디스플레이 프로필, 위젯 사용
  기록 등)가 같이 있어서 통째로 갈면 그것까지 날아간다. 월페이퍼는 여기 없다 — session.json 에 따로 산다.

터미널은 프로필에 조각을 두지 않는다. ghostty 가 DMS/matugen 이 써 주는 `themes/dankcolors` 를 읽어 색은 이미 프로필을
따라오고, 남는 투명도·패딩 때문에 프로필마다 파일을 더 두는 대신 `~/.config/ghostty/config` 에서 한 번만 정한다. fuzzel 은
테마가 바뀌었으면 `--wait` 로 불러 matugen 의 비동기 팔레트 갱신을 기다린다(테마가 그대로면 팔레트도 그대로라 기다리지
않는다). 실패해도 런처 색이 한 박자 늦을 뿐이다.

## 터미널 룩 — apps/rice/term

```sh
apps/rice/term            # 현재 룩과 목록
apps/rice/term crt        # 전환
apps/rice/term --next
apps/rice/term off        # 셰이더 없는 기본 상태 — 탈출구
```

룩 하나 = `~/.config/ghostty/rices/<name>.conf` 조각 하나. 고른 조각을 `~/.config/ghostty/rice.conf` 로 복사하면 끝이다 —
config 끝의 `config-file = ?rice.conf` 가 그걸 읽고, ghostty 는 config-file 을 자기를 담은 파일보다 나중에 읽으므로 조각이
항상 본체를 이긴다. 셰이더 자체는 [ghostty-shaders.md](ghostty-shaders.md).

반영은 D-Bus 로 reload-config 액션을 보내서 한다. custom-shader 는 런타임에 바꿀 수 있는 키라 열린 창 전부에 즉시 적용된다.
손으로는 ctrl+shift+, 이고, ghostty 가 안 떠 있으면 다음에 뜰 때 읽는다. macOS 에서는 background-opacity 가 리로드로 안
바뀌어서(ghostty 문서) 셰이더는 바로 갈리는데 투명도만 그대로인 상태가 잠깐 보인다.

rice-switch 와는 다른 축이다. 프로필(amoled/frosted/matugen)은 색과 형태를 정하고, 여기는 터미널 셰이더만 정한다. 색은
ghostty 가 `themes/dankcolors` 를 읽어 프로필을 따라오므로 두 축을 엮을 이유가 없다. crt 를 켜 둔 채 프로필만 바꿔도
셰이더는 남는다. 셰이더 컴파일이 실패해 창이 새까매져도 이 스크립트는 다른 터미널이나 런처에서 돌릴 수 있다.

## 월페이퍼 — apps/rice/wall

`~/Pictures/Wallpapers`(또는 `RICE_WALLPAPERS`) 아래를 재귀로 훑는다.

```sh
apps/rice/wall                        # 전체에서 무작위
apps/rice/wall mountain               # 그 이름이 경로에 든 것 중 무작위
apps/rice/wall --pick [pattern]       # fuzzel 로 경로 목록에서 (빠름)
apps/rice/wall --yazi [pattern]       # yazi(터미널 파일 관리자)로 미리보기 보며
apps/rice/wall --list [pattern]
apps/rice/wall --categories
apps/rice/wall /path/to/img.jpg       # 그 파일로
```

적용은 DMS 에 맡긴다(`dms ipc call wallpaper set`). 직접 파일을 쓰지 않는 이유는 월페이퍼가 session.json 에 기록되고 그
변경이 matugen 재생성을 촉발하기 때문이다 — 프로필이 matugen 이면 셸·니리 보더·터미널 팔레트가 이 한 번의 호출로
따라온다. fuzzel 만 이 흐름 밖이라 `apps/rice/fuzzel --wait` 를 따로 부른다. yazi 는 ghostty 밖에서는 sixel 이나 chafa 로
알아서 낮춰 잡는다.

## fuzzel 색 — apps/rice/fuzzel

```sh
apps/rice/fuzzel           # 지금 팔레트로 다시 만든다
apps/rice/fuzzel --wait    # 팔레트 파일이 갱신될 때까지 최대 8초 기다렸다가
```

fuzzel 은 Wayland 런처다. DMS 의 matugen 템플릿 목록은 소스에 하드코딩돼 있어서(`Common/Theme.qml`) fuzzel 을 끼울 수 없다.
대신 DMS 가 뽑은 팔레트를 `~/.cache/DankMaterialShell/dms-colors.json` 에 떨궈 두므로 그걸 읽어 fuzzel 색을 직접 쓴다.

쓰는 파일은 `dank-rice.ini` 하나다. fuzzel.ini 는 맨 위에서 그걸 include 하는데 그 줄은 이 스크립트가 붙인다 — include 는
절대 경로만 받고(홈 경로는 머신마다 다르다) 기본 섹션(첫 `[main]` 앞)에만 쓸 수 있어서 레포 시드에 넣을 수 없다. 형태(폰트/
여백/줄 수)와 색을 가르는 이유는 niri·ghostty 와 같다: 손으로 고치는 파일과 기계가 쓰는 파일이 섞이면 한쪽이 다른 쪽을
덮는다.

- 투명도와 곡률은 활성 프로필의 dms.json 에서 가져온다(팝업이라 `popupTransparency`, 곡률은 `cornerRadius`). 이 두 값이
  이미 같은 뜻이라 프로필에 fuzzel 전용 조각이 필요 없다.
- 팔레트가 아직 없으면(첫 로그인, DMS 가 안 뜬 상태) 시드된 dank-rice.ini 의 중성 폴백이 남는다.
- 창 높이 비율은 `RICE_FUZZEL_RATIO`(기본 0.8)로, fuzzel.ini 의 보더·여백·줄높이 값을 읽어 줄 수로 역산한다.

## 장식 값 — apps/rice/decor

하이프랜드 장식 값(투명도·흐리게·어둡게·그림자)을 밖에서 읽고 쓰는 뒤판. 라이싱 스튜디오의 「장식」탭이 쓴다.

```sh
apps/rice/decor                              # 값 전부 JSON
apps/rice/decor set decoration:blur:size 6
apps/rice/decor reset [키]                   # 기본값으로, 안 주면 전부
apps/rice/decor --file                       # 쓰는 파일 경로
```

### 왜 조각 파일 하나를 따로 소유하는가

값을 넣을 자리가 셋인데 둘은 막혀 있다.

- `~/.config/hypr/hyprland.lua` — 손으로 고치는 파일이다. 프로그램이 같이 쓰기 시작하면 그 약속이 깨진다.
- `~/.config/hypr/dms/layout.lua` — DMS 가 SettingsData 로부터 통째로 재생성한다("Auto-generated by DMS — do not edit
  manually"). 여기 적으면 다음 설정 변경에 말없이 날아간다.

그래서 셋째 자리 `~/.config/hypr/decor.lua` 를 이 스크립트만 쓰고, hyprland.lua 가 그것을 DMS 조각들 **뒤에** 한 줄로 부른다.

### 겹치는 값은 다루지 않는다

`hl.config` 는 카테고리를 통째로 갈지 않고 키 단위로 병합한다(layout.lua 가 general 을 다시 쓰는데도 hyprland.lua 의
`layout = "scrolling"` 이 살아 있다). 그래서 뒤에 와도 남의 값을 안 밟지만, 같은 키를 쓰면 반드시 밟는다.
`gaps_in`·`gaps_out`·`rounding`·`border_size` 는 DMS 설정 GUI 가 소유해서 표에서 뺐다. 여기서 또 쓰면 그쪽 슬라이더가
조용히 무효가 되고, 증상("DMS 에서 둥글기를 바꿨는데 안 바뀐다")만으로는 원인이 이 파일이라는 걸 알 수 없다.

### 왜 표가 이 파일에 있는가

`apps/rice/knobs` 는 셰이더가 `// @0..1` 로 손잡이를 스스로 선언해서 목록이 없다. 하이프랜드 옵션에는 그런 자기 선언이
없다 — `hyprctl getoption` 은 타입과 지금 값뿐이고 범위·기본값·설명이 없다. 그래서 표가 하나 필요하고 그게 여기다. 값을
늘리려면 표에 한 줄 넣으면 되고 스튜디오는 안 고친다. 기본값은 하이프랜드 0.56 기준(조각을 안 건 세션에서 `hyprctl
getoption <키>` 로 확인).

### 파일과 eval 둘 다 하는 이유

파일은 다음 세션까지 남기고, `hyprctl eval` 은 지금 화면에 건다. `hyprctl reload` 는 설정을 통째로 다시 읽어 화면
셰이더까지 지워서, 슬라이더를 끄는 동안 초당 몇 번씩 할 수 없다. lua 설정에서는 `hyprctl keyword` 가 거절당하므로(파서가
다르다) 남는 길이 eval 이다.

이 분업은 hyprland.lua 가 decor.lua 를 `require` 가 아니라 **`dofile`** 로 읽어야 성립한다. require 된 파일은 하이프랜드가
감시해서 파일을 다시 쓸 때마다 리로드가 일어난다(실측 2026-08-12 — dofile 로 읽은 파일은 감시 목록에 안 들어간다). 배선은
`modules/nixos/hyprland/default.nix` 가 ensure 로 보장한다.

### 되돌릴 곳은 레포가 아니라 기본값이다

다른 라이싱 축은 레포 사본과 견준다(rice-knobs 의 "레포와 다름"). decor.lua 는 생성물이라 레포에 시드가 없고 하이프랜드
기본값이 그 자리를 대신한다. 기본값과 같아진 값은 파일에서 빠지므로 **파일에 남은 줄이 곧 바꾼 것의 목록**이고, 아무것도
안 바꾼 머신의 decor.lua 는 빈 표다.

세션이 없으면 파일에만 적는다(다음 로그인에 읽히는 게 맞다). 그 사실을 JSON 의 `session` 으로 실어 창이 머리에 적게 한다 —
`apps/rice/layout` 과 같은 갈래.

## 하이프랜드 배치 — apps/rice/layout

```sh
apps/rice/layout                    # 현재 것과 목록
apps/rice/layout dwindle            # 리로드 없이 지금 세션에 갈아끼운다
apps/rice/layout --next
apps/rice/layout --reload           # 지금 것을 파일에서 다시 돌린다
apps/rice/layout --json             # 스튜디오가 창을 그리는 데 쓰는 것 전부
apps/rice/layout get [이름]
apps/rice/layout set <이름> <키> <값>
apps/rice/layout reset <이름> [키]   # 레포 값으로
apps/rice/layout --file [이름]
```

배치 하나 = `~/.config/hypr/layouts/<이름>.lua` 하나. `general.layout` 과 그 레이아웃의 값 블록과, 그 레이아웃에서만 뜻이
있는 키바인드가 한 파일에 있다. 어느 것을 쓰는지는 `~/.config/rice/layout` 한 줄이고, hyprland.lua 가 뜰 때 그걸 읽어
dofile 한다(없으면 scrolling). 각 배치의 키는 [hyprland.md](hyprland.md#배치-파일과-체인).

### 왜 값 하나가 아니라 파일 하나인가

`general.layout` 만 바꾸면 컬럼 사이 이동·폭·합치기 키가 `Unknown layoutmsg` 로 조용히 죽는다 — 레이아웃마다 디스패처
이름이 다르다(scrolling 의 colresize, dwindle 의 togglesplit). 값과 키를 한 파일에 묶으면 어긋날 자리가 없고, 새 레이아웃을
만드는 일도 파일 하나를 쓰는 일이 된다.

### 리로드 없이 갈아끼운다

`hyprctl reload` 는 설정을 통째로 다시 읽으면서 걸어 둔 화면 셰이더까지 지운다. 그래서 eval 로 세 단계를 한다:

1. 옛 파일을 `hl.bind` 를 "키만 받아 적는 함수"로 바꿔 둔 채 한 번 돌려 그 파일이 걸었던 키를 전부 알아낸다. 파일을
   파싱하지 않으므로 키 문자열이 `mod .. " + J"` 처럼 조립돼 있어도 실제 값이 나온다.
2. 그 키들을 `hl.unbind` 한다. 새 파일이 안 쓰는 키(dwindle 의 T/P/대괄호)가 남아 두 레이아웃의 키가 섞이는 일이 없어진다.
3. `hl.bind` 를 "먼저 풀고 거는 함수"로 바꾼 채 새 파일을 돌린다. 하이프랜드는 같은 키에 걸린 바인드를 전부 실행하므로 그냥
   걸면 한 키가 두 번 뛴다.

그래서 배치 파일은 몇 번을 다시 돌려도 같은 결과여야 한다 — 선언만 하고 상태를 쌓지 않는다. 돌리기 전에 `loadfile` 로
문법만 먼저 본다. 중간에 깨지면 옛 키는 풀렸는데 새 키는 반만 걸린 상태가 되는데, 그때는 `hl.bind` 를 되돌린 뒤 에러를 다시
던져 적어도 소리는 나게 한다.

### 값은 파일이 스스로 선언한다

셰이더의 `// @0..1` 과 같은 규약이다. `name = 0.5, -- @0.2..0.9:0.05 설명` 처럼 `@` 가 붙은 값만 손잡이가 되고, 불리언은
`-- @bool`. 설명은 바로 위 주석 덩어리와 `@범위` 뒤의 글자, 구역은 `-- ── 이름 ──` 줄이다. 손잡이 목록을 스크립트가 들고
있지 않으므로 새 배치 파일을 넣어도 스크립트는 안 고친다.

- 손잡이 이름은 키 이름 하나(`column_width`)라, 한 파일 안에서 같은 키가 두 테이블에 있으면 첫 것만 고쳐진다 — 그런 일이
  있으면 배치 파일을 고친다.
- 눈금이 없으면 정수는 1, 실수는 범위의 1/100.

### 로컬만 고친다

쓰는 곳은 언제나 `$HOME` 쪽이다. 레포(`modules/nixos/hyprland/rice/layouts`, `RICE_REPO` 로 바꿀 수 있다)는 비교 대상으로만
읽어 "레포와 다른 값"을 표시하고 되돌릴 수 있게 한다. 레포에 넣는 것은 `apps/rice/save` 다.

## 런처 메뉴 뒤판 — apps/rice/menu

라이싱 축 전부를 한 창에서 고르기 위한 뒤판. DMS 런처 플러그인(RiceSwitcher, [dms-plugins.md](dms-plugins.md))이 읽고 쓴다.

```sh
apps/rice/menu                   # 축과 값 전부 JSON
apps/rice/menu profile amoled
apps/rice/menu shader studio     # 스튜디오 열기
apps/rice/menu shader off        # 탈출구
apps/rice/menu wall pick
```

### 왜 스크립트가 하나 더 필요한가

축마다 스위처가 있지만 인터페이스가 조금씩 다르다 — 셋은 `--list`/`--current` 를 갖는 목록형이고, 월페이퍼는 목록이 아니라
동작이며, 셰이더는 하이프랜드 세션에만 있다. 플러그인(QML)이 그 차이를 알면 스위처를 고칠 때마다 QML 도 고쳐야 한다.
그래서 차이를 여기서 흡수하고 플러그인에는 한 모양만 준다: 축 = `{ id, label, icon, keywords[], current, values[],
actions[] }`. 새 축이 생겨도 QML 은 그대로다.

### keywords 는 영어 검색어다

라벨이 한글이라("프로필", "스튜디오 열기…") 영어로 치면 한 글자도 안 겹친다. 런처 점수기는 이름·부제가 0점일 때 keywords
를 보므로(DMS `Scorer.js`) 축과 동작마다 영어 별칭을 단다(`:studio`, `:wallpaper`, `:layout`). 플러그인은 이 목록을 항목에
싣고 자기 필터에도 쓴다. 한글은 이름에 이미 있어 안 적는다.

### 값의 출처는 각 스위처다

목록도 현재값도 따로 계산하지 않고 스위처에 묻는다. 셰이더의 현재값은 파일이 아니라 컴포지터가 알고 있어서(`apps/rice/crt`)
그 판단을 복제하면 두 곳이 어긋난다.

### 셰이더 축은 동작만 있다

셰이더 축은 "값 하나 고르기"라는 계약에서 벗어나서(여러 장을 쌓고 칸마다 손잡이가 있다) 스튜디오로 냈다. 여기 남은 것은
월페이퍼 축처럼 동작만 있는 축이다(값·meta·chain 없음). off 와 --next 는 탈출구라 스튜디오로 안 옮겼다.

### 경로

플러그인은 이 파일을 `$HOME/nixos-config/apps/rice/menu` 로 직접 부른다. 스토어 경로가 아닌 건 키바인드들과 같은 이유다
(`modules/nixos/niri/rice/config.kdl`): 라이싱 중에는 스크립트를 자주 고치는데 그때마다 rebuild 하고 싶지 않다.

## 라이싱 스튜디오 — apps/rice/studio

화면 셰이더를 고르고, 겹치고, 값을 맞추는 창을 띄운다(이미 떠 있으면 아무 일도 안 한다). 창의 구조와 왜 DMS 플러그인이
아니라 별도 창인지는 [rice-studio.md](rice-studio.md).

창 자체는 QML 이고 `~/.config/rice-studio` 에 시드된다(`modules/nixos/hyprland`). 다른 라이싱 파일과 같은 자리·규칙이라
rebuild 없이 고쳐진다. 껍데기가 하는 일은 셋이다.

1. `RICE_APPS` 로 스크립트 위치를 알려 준다 — QML 이 경로를 짐작하지 않아야 `nix run .#rice-studio` 로 띄웠을 때 스토어 쪽
   스크립트를 부른다.
2. `quickshell -n` 으로 두 번 안 뜨게 한다.
3. 없으면 왜 없는지 말해 준다.

셰이더를 거는 것은 하이프랜드에서만 되지만 값 맞추기와 합성 검증은 어디서나 되므로 막지 않는다.

## 배경화면 경로 — apps/rice/wallpaper-path.py

macOS 의 현재 데스크톱 배경화면 파일 경로를 찍는다. `apps/rice/colors`(인자 없이 불렀을 때)와
`modules/darwin/rice/default.nix` 의 wal-watch 에이전트가 같이 쓴다([macos-rice.md](macos-rice.md)).

- osascript 로 System Events 에 묻지 않는 이유: Automation 권한이 필요한데 LaunchAgent 에게는 그 권한 창이 뜨지 않아서,
  거부도 아닌 빈 문자열만 돌아오고 로그도 안 남는다. plist 는 자기 홈의 파일이라 권한이 필요 없다.
- 경로는 중첩된 바이너리 plist 안에 있어서 plutil 로 한 겹 벗겨도 base64 만 나온다. 그래서 바이트로 읽고 `file://` URL 을
  찾는다. URL 은 퍼센트 인코딩(`%20`, 한글은 `%ED%95%9C` 꼴)이라 풀어야 한다.
- macOS 기본 벽지(동적 벽지 등)는 파일이 아니라 URL 이 없다.
