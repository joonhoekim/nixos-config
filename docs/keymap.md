# 키맵 — rift-grid (macOS)

macOS 의 창 관리자 rift-grid 의 키 배치. 설정 파일은 `modules/darwin/rice/rift-grid/config.toml` 이고, 이 문서는 그
`[keys]` 를 사람이 읽는 표로 옮긴 것이다. NixOS 의 창 관리자는 subline 이고 그 키는 subline 이 정한다(설정 앱의 키
페이지, `~/git/subline`).

**rift-grid 는 subline 의 ijkl 프리셋을 따른다.** rift-grid 의 워크스페이스가 subline 과 같은 격자라서, 격자를 다루는
키도 subline 과 같게 두었다. 두 기계를 오가도 손이 같은 자리를 누른다.

Caps Lock 레이어(커서·포인터)는 창 관리자와 별개다 — `modules/shared/kanata/README.md`.

## 규칙 셋

```
Mod          간다, 연다
Mod + Shift  창을 데리고 간다
Mod + Ctrl   모니터를 넘는다, WM 에게 말한다
```

예외가 하나 있다 — subline 을 따라 창을 격자 N 으로 보내는 키가 `Mod+Ctrl+숫자`다.

`Mod`는 macOS에서 **Alt**다(subline 에서는 Super). macOS가 Cmd를 시스템용으로 가져가기 때문에 선택지가 없었다.

## 방향은 IJKL

```
        I                 ↑
   J    K    L        ←   ↓   →
```

hjkl이 아니다. hjkl은 한 줄에 늘어선 네 개일 뿐 **모양이 없다** — vim 유산이지
공간이 아니고, 창 관리는 공간 작업이다. IJKL은 화살표와 같은 역T자라 손이 화면을
그대로 흉내낸다.

**화살표는 어느 티어에서든 같은 동작에 같이 걸려 있다.** IJKL이 흉내내는 대상이기도
하고, 손이 익는 동안의 안전망이기도 하다.

## 표

### 티어 1 — `Mod` : 간다, 연다

| 키 | 무엇 |
|---|---|
| `Mod+I` `Mod+K` `↑` `↓` | 포커스 위 / 아래 |
| `Mod+J` `Mod+L` `←` `→` | 포커스 왼 / 오른 |
| `Mod+1`..`9` | 격자 N |
| `Mod+Tab` | 직전에 포커스가 있던 창 (어느 칸·격자에 있든, 다시 누르면 돌아온다. subline 의 Alt+Tab, 창 줄은 없다) |
| `Mod+Return` | 터미널 (subline-terminal, 세션 목록부터) |
| `Mod+O` | 오버뷰 (rift-grid 의 격자 오버뷰) |
| `Mod+E` | 파일 관리자 (`open ~`, Finder) |
| `Mod+H` | 격자의 가운데 칸 |
| `Mod+Q` | 창 닫기 |
| `Mod+F` | 최대화 — **갭 유지** |
| `Mod+C` | 가운데로 |
| `Mod+=` `Mod+-` | 폭 넓게 / 좁게 |
| `Mod+R` | monocle (폭 프리셋 순환 자리) |
| `Mod+,` | rift-grid 설정 창 (`rift-grid-cli settings`) |
| `Mod+Shift+/` | 치트시트 (이 문서를 연다) |
| `Mod+Shift+S` | 영역 스크린샷을 클립보드로 (`screencapture -i -c`) |

### 티어 2 — `Mod+Shift` : 창을 데리고 간다

| 키 | 무엇 |
|---|---|
| `Mod+Shift+IKJL` + 화살표 | 창 이동 (4방향) |
| `Mod+Shift+F` | 전체화면 — **갭까지 덮음** |
| `Mod+Shift+Space` | 플로팅 토글 |

### 티어 3 — `Mod+Ctrl` : 모니터를 넘는다, WM에게 말한다

| 키 | 무엇 |
|---|---|
| `Mod+Ctrl+IKJL` + 화살표 | 창을 옆 모니터로 |
| `Mod+Ctrl+E` | 이웃과 합치기 / 떼기 |
| `Mod+Ctrl+R` | 설정 다시 읽기 |
| `Mod+Ctrl+1`..`9` | 창을 격자 N 으로 보내고 나는 남는다 |
| `Mod+Ctrl+Shift+1`..`4` | 레이아웃 모드 |

### 그 밖

| 키 | 무엇 |
|---|---|
| `Mod+Z` | 이 space 를 rift-grid 관리에서 빼기 |
| `Mod+/` | 방향 토글 |
| `Mod+Shift+,` | 스택 토글 |
| `Mod+Ctrl+Space` | 플로팅 창으로 포커스 |
| `Mod+Cmd+IJKL` | 격자의 옆 칸으로 (칸 단위) |

`Mod+Shift+/` 는 **이 문서를 에디터에 연다.** 그 대가는 이 문서가 낡으면 치트시트도 같이 낡는다는 것이다. rift-grid
에 키를 더하면 위 표도 같이 고쳐야 한다. 같은 것을 rift-grid 에게 직접 물어보려면:

```sh
rift-grid-cli execute config get | jq -r '.binding_mode_specs[] | select(.[0] == "default") | .[1][] | "\(.[0])\t\(.[1])"'
```

`Mod+Ctrl+E` 는 지금 컬럼 상태를 보고 뒤집힌다 — 혼자면 옆 창을 데려와 한 컬럼에 쌓고, 이미 쌓여 있으면 활성 창만
빼내 제 컬럼으로 돌려놓는다(`consume_or_expel_window`). 합치는 방향은 오른쪽이다.

**rift-grid 의 워크스페이스는 3×3 격자다**(rift 포크, subline 과 같은 모델). 격자 하나에
칸이 왼쪽 위부터 줄마다 1..9 로 있고, 격자는 디스플레이마다 아홉 개라 `Mod+1`..`9`
가 격자를 고른다. `Mod+방향`·`Mod+Shift+방향`은 칸 안의 타일을 다루다가 칸 끝에서
옆 칸으로 넘어간다(창을 데리고 가는 것도 같다). 그래서 워크스페이스 앞뒤 키가 따로
없다. 칸 단위로만 옮기려면 아래 `Mod+Cmd+IJKL`. 로그인하면 격자 1의 가운데 칸(5)에서
시작하고, `Mod+H` 가 그 가운데 칸으로 돌아온다.

## 마우스로는 포커스가 가지 않는다

**클릭해야 포커스가 간다**(`focus_follows_mouse = false`).

호버 포커스와 키보드 타일러는 **누가 주도권을 갖는지에 대해 답이 다르다.**
포인터는 마지막으로 놓아둔 자리에 그대로 있으면서도 포커스에 대한 권리를 계속
주장한다. 키보드로 옮겨 간 창에 타이핑을 시작하면 첫 타가 커서 밑의 엉뚱한 창으로
들어갈 수 있고, 배경 창 위에서 스크롤하면 포커스를 통째로 빼앗긴다. 클릭을 요구하면
포커스가 포인터가 암시하는 것이 아니라 **내가 말하는 것**이 된다.

**반대 방향은 켜 두었다**(`mouse_follows_focus = true`). 키보드로 포커스를
옮기면 커서가 그 창으로 끌려간다 — 그래서 위 설정이 싸게 먹힌다. 마우스를 잡는
순간 이미 맞는 창 위에 있다.

## 검증

설정을 다시 읽힌 뒤 `rift-grid-cli execute config get` 으로 키가 전부 등록됐는지 본다(2026-10-15 기준 72개).
