# macOS 배선 — 기본 앱, 로그인 항목, kanata, launchd

nix-darwin 은 macOS 를 Nix 로 선언하는 모듈 시스템이다. 이 문서는 macOS 쪽 모듈 가운데 "이 줄이 왜 이렇게 생겼나"가
macOS 내부 동작에 달린 것들을 모은다. 설정을 어디까지 관리할 수 있는지의 큰 그림은
[03-operating-on-macos.md](03-operating-on-macos.md), 라이싱(rift-grid·벽지·터미널)은 [macos-rice.md](macos-rice.md).

## 기본 앱 핸들러 (modules/darwin/default-apps.nix)

두 묶음, 한 메커니즘이다.

- 셸 스크립트 → subline-terminal (`.sh` 를 더블클릭하면 *실행*돼야 한다)
- 코드·설정 파일 → VS Code (rift-grid 의 "settings" 항목, `.toml`, `.json`, …)

### macOS 에는 "기본 터미널/편집기" 설정이 없다

LaunchServices(파일·URL 을 어느 앱이 여는지 정하는 macOS 서비스)가 아는 것은 의사 UTI
`com.apple.default-app.{web-browser,mail-client,…}` 뿐이고 `...default-app.{terminal,editor}` 는 없다. 파일이 어디서
열리는지를 실제로 정하는 것은 UTI(파일 형식 식별자)별 role handler 다. 사용자 지정이 없으면 LaunchServices 가 등록된
후보 가운데 스스로 고른다. 그래서 `.toml` 은 Zed 로 가고(Zed 의 Info.plist 가 `public.text` 전체를 주장해서, 아무도
주장하지 않은 텍스트류 타입을 전부 물려받는다), Xcode 가 가진 소스 타입은 Xcode 로 간다.

### 왜 `duti` 가 아니라 plist 를 직접 쓰나

핸들러는 `~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist` 에 있다. 흔한 조언은
duti 다 — 그냥 `defaults write` 하면 무시된다는 이유인데, 그건 반만 맞는다.

- macOS 26 에서 duti 는 믿을 수 없다. duti 가 부르는 `LSSetDefaultRoleHandlerForContentType` 은 기존 항목이 없는 타입에
  대해 noErr 를 돌려주고 아무것도 안 한다. `duti -s com.microsoft.VSCode public.toml all` 이 plist 를 조용히 그대로 둔다.
  이미 배열에 있는 타입에만 먹는다.
- 현대식 대안 `NSWorkspace.setDefaultApplication(at:toOpen:)` 은 GUI 가 아닌 프로세스에서는 완료 핸들러를 아예 부르지 않는다.
- plist 직접 쓰기는 된다. 단, 항목에 `LSHandlerPreferredVersions = { LSHandlerRoleAll = "-" }` 가 있어야 한다. 이 키가
  없으면 LaunchServices 가 항목을 통째로 무시한다 — 시스템이 쓰는 모든 항목에 있는 키이고, "defaults write 는 무시된다"
  는 설의 실제 원인이다. 키가 있으면 손으로 쓴 항목도 따른다. 끝까지 확인: public.toml 을 쓴 뒤 `open x.toml` 이 VS Code
  를 띄운다.

### 다른 앱이 이미 가진 타입은 로그아웃이 필요하다

LaunchServices 는 콘텐츠 타입별로 해석 결과를 캐시한다. 아무도 주장하지 않던 타입(public.toml)은 바로 바뀌지만, Xcode
나 TextEdit 이 이미 가진 타입은 LS 데이터베이스가 다시 지어질 때까지 옛 앱으로 해석된다 — 실제로는 로그아웃 후 다시
로그인. `lsregister` 로는 강제할 수 없다: `lsregister -domain user` 는 유효한 문법조차 아니고(플래그는 `-apps`/`-all`),
`-kill` 은 macOS 26 에서 빠졌다. 핸들러를 바꾼 리빌드 뒤에는 실패라고 결론 내기 전에 로그아웃부터 한다.

### 일부러 VS Code 로 가져오지 않는 타입

- `public.html` → 브라우저(Chrome). 웹 페이지는 *보려고* 연다.
- `public.log` → Console.app
- `public.perl-script` → 셸 스크립트 트리에서 상속되어 subline-terminal. 셸 스크립트 자체는 더블클릭으로 실행되도록
  편집기 밖에 둔다.
- `public.comma-separated-values-text` → OnlyOffice. `.csv` 는 스프레드시트다.

