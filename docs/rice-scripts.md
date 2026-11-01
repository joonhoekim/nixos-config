# 라이싱 스크립트 — 셰이더 체인, 손잡이, 저장과 복원

`apps/rice/` 의 셸 스크립트 가운데 화면 셰이더를 다루는 것(chain, crt, knobs)과 라이브 ↔ 레포를 오가는 것(save,
restore)의 쓰는 법과 세부. 나머지 스크립트(스위처, 기준선, 장식, 배치, 메뉴, 스튜디오 껍데기)는
[rice-tools.md](rice-tools.md). 화면 셰이더의 공통 규약은 `modules/nixos/hyprland/rice/README.md`, 이 스크립트들을 부르는
창은 [rice-studio.md](rice-studio.md).

모두 `nix run .#rice-<이름>` 으로도 부를 수 있지만, 라이싱 중에는 체크아웃의 `apps/rice/<이름>` 을 직접 부른다(스크립트를
고칠 때마다 rebuild 하지 않게).

## apps/rice/chain — 셰이더 여러 장을 한 장으로 접기

하이프랜드의 `decoration:screen_shader` 는 셰이더 한 장만 받는다(상류는 hyprwm/Hyprland#14101 에서 "합쳐서 써라"로
답했다). chain 은 여러 장(칸)을 순서대로 겹친 한 장을 만든다. 왜 합성이 필요한지, 비용이 합이 아니라 곱인 것, 탭 표,
`!motion` 은 `modules/nixos/hyprland/rice/README.md`. 여기는 스크립트 쪽 세부다.

### 쓰는 법

```sh
apps/rice/chain water/still print/paper  # 합성해서 결과 파일 경로를 낸다
apps/rice/chain --check crt/crt          # 합성과 검증만 (경로는 안 낸다)
apps/rice/chain --cost crt/crt neon      # 탭 곱만 (왜 거절당했는지 볼 때)
apps/rice/chain --stages <합성본>         # 그 파일이 어느 칸들로 만들어졌는지
apps/rice/chain --motion crt/crt         # 이 조합이 흐르는가 (yes/no)
apps/rice/chain --info-all <칸>...       # 칸마다 `<칸> <탭> <흐름>` (mtime 으로 캐시)
apps/rice/chain --addable <지금칸>...    # 후보를 stdin 으로, 붙일 수 있는 것만
apps/rice/chain --limit                  # 탭 한도 하나
```

칸 이름은 셋 중 하나다.
- `갈래/이름` → `~/.config/hypr/shaders/<갈래>/<이름>.frag`
- `term/<이름>` → `~/.config/ghostty/shaders/<이름>.glsl`
- 절대 경로

터미널 셰이더는 셰이더토이 규약(mainImage / iChannel0 / iResolution), 화면 셰이더는 하이프랜드 규약(main / tex /
screen_size)이라 껍데기가 다르지만, "화면 한 장을 받아 한 장을 낸다"는 점이 같아 한 체인에 섞인다. 터미널 셰이더를
복사하지 않고 부르는 것은 같은 셰이더가 두 벌이 되지 않게 하려는 것이다.

### 접는 방식 — 소스는 한 글자도 안 고친다

접는 방법은 전처리기뿐이다. 셰이더를 함수로 고치면 같은 파일이 맥에서·혼자 걸릴 때 안 돈다. 칸마다 이런 껍데기를 앞뒤에
두르고 파일 내용을 그대로 사이에 끼운다:

```glsl
#define v_texcoord _uv1        // 칸의 입력 좌표를 우리 전역으로
#define fragColor  _fc1        // 칸의 출력을 우리 전역으로
#define main       _p1_main    // 칸의 main 을 이름 있는 함수로
#define bloom      _p1_bloom   // 칸끼리 겹치는 이름을 갈라 놓는다
#define texture(_s, _c) _p0(_c)   // 이 칸의 tex 는 앞 칸의 출력이다
<파일 내용 그대로>
#undef …
vec4 _p1(vec2 _c) { _uv1 = _c; _p1_main(); return _fc1; }
```

`#define` 의 매크로 이름은 매크로 확장을 거치지 않으므로(GLSL ES 3.00 전처리기) 칸 안의 `#define BLOOM 0.32` 는 이름
바꾸기와 부딪히지 않는다. 그래서 칸이 선언한 `#define` 은 이름을 바꾸지 않고 칸이 끝날 때 전부 `#undef` 한다.

