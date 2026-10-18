# subline-terminal (macOS)

창을 닫아도, 앱을 끝내도 셸이 살아 있는 터미널. 이 문서는 그게 무엇인지와,
이 저장소의 `build-switch` 가 그것을 어떻게 까는지를 적는다. 터미널 자체의 설계는
그 레포(`~/git/subline-terminal`)의 `docs/design.md` 가 정본이다.

## 무엇인가

tmux 의 `new -s` / `ls` / `attach -t` 를 GUI 로 하는 터미널이다. 주된 쓰임은
Claude Code 같은 오래 도는 프로그램을, 창을 닫거나 앱을 다시 띄워도 그대로
살려 두는 것이다. 창 나누기·탭(터미널 속 터미널)은 없다 — 배치는 창 관리자
(rift)의 일이다.

| 조각 | 하는 일 |
|---|---|
| `subline-terminald` | 데몬. 세션(PTY 와 해석한 화면, 스크롤백)을 쥔다. 창이 없어도 출력을 계속 읽는다 |
| `subline-terminal` | 창. 세션 하나를 그리고 입력을 보낸다. 한 앱이 창 여럿을 띄운다(Dock 아이콘 하나) |
| `subline-terminal.app` | 위 둘을 담은 앱 묶음. `~/Applications` 에 깔린다 |

세션의 수명은 이렇다.

| 일 | 세션 |
|---|---|
| 창 닫기, Cmd+Q | 산다. `subline-terminal attach 이름` 이나 세션 목록(Cmd+L)으로 다시 붙는다 |
| 새 판 설치 | 산다. 데몬이 PTY 를 쥔 채 새 바이너리로 갈아타고, 떠 있던 창들도 새 판으로 다시 뜬다 |
| 로그아웃, 재부팅 | 끝난다. macOS 는 로그아웃 때 사용자의 프로세스를 모두 정리한다 — LaunchAgent(`user/` 도메인 포함)도 넘기지 못하는 것을 실측했다 |

데몬은 launchd 에이전트로 띄우지 않는다. 처음 필요한 창이나 셸이 띄운다.
로그아웃을 넘길 수 없으니 상시 에이전트가 줄 것이 없고, 에이전트(Background 세션)
에서는 Keychain 이 열리지 않아 Claude Code 의 로그인이 깨진다(이것도 실측).

### 쓰는 법

```sh
subline-terminal                # 새 세션의 창 (설정 start = "pick" 이면 세션 목록부터)
subline-terminal new [이름]      # 새 세션
subline-terminal attach 이름     # 있는 세션에 붙기
subline-terminal run -- 프로그램  # 셸 대신 그 프로그램을 도는 세션
subline-terminal ls              # 세션 목록
subline-terminal new -d [이름]   # 창 없이 세션만
subline-terminal kill 이름       # 세션 끝내기
```

앱이 떠 있을 때 셸에서 친 창 명령은 **그 앱에 창을 하나 더** 연다(그 셸의 폴더와
환경으로). Dock·Finder 로 띄우면 새 세션은 홈 폴더에서 시작한다.

키는 Cmd 바탕이고(Cmd+C/V/N/W/F/,/=/-/0, Cmd+↑/↓ 앞뒤 프롬프트), Ctrl 은 프로그램
몫, **왼쪽 Option 은 Meta**, 오른쪽 Option 은 macOS 가 만드는 글자를 친다. 한글은
macOS 입력기로 조합하고, 띄운 직후 첫 음절이 낱자모로 쪼개지는 macOS 의 버그를
앱이 피해 간다. 설정 파일은 `~/.config/subline-terminal/config.toml`(Cmd+, 로 그 자리에서 고친다).

## 어떻게 깔리나

nix 가 빌드하지 않는다. `build-switch` 가 시스템 전환을 마친 뒤 `apps/subline-terminal --auto`
를 부르고, 그 스크립트가 **이 기계에서** 소스를 빌드해 **이 기계의 서명 신원으로** 서명해 깐다.
`apps/rift-grid` 와 같은 꼴이다.

