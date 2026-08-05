# 하이프랜드 키바인드 — 쓸 수 있는 것과, 왜 이렇게 뒀는가

`modules/nixos/hyprland/rice/hyprland.lua` 의 키바인드 절에 대한 참고 문서다.
지금까지 그 파일의 근거는 "니리에서 옮겼다" 한 줄뿐이었다. 그건 *배치*의
이유이지 *선택지*의 설명이 아니라서, 뭘 더 걸 수 있는지 알 수 없었고 실제로
죽은 바인드 셋이 한동안 살아남았다. 이 문서는 그 두 가지를 채운다.

- 하이프랜드 0.56.1, 설정은 Lua (hyprlang 아님)
- 레이아웃은 `scrolling` — 아래 `layoutmsg` 목록은 이 레이아웃 전용이다
- 아래의 모든 목록은 **돌고 있는 컴포지터에 직접 물어서** 뽑았다. 위키를 옮긴 게
  아니다. 뽑는 방법은 다음 절에 있다.

## 설정 파일이 두 벌인 것부터

| 경로 | 성격 |
|---|---|
| `modules/nixos/hyprland/rice/hyprland.lua` | 리포. 커밋되는 원본 |
| `~/.config/hypr/hyprland.lua` | 실제로 읽히는 사본. 평범한 쓰기 가능 파일 |

`../default.nix` 의 활성화 스크립트는 **파일이 없을 때만** 복사한다(`seed`).
그러니 리포만 고치고 리빌드해도 살아있는 세션은 안 바뀐다. 고쳤으면 둘 다
맞춰야 한다:

```sh
cp modules/nixos/hyprland/rice/hyprland.lua ~/.config/hypr/hyprland.lua
```

저장하면 하이프랜드가 알아서 리로드한다. 문법이 깨졌으면 에러만 찍고 직전 설정이
계속 돈다 — 즉 **조용히 실패하지는 않지만, 조용히 아무 일도 안 일어날 수는 있다.**
이 문서의 "함정" 절이 대부분 그 이야기다.

## 확인하는 법

리빌드도 리로드도 없이 바인드 한 줄을 그 자리에서 시험할 수 있다. 설정에
`hl.bind(key, ACTION)` 으로 적을 `ACTION` 을 그대로 `hyprctl dispatch` 에 넘기면
된다:

```sh
hyprctl dispatch 'hl.dsp.window.fullscreen({mode="maximized", action="toggle"})'
hyprctl dispatch 'hl.dsp.layout("colresize +conf")'
```

반환값 세 가지의 뜻이 다르다:

| 반환 | 뜻 |
|---|---|
| `ok` | 받아들여졌다. **동작했다는 뜻은 아니다** — 아래 함정 2 참고 |
| `warning: ...` | 디스패처까지 갔지만 대상을 못 찾았다 (`hl.focus: window not found`) |
| `error: ...` | 이름이나 인자가 틀렸다 (`no such layoutmsg for scrolling`) |

`hyprctl keyword` 는 못 쓴다. Lua 설정에서는 파서가 통째로 거절한다
(`keyword can't work with non-legacy parsers. Use eval.`). 남는 길은 `eval` 이다.

`hyprctl eval` 은 값을 안 돌려주고 `ok` 만 찍는다. Lua 쪽 `io` 는 열려 있으니,
내부 상태를 볼 때는 파일로 빼면 된다. 이 문서의 목록도 전부 이렇게 뽑았다:

```sh
hyprctl eval '
  local t = {}
  for k, v in pairs(hl.dsp) do t[#t+1] = k .. " (" .. type(v) .. ")" end
  table.sort(t)
  local f = io.open("/tmp/dsp.txt", "w") f:write(table.concat(t, "\n")) f:close()'
cat /tmp/dsp.txt
```

지금 걸린 것 전부 보기: `hyprctl binds` (또는 `-j`). 파일의 `hl.bind` 개수와
여기 개수가 다르면 어딘가 등록에 실패한 것이다.