잘못 접히면 컴파일 에러로 죽고, 조용히 다른 그림이 나오는 길이 없다 — 맥 판이 GLSL→MSL 에 손치환기를 안 쓴 것과 같은
기준이다. 예외 하나는 셰이더가 직접 선언한 `uniform` 으로, 접기도 검증기도 통과하고 0 이 든 그림이 나오므로 chain 이
미리 거절한다.

### 탭 한도

`RICE_CHAIN_MAX_TAPS`(기본 64). 탭은 픽셀 하나를 그리려고 텍스처를 읽는 횟수이고, 체인의 비용은 칸별 탭의 곱이다. 레포에서
제일 무거운 한 장이 `crt/crt`(23탭)이고 한 탭짜리 마감 `term/glow` 를 붙이면 23 이다. 64 는 거기에 한 겹 더 얹을
여유이고, `crt/crt → cyberpunk/neon`(21탭, 곱 483)은 여기서 걸린다. 화면을 보고 판단하고 싶으면 환경변수로 올린다.

탭은 함수 단위로 세고 호출 횟수를 곱해 올린다 — `texture(tex` 가 몇 줄인지만 세면 bloom() 처럼 루프를 품은 함수를 두 번
부르는 경우를 놓친다.

### 결과 파일

`${XDG_CACHE_HOME:-~/.cache}/rice/shaders/` 에 쓴다. 손잡이를 고치면 원본이 바뀌므로 걸 때마다 다시 접는다
(`apps/rice/crt --reload`). 캐시를 통째로 지워도 다음에 걸 때 다시 만들어진다. 파일 이름은 `<슬러그>.<cksum>.frag` —
신원은 cksum 이 맡는다.

합성본 첫 줄 근처에 `// rice-chain: <칸> <칸>` 을 적는다. 컴포지터에게 "지금 뭐가 걸렸냐"고 물으면 이 경로만 돌아오는데,
경로만으로는 칸을 되짚을 수 없다. 칸 이름을 파일명에 인코딩하는 것보다 이쪽이 안 깨진다.

`--info-all` 캐시(`meta.tsv`)는 GUI 때문이다. 값마다 프로세스를 띄우면 열 몇 장에 awk 가 예순 번쯤 돈다 — 런처는 창을 열
때만 치러서 2초 캐시로 가렸지만, 열어 두고 만지는 GUI 에서는 가려지지 않는다.

## apps/rice/crt — 화면 셰이더 걸기

### 쓰는 법

```sh
apps/rice/crt                          # 현재 것과 목록만 출력
apps/rice/crt crt/crt                  # 한 장 걸기
apps/rice/crt water/still print/paper  # 즉석 체인 — 순서대로 겹쳐 건다
apps/rice/crt chain/bad-signal         # 저장해 둔 체인
apps/rice/crt --next                   # 목록 순서대로 다음 것 (Mod+Shift+C 와 같은 순환)
apps/rice/crt --reload                 # 지금 걸린 것을 파일에서 다시 읽는다 (값 튜닝용)
apps/rice/crt --save <이름>             # 지금 걸린 체인을 이름 붙여 저장
apps/rice/crt --stages                 # 지금 걸린 칸들을 한 줄에 하나씩
apps/rice/crt --json                   # 스튜디오가 창을 그릴 때 쓰는 것 전부
apps/rice/crt off                      # 셰이더 없는 상태로 (탈출구)
```

### 왜 hyprctl keyword 가 아니라 eval 인가

이 레포의 하이프랜드는 hyprland.lua 로 설정한다. 0.56 의 lua 파서에서 `hyprctl keyword` 는 `keyword can't work with
non-legacy parsers. Use eval.` 로 통째로 거절당한다. 밖에서 설정을 건드리는 길은 `hyprctl eval` 로 lua 한 줄을 밀어 넣는
것뿐이고, hyprland.lua 의 Mod+Shift+C 도 같은 hl.config 를 부른다.

### 현재값은 컴포지터에게, 파일은 리로드 복원용

다른 스위처들은 `~/.config/rice/<축>` 파일이 곧 진실이지만(lib.sh 의 `rice_current_file`) 이 축은 컴포지터에게 묻는다.
파일을 진실로 삼으면 `hyprctl eval` 로 직접 건 경우와 어긋나고, 낡은 파일을 보고 고른 "다음 것"은 엉뚱한 데로 뛴다.
hyprland.lua 의 키바인드도 같은 이유로 카운터를 안 들고 되읽는다.