셸 스크립트 쪽 목록은 subline-terminal 이 Info.plist 에 선언한 타입과 정확히 같다(그 레포의 tools/macos-bundle.sh).
bash/ksh/tcsh 줄이 빠지면 그 타입은 VS Code 나 TextEdit 으로 간다. 지정하지 않은 Language 타입들(python, ruby, c, swift,
make, markdown…)의 macOS 기본값은 Xcode 이고, .js 는 Chrome, .css 는 Firefox 로 가 있는 경우가 흔하다.

## 로그인 항목 — Stats·LinearMouse 를 launchd 로 띄우는 이유

launchd 는 macOS 의 서비스 관리자이고, 사용자별 LaunchAgent 는 로그인 때 도는 job 이다. 최근 macOS 에서는 앱 자체의
"로그인 시 시작" 토글이 유지되지 않아서, GUI 앱의 로그인 항목은 `launchd.user.agents`(hosts/darwin/common.nix)로
선언한다. 앱이 그 호스트에 cask 로 선언되어 있을 때만 둔다(`hasCask`) — 앱 없이 `open -a` 를 남기면 로그인마다
실패하고 apps/check/mac 이 그 job 의 last exit code 를 ✗ 로 보인다.

- **Stats**(메뉴바 시스템 모니터): 로그인에 띄우되 손으로 끈 것은 존중한다(RunAtLoad 만, KeepAlive 없음). Stats 에도
  "Start at login" 토글이 있지만 앱이 자기 설정에서 다시 쓰는 SMAppService 로그인 항목을 등록한다 — 이 레포가 선언적으로
  들고 있으려는 바로 그런 상태다. launchd 로 띄우면 다른 GUI 앱과 모양이 같고 재설치에도 살아남는다.
- **LinearMouse**: 트랙패드는 자연스러운 스크롤 그대로 두고 외장 마우스 휠만 뒤집는다. 읽는 설정은
  `~/.config/linearmouse/linearmouse.json`(시드는 modules/darwin/rice/default.nix, 근거는
  modules/darwin/rice/linearmouse/README.md). 첫 실행에서 입력 모니터링 권한을 한 번 묻는다. 거부하면 앱은 떠 있는 채로
  아무 일도 안 하고, 휠 방향이 안 바뀌는 것 말고는 증상이 없다.

### 왜 `open -a` 인가 (실측)

번들 안의 Mach-O 를 직접 exec 하지 않고 `open -a` 를 거치는 것이 요점이다. LinearMouse(그리고 Stats)는 자기 "Start at
login" 을 SMAppService 로그인 항목으로도 등록하고, 그게 켜져 있으면 부팅 때 두 군데서 발화한다.

| 띄우는 방법 | 이미 떠 있을 때 |
|---|---|
| `open -a` | 아무 일도 안 한다 (LaunchServices 가 막는다) |
| `.../MacOS/Linear…` 직접 exec | 막지 않는다 — 두 번째 프로세스가 생긴다 |

LinearMouse 두 인스턴스가 같은 스크롤 이벤트를 각각 뒤집으면 서로 상쇄되므로, 증상은 "상단바 아이콘이 둘"과 "휠 방향이
안 바뀐다"로 같이 온다. 하나를 끄면 낫는다는 게 이 조합의 표식이다. Stats 는 메뉴바에 둘이 뜬다. 앱 안에서 막아 주는
것은 없고, 하나로 유지되는 것은 앱 자체 항목이 꺼져 있기 때문일 뿐이다 — `sudo sfltool dumpbtm` 이 두 항목의
disposition 을 보여 준다.

launchd 는 이 job 을 곧 끝난 것으로 본다. RunAtLoad 뿐이고 KeepAlive 가 없으니 그게 맞는 모양이다 — 로그인에 한 번
띄우는 것이 하는 일의 전부다.

## rift-grid 로그인 에이전트와 "Displays have separate Spaces"