## 쓸 수 있는 것

### 키 문자열

`hl.bind("SUPER + SHIFT + F", ...)`. 대소문자까지 정확히 같아야 하고 — 특히
`hl.unbind()` 로 풀 때 — 마우스 버튼은 `mouse:272`(좌), `mouse:273`(우)에
`{ mouse = true }` 를 준다. 세 번째 인자로 옵션:

```lua
{ locked = true }     -- 잠금 화면에서도 먹는다 (니리의 allow-when-locked)
{ repeating = true }  -- 누르고 있으면 반복
{ mouse = true }      -- 마우스 버튼 바인드
```

### `hl.dsp.*` — 디스패처

```
cursor(table)  dpms  event  exec_cmd  exec_raw  exit  focus  force_idle
force_renderer_reload  global  group(table)  layout  no_op  pass
release_input_capture  send_key_state  send_shortcut  submap
window(table)  workspace(table)
```

`hl.dsp.window.*`:

```
alter_zorder  bring_to_top  center  clear_tags  close  cycle_next
deny_from_group  drag  float  fullscreen  fullscreen_state  kill  move
pin  pseudo  resize  set_prop  signal  swap  tag  toggle_swallow
```

`hl.dsp.workspace.*`: `change_id  move  rename  swap_monitors  toggle_special`
`hl.dsp.group.*`: `active  lock  lock_active  move_window  next  prev  toggle`
`hl.dsp.cursor.*`: `move  move_to_corner`

인자 모양(검증한 것만):

```lua
hl.dsp.focus({ direction = "l"/"r"/"u"/"d" })   -- 축약형도 먹는다
hl.dsp.focus({ workspace = "e+1" })             -- 또는 번호
hl.dsp.focus({ window = "address:0x..." })      -- 위치 키워드가 아니라 셀렉터다
hl.dsp.window.move({ direction = ... })         -- focus 와 같은 값
hl.dsp.window.move({ workspace = "e+1" })
hl.dsp.window.fullscreen({ mode = "fullscreen"/"maximized", action = "toggle" })
hl.dsp.window.float({ action = "toggle" })
```

### `layoutmsg` — 스크롤링 레이아웃 전용

`hl.dsp.layout("<이름> <인자>")`. **유효한 이름은 아홉 개가 전부다**(그 밖의
이름은 `no such layoutmsg for scrolling`):

| 이름 | 상태 |
|---|---|
| `focus l/r/u/d` | 검증함. 끝에서 감싸 돈다 |
| `swapcol l/r` | 이름·인자 검증함 (잘못된 방향은 `no target`) |
| `colresize +0.1 / -0.1 / +conf` | 검증함. `+conf` 는 `explicit_column_widths` 순환 |
| `fit_into_view` | 검증함 |
| `center` | 이름만 확인, 동작 미검증 |
| `promote` | 이름만 확인, 동작 미검증 |
| `expel` | 이름 확인 (`column has only one window` 경고를 돌려줌) |
| `consume` | 이름만 확인, 동작 미검증 |
| `move` | 이름 확인 (`failed to parse offset` — 오프셋 인자를 받는다) |

`consume`/`expel` 은 니리의 consume-or-expel-window 에 해당할 가능성이 높지만
확인하지 않았다. `promote`/`center`/`move` 도 마찬가지다. **지금 어디에도 안
걸려 있고, 걸기 전에 위 "확인하는 법"으로 한 번 눌러보고 걸어야 한다.**

### `hl.*` — 조회 함수

바인드를 함수로 쓸 때(`hl.bind(key, function() ... end)`) 쓸 수 있는 것들이다.
디스패처만으로 안 되는 걸 여기서 만든다.

```
get_active_monitor  get_active_special_workspace  get_active_window
get_active_workspace  get_config  get_current_submap  get_cursor_pos
get_last_window  get_last_workspace  get_layers  get_loaded_plugins
get_monitor  get_monitor_at  get_monitor_at_cursor  get_monitors
get_urgent_window  get_window  get_windows  get_workspace
get_workspace_windows  get_workspaces  is_key_down  version
```