그 기억은 설정 리로드를 못 넘긴다. 하이프랜드는 설정 파일과 require 된 조각이 바뀔 때마다 통째로 다시 읽으면서
screen_shader 를 비우고(리로드 평가 시점에 `hl.get_config` 가 빈 값을 주는 것까지 실측, 2026-08-12), DMS 는 테마·간격이
바뀔 때마다 `~/.config/hypr/dms/` 조각을 다시 쓴다 — 프로필 전환마다 셰이더가 날아간다. 그래서 apply 가 마지막으로 건
칸들을 `$RICE_STATE`(기본 `~/.config/rice/shader`)에 적고, 리로드 뒤 hyprland.lua 가 `--boot` 으로 도로 건다. 키바인드·
스튜디오·런처가 전부 이 스크립트를 거쳐 걸 때마다 파일을 다시 쓰므로 낡을 걱정은 없다. 서열은 그대로다: 읽기는 컴포지터,
파일은 컴포지터가 잊었을 때의 복원용.

### 두 축

`debug:damage_tracking` 은 셰이더가 걸리면 무조건 0, `debug:vfr` 은 `apps/rice/chain --motion` 이 흐른다고 할 때만 끈다.
이유와 표는 `modules/nixos/hyprland/rice/README.md`(「계속 그릴지는 셰이더가 정한다」)와
[hyprland.md](hyprland.md#화면-셰이더), 경위는 [postmortem](postmortems/2026-08-04-hyprland-crt.md). 셰이더를 새로 넣어도
두 판단 다 자동이다.

## apps/rice/knobs — 슬라이더 뒤판

라이싱 스튜디오의 슬라이더가 셰이더 값을 읽고 쓰는 뒤판이다.

### 쓰는 법

```sh
apps/rice/knobs                        # 조절 가능한 대상 목록 (JSON)
apps/rice/knobs get crt/crt            # 그 대상의 손잡이 전부 (JSON)
apps/rice/knobs set crt/crt CURVE 0.14
apps/rice/knobs reset crt/crt [CURVE]  # 레포 값으로 되돌린다
```

### 대상 이름

셰이더 칸 이름과 같다(`crt/crt` · `water/still` · `term/glow`). 종류(hypr / term)는 targets() 의 넷째 열에 있고 다시 거는
방법을 정하는 데만 쓰인다. 맥 판은 체인에서 이름이 겹칠 때 `1.BLOOM` 처럼 칸 번호를 붙이지만, 여기서는 손잡이가 파일 안의
`#define` 이라 파일 이름이 곧 유일한 주소다. 대신 targets 가 지금 걸린 체인의 몇째 칸인지(pass)를 같이 준다.

### 왜 파일을 다시 쓰는가

하이프랜드의 스크린 셰이더에 넘어오는 것은 tex / time / screen_size / pointer_* 뿐이고 그 목록은 컴포지터가 정한다. 값을
바꾸는 길은 셰이더 안의 `#define` 을 고치고 다시 거는 것뿐이다. 하이프랜드는 걸 때마다 파일을 새로 읽으므로
(`apps/rice/crt --reload` 가 그 성질을 쓴다) 쓰고 → 다시 걸면 즉시 반영된다. 슬라이더를 끄는 동안 초당 여러 번 하게
되므로 **부르는 쪽에서 디바운스를 거는 것을 전제로 한다.**

### 손잡이 선언

```glsl
#define CURVE       0.10   // @0..0.3
#define BLOOM       0.32   // @0..1:0.01      (선택: 뒤가 눈금)
#define GRAIN       0.030  // @0..0.15 !motion
```

- `@` 가 붙은 것만 손잡이다. BLOOM_TAPS 나 TAU 처럼 만질 것이 아닌 값은 표시를 안 하면 그만이라 목록 관리가 따로 필요
  없고, 새 셰이더를 넣어도 knobs 는 안 고친다.
- 설명은 `#define` 바로 위에 붙은 주석 덩어리와 `@범위` 뒤에 남은 글자를 쓴다. `// ── 형태 ────` 줄은 그룹 머리다.
- 숫자 값만 손잡이가 된다(vec3 을 태우면 되돌리기가 그 줄을 0.0000 으로 만든다).

### 로컬만 고친다

쓰는 곳은 언제나 `$HOME` 쪽이다. 레포는 비교 대상으로만 읽어 "레포와 다른 값"을 표시하고 되돌릴 수 있게 한다. 레포에 넣는
것은 값이 자리를 잡은 뒤 사람이 판단해서 `apps/rice/save` 로 한다. 레포 경로는 cwd 가 아니라 `$0` 의 체크아웃에서
찾고(DMS 안에서 불리므로), 안 되면 `~/nixos-config`.

## apps/rice/save — 라이브 → 레포

라이싱 파일은 Nix 가 관리하지 않는 보통의 쓰기 가능한 파일이다 — 니리가 저장 즉시 핫리로드하고 DMS 설정 GUI 가 자기
상태를 쓸 수 있게([rice-seeding](rice-seeding.md)). save 는 그 짝으로, 레포 사본은 백업이자 다음 머신의 시드이고 사람이
말할 때만 갱신된다.

흐름: `~/.config` 에서 고친다 → 라이브로 확인 → `apps/rice/save` → `git diff` → 커밋.

### 옵션

- `--check` — 검증하고 무엇이 다른지만 보고, 아무것도 안 쓴다.
- `--dms <프로필>` — DMS 설정 GUI 로 만진 룩을 그 프로필(`~/.config/rice/profiles/<프로필>/dms.json`)로 먼저 회수한다. 다른
  축은 파일을 고치고 저장하면 끝이지만 DMS 만 방향이 반대라(rice-switch 는 프로필 → settings.json 으로 밀어 넣기만 한다)
  이게 없으면 프로필 JSON 을 손으로 고쳐야 한다. 이미 프로필에 있는 키만 갱신하므로 키 집합이 안 변하고,
  `rice/profiles/README.md` 의 "프로필들이 같은 키 집합을 다룬다" 규칙이 저절로 지켜지며 diff 에는 만진 값만 뜬다.
- `--force` — 지금 켜 둔 프로필이 아닌 곳에 `--dms` 로 쓰는 것을 허용한다. 기본은 거절한다 — 화면에 없는 룩이 박히고
  되돌릴 방법이 diff 뿐이다.

### 기준선

"레포와 다르면 되받는다"는 방향을 못 가린다. 레포에만 더한 것(다른 머신에서 온 커밋, 손으로 쓴 주석)도 "다름"이라, 라이브를
손도 안 댄 파일이 되받기 한 번에 레포에서 지워진다. 그래서 `baseline.sh` 의 기준선을 함께 본다
([rice-tools.md](rice-tools.md#기준선baseline--appsricebaselinesh)). 라이브가 기준선과 같으면 아무도 라이브를 안 고쳤다는
증명이므로 "레포가 앞섬"이라고만 말하고, 맞추는 건 `apps/rice/restore` 나 리빌드의 몫이다.

### 안 받는 것과 이유

- `~/.config/niri/profile.kdl`, `~/.config/rice/current` — rice-switch 가 프로필에서 만든 파생물. 저장하면 "지금 켜 둔
  프로필"이 레포에 섞인다. 프로필을 고쳤다면 `profiles/` 를 고치고 rice-switch 를 다시 돌린다.
- `~/.config/ghostty/rice.conf`, `~/.config/rice/term` — rice-term 이 `rices/` 에서 복사한 것. 터미널 룩은 `rices/` 를 고친다.
- `DankMaterialShell/settings.json` 전체 — 키가 500 개 넘는 GUI 상태라 룩과 무관한 키가 diff 에 섞이고, 룩은 이미
  `profiles/*/dms.json` 이 갖고 있다. 새 머신은 DMS 기본값 위에 rice-switch 를 한 번 돌리면 된다. 되받을 것은 프로필이
  다루는 키뿐이고 그건 `--dms` 가 한다.
- `DankMaterialShell/themes/` — 레지스트리 테마는 파일로 복원해도 적용되지 않는다(`rice/profiles/README.md`).
- `~/.config/niri/dms/*.kdl`, `~/.config/hypr/dms` — DMS 가 settings.json 에서 매번 새로 만드는 파생물. 저장해 봐야 다음
  DMS 실행이 덮는 diff 소음뿐이다.
- `~/.config/rice/layout` — 지금 고른 레이아웃 이름은 머신 상태다. 레포의 기본은 늘 scrolling.
- DMS `plugin_settings.json` — DMS 가 켜고 끈 상태를 쓰는 파일이라 레포에는 "켠다"는 시드 한 줄만 있으면 된다.

### GTK

`gtk-settings.ini` 는 GNOME 용이 아니라 니리 용이다. 니리 세션에는 XSettings 를 방송하는 데몬이 없어 GTK 앱이 이 파일을
직접 읽는다. GNOME 쪽 경로는 `modules/nixos/home-manager.nix` 의 dconf 블록이라, GNOME 을 걷어내도 이 파일은 남고 유일한
경로가 된다. 되받을 값이 생기는 건 DMS 가 `SettingsData.qml` 의 `updateGtkIconTheme` 으로 `gtk-icon-theme-name` 을 써 넣기
때문이다. 레포에는 파일이 하나뿐이라(두 디렉터리에 같이 시드) gtk-3.0 을 정본으로 삼고, 3.0 과 4.0 이 어긋나면 알린다.
home-manager 의 `gtk` 모듈을 안 쓰는 이유는 [niri.md](niri.md#그-밖의-심기).

## apps/rice/restore — 레포 → 라이브

save 의 반대 방향이다. 평소에는 필요 없다 — 레포를 먼저 고친 흔한 경우(다른 머신에서 가져온 커밋, git 에서 되돌린 변경)는
리빌드의 `rice_sync` 가 기준선을 보고 라이브가 손 안 닿았으면 알아서 따라간다([rice-seeding](rice-seeding.md)). restore 는
rice_sync 가 일부러 손 떼는 자리를 위한 것이다: 라이브를 손댔는데 레포 것으로 덮고 싶을 때, 양쪽이 다 움직여 conflict 로
멈춘 뒤 레포 쪽을 고를 때, 리빌드를 기다리지 않고 지금 밀어 넣을 때. 즉 "사람이 레포를 고른다"는 명령이다.

### 쓰는 법

```sh
apps/rice/restore                 # 전부
apps/rice/restore ghostty niri    # 고른 것만
apps/rice/restore --check         # 무엇이 덮이는지만 보고 아무것도 안 쓴다
apps/rice/restore --yes           # 확인을 묻지 않는다 (키 바인딩·스크립트용)
```

### 대상

rice-save 가 저장하는 것과 정확히 같은 집합이어야 한다. 한쪽만 고치면 왕복이 안 맞는다.

| 대상 | 내용 | 세션 |
|---|---|---|
| niri | config.kdl, animations.kdl | 니리 |
| profiles | rice/profiles (프로필당 niri.kdl + dms.json) | 니리 |
| hypr | hyprland.lua, layouts/, shaders/, chains/ | 하이프랜드 |
| studio | ~/.config/rice-studio (라이싱 스튜디오 QML) | 하이프랜드 |
| dms | DankMaterialShell 플러그인 (레포에 있는 것 전부) | 두 리눅스 세션 |
| ghostty | config, rices/, shaders/ | 양쪽 |
| fuzzel | fuzzel.ini | 니리 |
| gtk | gtk-3.0 과 gtk-4.0 의 settings.ini (레포엔 파일 하나) | 니리 |
| wezterm | wezterm.lua | macOS |
| rift-grid | config.toml (키맵) | macOS |
| linearmouse | linearmouse.json (마우스 휠 방향) | macOS |
| helpers | rift-grid 키바인딩이 부르는 스크립트들 (rice/bin) | macOS |

플랫폼은 여기서만 가린다(uname). save 는 라이브가 없으면 "skip (absent)" 로 비켜 가지만, 방향이 반대인 restore 는 원본이
레포에 늘 있어 그대로 두면 맥에 니리 설정을 심는다.

ghostty 의 `themes/` 는 뺐다. save 도 저장하지 않고, 레포에 있는 것은 생성기가 없는 곳을 위한 폴백 팔레트라 덮으면
DMS/matugen 이 이 머신에 써 준 진짜 팔레트가 지워진다.

### 백업

덮기 전의 것은 `~/.config/rice/backups/<UTC 시각>/` 에 그 자리 그대로 쌓인다. 스크립트는 지우지 않는다 — 되돌릴 일은
대개 한참 뒤에 생기고, 텍스트 파일 몇 개라 무게가 없다. 정리는 그 디렉터리를 지우면 된다.

### 복원 뒤 다시 읽히기

대상 디렉터리를 `rm -rf` 뒤 `cp` 하므로 감시가 걸려 있던 아이노드가 사라진다. 그래서 대상마다 명시적으로 다시 읽힌다:

- hyprland.lua → `hyprctl reload`
- 셰이더 → `apps/rice/crt --reload`
- DMS 플러그인 → `dms ipc call plugins reload <id>`(plugin.json 을 바꿨으면 `dms restart`)
- rift-grid → `rift-grid-cli execute config reload`
- LinearMouse → JSON 검사 뒤 `launchctl kickstart`
- wezterm 은 디렉터리를 통째로 감시해 알아서 다시 읽고, helpers 는 키마다 새로 실행되는 스크립트라 할 일이 없다.