```
nix run .#build-switch
  └─ darwin-rebuild switch          (nix 가 하는 부분: 여기엔 subline-terminal 이 없다)
  └─ apps/rift-grid --auto
  └─ apps/subline-terminal --auto
       ├─ 서명 신원이 없으면 apps/mac-signing-cert 로 만든다 ("<계정> local codesign")
       ├─ ~/git/subline-terminal 이 없으면 클론, 깨끗한 main 이면 pull --ff-only
       ├─ 소스 커밋 = 지난번에 깐 커밋(~/.local/bin/.subline-terminal.commit)이면 여기서 끝
       └─ 그 레포의 tools/install.sh (SUBLINE_TERMINAL_SIGN=그 신원)
            ├─ cargo build --release
            ├─ ~/Applications/subline-terminal.app 을 옆에 짓고 이름을 바꿔 넣는다
            ├─ ~/.local/bin/subline-terminal, subline-terminald → 앱 안을 가리키는 링크
            └─ 기본 소켓에 데몬이 돌고 있으면 세션을 살린 채 새 판으로 갈아태운다
```

### 왜 nix 가 빌드하지 않는가

`apps/mac-signing-cert` 머리말과 같은 이유다. 세션 안의 프로그램이 로컬 네트워크(`ssh`
같은 것)나 문서·데스크탑 폴더에 닿을 때 macOS 가 묻는 허가(TCC)는 **앱의 서명 요구사항**에
묶인다. nix 가 짓는 앱은 임의 서명(ad hoc)이라 요구사항이 바이너리 해시(cdhash)이고,
다시 빌드할 때마다 허가가 조용히 끊긴다. 이 기계의 인증서로 서명하면 요구사항이
인증서에 묶여 몇 번을 다시 지어도 그대로다. 깔린 앱의 요구사항은 이렇게 나온다
(`--status` 가 보여 준다):

```
identifier "io.github.joonhoekim.SublineTerminal" and certificate leaf = H"<이 기계 인증서의 지문>"
```

그리고 앱은 **`~/Applications` 같은 보통 자리**에 있어야 한다. 임시 폴더(`/private/tmp`)에
둔 앱은 알림 서버(usernoted)가 "Failed to find or validate client" 로 받지 않는다 —
서명 종류와는 상관없었다.

### 올리기, 상태, 손으로 다시 깔기

```sh
nix run .#subline-terminal -- --status   # 깔린 커밋, 서명 요구사항, 소스 커밋
nix run .#subline-terminal               # 지금 소스로 빌드해 다시 깐다 (--auto 와 달리 커밋이 같아도)
```

다른 맥에서 올린 커밋은 `build-switch` 때 받아 온다(소스가 깨끗한 `main` 일 때만 —
고치는 중인 트리는 건드리지 않고 그대로 빌드한다). rust 가 아직 없으면(mise 가 깔기 전)
경고만 하고 넘어간다.

### 처음 까는 기계에서

- 서명 신원이 없으면 `apps/mac-signing-cert` 가 만들고, 키체인 인증 창이 한 번 뜬다.
- 첫 알림 때 macOS 가 알림 허가를 묻는다. 거절했거나 한 번 실패한 뒤라면 시스템 설정 →
  알림 → subline-terminal 에서 켠다.
- 세션 안의 프로그램이 처음 로컬 네트워크·폴더에 닿을 때 허가를 묻는다. 한 번 주면
  다시 빌드해도 남는다.
- 셸에서 쓰려면 `~/.local/bin` 이 PATH 에 있어야 한다(이 저장소의 셸 설정이 넣는다).

### 지우기

```sh
subline-terminal ls                      # 남은 세션 확인. kill 로 끝내거나 그대로 둔다
rm -rf ~/Applications/subline-terminal.app
rm -f ~/.local/bin/subline-terminal ~/.local/bin/subline-terminald ~/.local/bin/.subline-terminal.commit
```

`build-switch` 가 다시 깔지 않게 하려면 `apps/build-switch` 에서 그 줄을 뺀다.

## 다른 맥으로 옮기기 (nix 없이)

그 레포의 `tools/package-macos.sh` 가 Apple silicon·Intel 겸용 zip 을 만들고, 받은 맥에서
`bash install-app.sh` 가 격리 표시를 지우고 깐다. 애플의 공증을 받지 않은 앱이라 그
과정이 필요하다. 이 저장소를 쓰는 맥이라면 위의 `build-switch` 가 더 낫다(서명이 그 기계 것).