`get_windows()` 가 돌려주는 원소는 테이블이 아니라 `HL.Window` userdata 다.
`__index` 가 함수라서 필드를 열거할 수 없으니, 확인한 것만 적어 둔다:

```
at.x  at.y  size  class  initial_class  title  address  workspace(userdata)
floating  monitor(userdata)  pid  hidden  mapped  fullscreen  tags
```

`at.x` 는 화면 좌표라 스크롤 위치가 반영된다(왼쪽으로 밀려난 컬럼은 음수).
컬럼 순서를 알아내는 데 그대로 쓸 수 있다는 뜻이다.

함수 안에서 디스패처를 부를 때는 **한 번 감싸야 한다.** `hl.dsp.focus({...})` 는
실행이 아니라 디스패처 객체를 만들 뿐이다:

```lua
hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
```

`hl.bind(key, hl.dsp.focus({...}))` 가 되는 건 `bind` 가 그 객체를 받기 때문이고,
그래서 함수 본문에서는 `hl.dispatch` 가 더 필요하다.

### DMS IPC

셸이 주는 것은 `dms ipc` 로 전부 나온다(타깃 50여 개). 지금 쓰는 것들:

```
spotlight toggle | toggleQuery ':'      clipboard toggle    notifications toggle
control-center toggle                   settings toggle     powermenu toggle
lock lock                               hypr toggleOverview
keybinds toggle <provider>              audio increment|decrement|mute
mic mute                                brightness increment|decrement
```

인자 개수가 틀리면 친절하게 알려준다 — 이름만 맞으면 되는 게 아니다:

```
$ dms ipc call keybinds toggle
Too few arguments provided (1 required but 0 were provided.)
Function definition: function toggle(provider: string): string
```

## 지금 배치와 이유

전체 원칙 하나: **키 배치는 `modules/nixos/niri/rice/config.kdl` 에서 옮겼다.**
두 세션을 오가며 쓰기 때문에 근육기억이 갈리는 게 제일 큰 비용이다. 그래서
"하이프랜드에서 더 자연스러운 배치"보다 "니리와 같은 배치"를 항상 우선한다.
아래 표의 "왜"는 그 원칙으로 설명되지 않는 것만 적었다.

### 프로그램·셸

| 키 | 하는 일 | 왜 |
|---|---|---|
| `Mod+Return` | ghostty | |
| `Mod+D` | fuzzel | 셸이 안 뜬 상태에서도 터미널을 열 수 있는 폴백. 스포트라이트와 중복이지만 그게 목적이다 |
| `Mod+space` | 스포트라이트 | |
| `Mod+V` `Mod+N` `Mod+S` `Mod+comma` | 클립보드 / 알림 / 컨트롤센터 / 설정 | |
| `Mod+Escape` | 파워메뉴 | 로그아웃·재부팅의 **유일한** 입구. 메뉴라서 되돌릴 기회가 있다 |
| `Mod+L` | 잠금 | 이 자리가 잠금이라 "오른쪽으로 포커스"가 `Mod+L` 에 못 들어간다 |
| `Mod+Shift+/` | 치트시트 | 셸이 `hyprland.lua` 를 읽어서 만든다 |
| `Mod+O` | 오버뷰 | 니리엔 없다. 셸이 하이프랜드에서만 주는 것 |

DMS 자체 키바인드 묶음(`dms/binds.lua`)은 **일부러 안 읽는다.** 하이프랜드는 같은
키에 걸린 바인드를 위에서부터 *전부* 실행한다 — 니리처럼 나중 것이 앞 것을 덮지
않는다. 그대로 두면 겹치는 키가 토글을 두 번 때려 아무 일도 안 일어난다.

### 창·레이아웃