타일링 WM 은 rift-grid 다 — rift 를 포크해 가상 워크스페이스를 3x3 격자로 배치한 것(https://github.com/joonhoekim/rift-grid).
nix 나 brew 가 아니라 apps/rift-grid 가 기계마다 빌드·서명해 `~/.local/bin` 에 둔다. TCC(macOS 의 개인정보 허가 DB)가
손쉬운 사용·화면 기록 허가를 서명에 묶고, apps/mac-signing-cert 의 로컬 신원만 리빌드를 넘어 허가를 유지하기 때문이다
([03-operating-on-macos 의 rift-grid 항목](03-operating-on-macos.md#3-최초-셋업에서-겪는-함정들)).

hosts/darwin/common.nix 의 에이전트:

- `path`: rift-grid 의 키바인딩은 `rift-grid-cli`(같은 `~/.local/bin`)와 systemPath 의 도구를 부르는데, LaunchAgent 는
  로그인 셸의 PATH 를 하나도 물려받지 않는다.
- `KeepAlive.PathState`: apps/rift-grid 를 아직 안 돌린 기계에는 띄울 것이 없고, 그냥 KeepAlive 면 재시작 루프가 된다.
  PathState 면 launchd 가 기다렸다가 바이너리가 생기면 띄운다.
- `StandardOutPath`/`StandardErrorPath`(`/tmp/rift-grid.log`): 사실상 필수다. 없으면 rift-grid 가 시작을 거부한 이유가
  아무도 안 읽는 stdout 으로 가고, 눈에 보이는 증상은 조용히 안 도는 WM 뿐이다. run_on_start 실패도 같은 모양이다 — 안
  걸린 훅은 흔적을 남기지 않는다.

### "Displays have separate Spaces" (`system.defaults.spaces.spans-displays`)

- `false` = 디스플레이마다 따로인 Spaces (macOS 기본값)
- `true` = 한 Space 가 모든 디스플레이에 걸친다

rift-grid 의 필수 조건이다. `false` 가 아니면 저하 모드가 아니라 즉시 종료한다:

```
Rift detected that the macOS setting "Displays have separate Spaces"
is disabled. Rift currently requires this setting to be enabled.
```

LaunchAgent 가 KeepAlive 라 그 종료가 크래시 루프가 되어 "rift-grid 가 그냥 안 돈다"로 보인다 —
`launchctl print gui/$UID/org.nixos.rift-grid` 의 `last exit code = 1` 이 표식이다. 터미널에서 `~/.local/bin/rift-grid`
를 돌리면 이유가 찍힌다.

값을 바꾸면 어느 쪽이든 로그아웃이 필요하다 — com.apple.spaces 에는 바로 써지지만 WindowServer 는 로그인 때만 읽는다.
rift-grid 자체 검사는 설정값을 읽으므로 로그아웃 전에도 뜨지만 창은 옛 방식으로 움직인다. 짝인 "Spaces 자동 재정렬"
토글은 `dock.mru-spaces = false` 가 맡는다.

## kanata 배선 (modules/darwin/kanata.nix)

kanata 는 키보드 입력을 가로채 레이어·리맵을 거는 크로스플랫폼 프로그램이다. Caps Lock 레이어 자체는
`modules/shared/kanata/kanata.kbd`(Windows 와 같은 파일, [kanata.md](kanata.md))이고, macOS 쪽 모듈은 그걸 돌리는 배선만 있다.

kanata 는 키보드를 Karabiner-DriverKit-VirtualHIDDevice(가상 키보드를 만드는 드라이버 확장)로 내보내고, 그 드라이버의
유저 공간 데몬과 소켓으로 말한다. 그래서 세 조각이 필요하다.

1. **확장(dext)을 품은 Manager 앱** — `/Applications` 안에 실제 파일로 있어야 한다. 시스템 확장은 심링크나 /nix/store
   에서 활성화되지 않는다. 판이 바뀔 때만 갈아 넣는다 — 활성화된 확장의 주인 앱을 매번 지웠다 다시 두면 그 사이에
   macOS 가 확장을 주인 없는 것으로 보고 비활성화를 거는 일이 있다(같은 판을 다시 activate 하는 것 자체는 아무 일도
   안 한다). preActivation 인 것은 데몬이 올라오기 전에 앱이 제자리에 있어야 해서다.
2. **VirtualHIDDevice-Daemon** — root 로 돈다. 소켓이 `/Library/Application Support/org.pqrs/tmp/rootonly/` 에 생기고,
   그래서 kanata 도 root 여야 한다. `activate` 는 확장이 이미 같은 판으로 켜져 있으면 바로 끝나고 처음이면 시스템 설정의
   승인을 기다리므로, build-switch 가 아니라 데몬 스크립트에서 부른다(활성화가 승인 창 앞에서 멈춰 서지 않게). 이 데몬이
   없으면 kanata 는 떠 있는 채로 `connect_failed asio.system:2` 를 로그에 반복하고 키는 kanata 를 거치지 않은 그대로 나간다.
3. **kanata** — root 데몬. 바이너리와 설정은 스토어가 아니라 `/usr/local/libexec/kanata/` 에 있다(아래).

### 드라이버 판

`pkgs.kanata.passthru.darwinDriver` 를 그대로 쓴다. kanata 의 karabiner-driverkit 크레이트가 그 릴리스의 IPC 에 맞춰
빌드되고, pqrs 는 마이너 버전 사이에도 프로토콜을 바꾼다(kanata docs/setup-macos.md). Karabiner-Elements 를 같이 깔면
안 되는 이유가 이것이다 — KE 16.3 이 까는 데몬은 8.5.0 이고 kanata 1.12 가 아는 것은 6.2.0 이다. 둘 다 키보드를
독점으로 잡으려 하는 것도 있다.

### 바이너리가 스토어 경로가 아닌 이유

입력 모니터링·손쉬운 사용 허가는 TCC 가 바이너리의 서명 요구사항에 묶는다. nix 가 빌드한 바이너리는 임의 서명이라
요구사항이 cdhash 이고, kanata 판이 바뀔 때마다 허가가 **조용히** 끊긴다 — 설정 화면의 체크박스는 켜진 채로 레이어만
안 먹는다(apps/mac-signing-cert 머리말). 그래서 apps/kanata 가 스토어의 바이너리(`/etc/kanata/kanata-unsigned`)를 이 기계
신원으로 다시 서명해서 그 자리에 둔다. 설정도 같이 복사해서, 부팅 때 /nix 가 붙기 전에 떠도 /nix 를 건드릴 일이 없다
(apps/kanata 머리말). build-switch 가 매번 부른다.

kanata 데몬은 ProgramArguments 로 바이너리를 직접 띄운다. 셸을 거치면 TCC 가 허가를 찾는 대상이 그 셸이 될 수 있다. 같은
이유로 launchd-names.nix 의 wait4path 래퍼도 안 거치므로, 바이너리와 설정이 /nix 를 가리키면 안 된다. 설정은 고정
경로라 kanata.kbd 가 바뀌어도 plist 는 그대로이고, 복사본을 갈아 넣고 데몬을 다시 띄우는 것은 `apps/kanata --auto` 가
한다. KeepAlive 는 PathState 로 바이너리가 있는 동안만 — apps/kanata 를 아직 안 돌린 기계에서 그냥 KeepAlive 면 재시작
루프가 된다.

승인 절차와 화면 이름은 [clean-install-macos.md 의 7](clean-install-macos.md#7-사람이-해야-하는-단계-tcc--드라이버).

## launchd 서비스 이름 (modules/darwin/launchd-names.nix)

목적: launchd 서비스가 System Settings > General > Login Items & Extensions 의 Background App Activity 에 "sh" 가 아니라
제 이름으로 보이게 한다.

macOS 의 백그라운드 항목 목록(BTM)은 legacy daemon/agent 의 이름을 plist 의 Label 이 아니라 첫 ProgramArguments 의
basename 으로 정한다(`sudo sfltool dumpbtm` 의 Name 과 Executable Path). nix-darwin 은 `command`/`script` 가 있는 서비스를
전부 `[ "/bin/sh" "-c" "/bin/wait4path /nix/store && exec <command>" ]` 로 감싸므로(nix-darwin modules/launchd/default.nix),
그런 서비스는 모두 "sh" 로 보이고 목록에서 가를 수 없다.

그래서 같은 한 줄을 서비스 이름의 래퍼 스크립트로 `/usr/local/libexec/nix-darwin/{daemons,agents,user-agents}/` 에 두고
ProgramArguments 를 그 하나로 바꾼다. 스크립트여도 BTM 은 해석기가 아니라 스크립트 경로를 기록한다(macOS 27.0.1 에서
시험 에이전트로 확인: `Name: name-probe`).

래퍼가 /nix/store 밖에 있는 이유:

- 부팅 때 launchd 가 이 경로를 실행하는 시점에는 Nix 볼륨이 아직 안 붙었을 수 있다 — wait4path 가 바로 그걸 기다리는 줄이다.
- 경로가 세대마다 바뀌지 않아야 한다. 바뀌면 BTM 이 새 항목으로 보고 "백그라운드 항목 추가됨" 알림을 다시 띄운다.

- submodule 타입을 확장하는 방식이라 `command` 를 가진 서비스는 앞으로 더해지는 것까지 자동으로 따라온다. ProgramArguments
  를 직접 쓰는 서비스(org.nixos.kanata)는 이미 제 바이너리로 시작하므로 건드리지 않는다.
- 래퍼 디렉터리는 preActivation(nix-darwin 이 plist 를 다시 올리기 전)에 새 디렉터리를 다 채운 뒤 통째로 바꿔 끼운다 —
  도는 중인 서비스가 반쯤 쓰인 래퍼를 실행하지 않게.
- 파일은 root 소유 755 다. root daemon 이 실행하는 파일을 사용자가 고칠 수 있으면 그게 곧 root 권한이다.