| 키 | 하는 일 | 왜 |
|---|---|---|
| `Mod+Q` | 닫기 | |
| `Mod+F` / `Mod+Shift+F` | maximized / fullscreen | |
| `Mod+Shift+space` | 플로팅 토글 | |
| `Mod+H` `Mod+←` `Mod+→` | 컬럼 간 포커스 | `layoutmsg` 로 간다. 끝에서 감싸 돌고 옆 모니터로 안 샌다 |
| `Mod+J/K` `Mod+↑↓` | 컬럼 *안*의 위아래 | 이쪽은 평범한 방향 포커스 |
| `Mod+C` | `fit_into_view` | 니리의 center-column 자리. 같지는 않다 — 정렬은 `focus_fit_method` 가 정한다 |
| `Mod+Ctrl+*` | 창 이동 (컬럼 스왑 / 상하) | |
| `Mod+=` `Mod+-` | 폭 ±0.1 | |
| `Mod+R` | 폭 프리셋 순환 | 0.333 → 0.5 → 0.667 |
| `Mod+U/I`, `Mod+Ctrl+U/I` | 워크스페이스 이동 / 창까지 데려가기 | 니리는 세로로 쌓이고 하이프랜드는 번호가 붙지만, U/I 가 아래/위라는 감각은 같다 |
| `Mod+1..5` | 워크스페이스 직행 | |
| `Mod+마우스좌/우` | 드래그 / 리사이즈 | 니리엔 없다. 하이프랜드에선 관용이고 뜬 창에 편하다 |

### 스크린샷·미디어·리싱

| 키 | 하는 일 | 왜 |
|---|---|---|
| `Print` / `Ctrl+Print` / `Alt+Print` | 영역 / 화면 / 활성창 | 니리는 컴포지터가 직접 찍지만 하이프랜드는 아니라 `hyprshot`. `-m window` 만 주면 창을 고르라고 기다려서, 니리처럼 묻지 않게 `-m active` 를 덧붙인다 |
| `XF86*` | 볼륨·마이크·밝기 | 전부 `locked = true` — 잠금 화면에서도 먹어야 한다 |
| `Mod+Shift+P` | 프로필 다음 것 | 하이프랜드에선 **반만 적용된다.** 니리 조각(`profile.kdl`)은 여기서 아무 일도 안 하고 DMS 조각만 먹는다 |
| `Mod+Shift+W` / `Mod+Ctrl+W` / `Mod+Alt+W` | 벽지 / 골라서 / yazi 로 | |
| `Mod+Shift+R` | 리싱 메뉴 | 축마다 키를 하나씩 두는 것보다, 프로필·셰이더·터미널·벽지가 한 목록에 있는 게 값 맞출 때 빠르다 |
| `Mod+Shift+C` | CRT 셰이더 순환 | 끔 → crt → crt-motion. 자세한 건 `postmortems/2026-08-04-hyprland-crt.md` |

## 남는 키

`hyprctl binds` 기준. 글자키만 추렸다.

| 조합 | 비어 있는 글자 |
|---|---|
| `Mod` | a b e g m p t w x y z |
| `Mod+Shift` | a b d e g h i j k l m n o q s t u v x y z |
| `Mod+Ctrl` | a b c d e f g l m n o p q r s t v x y z |
| `Mod+Alt` | w 를 뺀 전부 |

`Mod+Shift+E` 는 **의도적으로 비워 둔 자리다.** 로그아웃이 걸려 있던 곳이고,
같은 이유로 다시 채우면 안 된다 — 아래 "뺀 것" 참고.

## 함정

**1. 겹친 바인드는 둘 다 실행된다.** 니리처럼 덮어쓰지 않는다. `dms/binds-user.lua`
에서 이미 잡힌 키를 다시 잡으려면 `hl.unbind("SUPER + R")` 를 먼저 불러야 하고,
키 문자열은 대소문자까지 같아야 한다.

**2. `ok` 는 "동작했다"가 아니다.** 인자를 검증하는 디스패처와 안 하는 디스패처가
섞여 있다.

```
hl.dsp.window.fullscreen({mode="zzz", ...})  -> error: invalid mode "zzz"   ← 검증함
hl.dsp.window.move({direction="zzz"})        -> error: invalid direction    ← 검증함
hl.dsp.window.float({action="zzz"})          -> ok                          ← 안 함. 그냥 토글된다
hl.dsp.layout("focus zzz")                   -> ok                          ← 안 함. 아무 일도 안 함
hl.dsp.layout("colresize zzz")               -> ok                          ← 안 함
```

`float` 에 `action` 을 오타 내면 조용히 토글되고, 나중에 `"on"`/`"off"` 를
기대하고 쓰면 그것도 조용히 토글된다.

**3. `layoutmsg` 의 인자는 첫 글자만 읽는다.** `focus leftmost` 도, `focus last`
도, `focus l` 과 똑같이 **한 칸** 움직인다. 3컬럼에서 맨 끝부터 재서 확인했다.
첫 글자가 방향이 아니면(`first`, `begin`, `end`, `home`) 조용히 아무 일도 안 한다.
즉 **끝 컬럼으로 뛰는 메시지는 없다.**

**4. `focus` 의 `window` 는 셀렉터다.** `class:`, `title:`, `address:` 를 받는
창 매칭이지 위치 키워드가 아니다. `"first"` 는 아무 창의 클래스도 아니라서
`hl.focus: window not found` 로 끝난다.

**5. 함수 본문에서는 `hl.dispatch` 로 감싸야 한다.** 위 "조회 함수" 절 참고.

**6. `hyprctl keyword` 는 안 된다.** `eval` 만 된다. CRT 셰이더처럼 자주 만지는
값은 `apps/rice-crt` 가 그 `eval` 을 감싸 두었다.

## 뺀 것

**`Mod+Shift+E` — 로그아웃 (`uwsm stop`).** 확인 없이 즉시 세션을 내렸다.
바로 옆이 `Mod+Shift+F`(풀스크린)와 `Mod+Shift+space`(플로팅)라 손 모양이 겹쳐
오타가 잦았다. 로그아웃은 `Mod+Escape` 파워메뉴로 간다. 다시 걸 일이 있으면
**`hl.dsp.exit()` 이 아니라 `uwsm stop`** 이다 — uwsm 세션에서 컴포지터를 직접
죽이면 클라이언트 밑에서 바닥을 빼는 꼴이라 유닛들이 어중간하게 남는다.

**`Mod+Home` / `Mod+End` — 첫/끝 컬럼 포커스.** 처음부터 죽어 있었다. 니리의
`focus-column-first`/`last` 를 `hl.dsp.focus({window="first"})` 로 옮겼는데,
함정 4 때문에 매칭에 실패하고 경고만 찍었다. 함정 3 때문에 `layoutmsg` 로 갈아탈
수도 없다.

되살리려면 조회 함수로 직접 만들어야 한다. 아래는 **동작을 확인한** 형태다:

```lua
local function focus_edge_column(edge)
    local aw = hl.get_active_window()
    if not aw then return end
    local best
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace == aw.workspace and w.mapped and not w.hidden and not w.floating then
            if not best
                or (edge == "first" and w.at.x < best.at.x)
                or (edge == "last" and w.at.x > best.at.x) then
                best = w
            end
        end
    end
    if best then hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address })) end
end

hl.bind(mod .. " + Home", function() focus_edge_column("first") end)
hl.bind(mod .. " + End", function() focus_edge_column("last") end)
```

한 컬럼에 창이 여러 개면 그중 누가 잡힐지는 정해지지 않는다(`at.x` 가 같다).
컬럼 단위 이동에는 상관없지만, 그게 걸리면 `at.y` 로 한 번 더 갈라야 한다.

지금은 걸지 않았다. 있는지도 모르고 지낸 키라 필요해지면 그때 붙인다.
