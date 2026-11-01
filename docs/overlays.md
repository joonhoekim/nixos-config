# 오버레이 — 왜 있고 언제 지우나

오버레이는 nixpkgs 의 패키지를 바꿔 끼우는 함수다. `overlays/` 의 `.nix` 파일은 `modules/shared/default.nix` 가 자동으로
읽어 모든 호스트(macOS 포함)에 적용한다 — 등록 규칙은 `overlays/README.md`. 이 문서는 오버레이마다 무엇을 고치는지,
왜 그 방법인지, 언제 지우는지를 적는다. 오버레이는 상류가 고치면 지워야 하는 임시 수선이라 **지우는 조건**이 핵심이다.

## avro-cpp-fmt12 — avro-cpp 헤더를 fmt 12 에 맞춘다

kcat(Kafka CLI) 때문에 둔다. `avro/Exception.hh` 는 `<fmt/core.h>` 만 include 하고 `fmt::format` 을 부른다. fmt 11
까지는 core.h 가 format 을 끌어왔지만 fmt 12 의 core.h 는 base.h 만 싣는다. avro-cpp 자체는 빌드되지만 이 헤더를 쓰는
쪽이 깨진다 — modules/shared/packages.nix 의 kcat → libserdes 가 "no member named 'format' in namespace 'fmt'" 로 멈춘다
(darwin 에서 확인, linux 도 캐시에 libserdes 가 없다).

include 를 `<fmt/format.h>` 로 바꾸면 된다. 이 오버레이로 kcat 을 빌드해 `kcat -V` 가 Avro 지원을 포함해 뜨는 것까지
확인했다.

**지우는 조건:** nixpkgs 의 avro-cpp 가 이 include 를 고치거나 1.12.1 이상으로 올라가 헤더가 바뀌면 `--replace-fail` 이
빌드를 멈춘다. 그때 이 파일을 지우고 kcat 이 빌드되는지 본다.

## onlyoffice-batang-alias — macOS OnlyOffice 의 한글이 한자로 깨지는 것

**증상.** macOS 의 OnlyOffice 에서 한글이 한자로 깨진다 — "테스트" 가 "埕瞻珚" 로. Arial·Calibri 처럼 한글이 없는
폰트(새 문서의 기본값)에서 폴백이 일어날 때만 그렇고, 깨지는 글자는 유니코드 코드포인트가 Big5 코드로도 유효한
음절(둘째 바이트 0x40–0x7E, 0xA1–0xFE)뿐이다. 9.4.0 에서 x2t(OnlyOffice 의 변환 CLI)로 재현된다.

**원인은 둘이 겹친 것이다** (core/DesktopEditor/fontengine):

1. `ApplicationFonts.cpp` 의 `CheckSymbols` 가 폰트의 **모든** cmap 서브테이블(문자 → 글리프 표)을 돌며 코드를 유니코드로
   간주해 커버리지에 기록한다. macOS 시스템 폰트 STHeiti(Heiti SC/TC)는 한글이 전혀 없지만 Mac Big5 cmap(1,2)이 있어,
   Big5 바이트 0xA140–0xF9FE 가 한글 음절 블록(AC00–D7A3)을 덮는 것으로 잘못 잡힌다. `FontFile.cpp` 의
   `SetCMapForCharCode` 도 같은 cmap 에 유니코드 값을 넣어 글리프를 꺼내니 결과가 엉뚱한 한자다.
2. `ApplicationFontsWorker.cpp` 가 폴백 테이블(`__fonts_ranges` / font_selection.bin)을 만들 때 하드코딩된 이름 목록으로
   우선순위를 준다. mac 빌드에선 PingFang·Heiti·Songti 가 그 목록에 있고, 목록에 없는 폰트는 파일 크기 순으로 **전부 그
   뒤**다. 그래서 Nix 로 어떤 한글 폰트를 깔아도 Heiti 를 이기지 못하고, 한글 블록이 Big5 패턴대로 NanumGothic / Heiti
   체스판이 된다(실측 4481 / 3755 / 3022 자).

**지렛대.** 1 은 시스템 폰트라 손댈 수 없고 2 는 바이너리 안이다. 남은 것은 목록의 **순서**다 — Heiti 보다 앞에 있는
이름 가운데 한글 폰트가 하나 있다: "Batang". 그 이름을 가진 진짜 한글 폰트가 있으면 한글 음절 11172 자를 통째로 가져가
Heiti 를 밀어낸다(실측: 전부 Batang 으로 배정, 렌더 정상).

그래서 Noto Serif CJK KR(정적)의 KR face 를 "Batang" 으로 개명해 설치한다. 이름은 정직하게 골랐다 — Batang(바탕)은
명조체이고 한국에서 온 .docx 가 그 이름으로 부르는 폰트라, 이 별칭이 그 문서에도 맞는 얼굴을 준다(Liberation 이 Arial
에 하는 일과 같다). OnlyOffice 는 "바탕" 도 Batang 으로 푼다. 산세리프에 이 이름을 붙이면 폴백 모양은 좋아져도 바탕을
부르는 문서가 틀린다.

개명은 `overlays/onlyoffice-batang-alias.py` 가 한다: name ID 1/2/4/6/16/17 을 바꾸고(FreeType 은 family_name 으로 ID 16
을 우선 보고 없으면 ID 1), WWS(21/22) 는 있으면 지우며, CFF 의 자체 이름도 맞춘다.

**부작용(알고 쓴다).** macOS 전체에 "Batang" 이 생기니 Pages/Word 도 본다. 이 별칭이 한자(4E00–9FFF)도 전부 덮으므로
폴백 한자가 PingFang 대신 한국식 자형의 명조로 나온다 — 한국어 문서엔 맞는 쪽이다.

**NixOS 쪽엔 넣지 않는다.** Heiti 가 없어 1 이 성립하지 않는다. 등록은 hosts/darwin/common.nix 의 `fonts.packages`.

**지우는 조건:** 상류가 CheckSymbols / SetCMapForCharCode 를 유니코드 cmap 으로 제한할 때. 확인은 AllFonts.js 의
`__fonts_ranges` 에서 AC00–D7A3 이 Heiti 없이 한 폰트로 잡히는지 본다.

## onlyoffice-fonts — NixOS 의 OnlyOffice 가 폰트를 못 보는 것

**증상.** OnlyOffice 는 NixOS 가 설치한 폰트를 하나도 못 본다. 증상은 둘(CJK 가 □ 로 깨짐, 폰트 목록에 설치한 폰트가 안
뜸)이지만 원인은 하나다.

**원인.** 편집기 코어는 fontconfig(리눅스의 폰트 검색 라이브러리)을 쓰지 않는다. `/usr/share/fonts`, `~/.fonts`,
`~/.local/share/fonts` 라는 하드코딩된 디렉터리만 훑는데, NixOS 가 그 자리에 놓는 것은 전부 /nix/store 로 가는 심볼릭
링크이고 이 스캐너는 심링크 엔트리를 건너뛴다. 그래서 스캔 결과가 자기가 번들한 폰트뿐이다. 확인:
`~/.local/share/onlyoffice/desktopeditors/data/fonts/fonts.log` — 파일 22 개, 전부 패키지 자신의 share/desktopeditors/fonts
아래 것이고 Noto CJK 는 없다.

nixpkgs 가 FHS 환경의 targetPkgs 에 noto-fonts-cjk-sans 를 넣어둔 것이 소용없는 이유도 같다 — buildEnv 는 그것을 파일
단위 심링크로 건다. `~/.local/share/fonts` 에 실제 .ttf 를 복사해 넣으면 목록에 뜨고, /nix/store 를 가리키는 심링크로
넣으면 안 뜬다(이 머신에서 갈라 본 결과).

**상류 버그.** 의도적인 심링크 배제가 아니다. 원인 코드는 core 의 `DesktopEditor/common/Directory.cpp` 의 `GetFiles2()` —
d_type 을 DT_REG / DT_DIR / DT_UNKNOWN 으로만 분기해서 DT_LNK 가 어디에도 걸리지 않고 조용히 버려진다. 바로 위
DT_UNKNOWN 분기가 XFS 때문에 "모르겠으면 stat() 으로 실체를 보자"는 예외인 걸 보면 방침은 실체를 따라가는 쪽인데 DT_LNK
만 열거에서 빠진 것이다. https://github.com/ONLYOFFICE/DocumentServer/issues/1859 — confirmed-bug(내부 티켓 58490)지만
열려 있다(7.1 기준 보고, 9.1.0 에서도 그대로).

**해법.** **실제 파일**로 된 폰트 디렉터리를 만들어 샌드박스 안의 `/usr/share/fonts` 위에 덮어 씌운다(`--ro-bind`).
링크가 아니라 복사인 것이 이 오버레이의 전부라 `cp -L` 을 링크로 "최적화"하면 원래 버그로 돌아간다. 중복된 용량은
hosts/nixos/common.nix 의 `nix.optimise.automatic` 이 동일 파일을 하드링크로 묶으면서 대부분 회수한다. buildFHSEnv 는
extraBwrapArgs 를 bwrap argv 배열에 따옴표 없이 보간하므로, 공백 있는 문자열 하나가 인자 셋이 된다.

**왜 손으로 고른 허용 목록인가** (시스템 폰트에서 자동으로 가져오는 것은 재어봤고, 답은 아니다):

- config.fonts.packages 전체를 복사하면 1914MB / 378 패밀리가 된다. 용량보다 폰트 드롭다운이 Nerd Font 와 아이콘 폰트로
  덮이는 쪽이 더 불편하다.
- 오버레이는 config.fonts.packages 를 읽을 수 없다. 오버레이가 pkgs 를 만들고 fonts.packages 의 값이 그 pkgs 에서 나오니
  무한 재귀다. 자동화하려면 이 파일을 버리고 모듈에서 사용처 오버라이드로 가야 한다.
- modules/shared/fonts.nix 만 가져오는 절충도 안 된다. 다섯 개가 세 군데서 온다 — cjk-sans/pretendard 는
  shared/fonts.nix, cjk-serif/nanum 은 nixos/korean.nix, liberation 은 NixOS 의 fonts.enableDefaultPackages. 유도하면 5개
  중 2개만 잡히고 한글 문서에 제일 중요한 나눔·명조를 놓친다.
- 방향도 틀렸다. 자동 유도는 거부 목록을 요구하는데 거부 목록은 **열린 채로 실패한다** — 나중에 fonts.packages 에 큰 폰트가
  붙으면 이 클로저에 조용히 수백 MB 가 딸려 들어온다. 허용 목록은 닫힌 채로 실패하고, 목록 자체가 "문서용 얼굴"이라는
  판단이다.

**목록의 각 항목:**

- Noto CJK 는 -static 판이어야 한다. nixpkgs 기본 패키지(2.004)는 가변 폰트(CFF2, wght 축 기본값 100)만 담는데,
  OnlyOffice 는 가변축을 다루지 못해 기본 인스턴스 = Thin 으로 그리고 PDF 에는 외곽선으로 떨어뜨린다(macOS 9.4.0 에서
  x2t 로 확인, 상류 DesktopEditors#3285). 정적 판은 굵기별 OTC 로 온다 — Regular/Bold 는 "Noto Sans CJK KR", 나머지는
  "Noto Sans CJK KR Medium" 처럼 이름이 따로 붙는다.
- pretendard 는 UI/문서용 산세리프.
- liberation_ttf 는 Arial / Times New Roman / Courier New 메트릭 호환이다. OnlyOffice 는 Calibri/Cambria 대응인
  Carlito·Caladea 만 번들하고, 없으면 기본 템플릿과 글머리 기호가 어긋난다(nixpkgs 패키지 주석이 경고하는 그것).

**지우는 조건(둘 중 하나):**

1. 상류가 고친다. 이 오버레이 없이 위 fonts.log 에 /usr/share/fonts 아래 경로가 잡히는지 본다.
2. nixpkgs PR #526315 (https://github.com/NixOS/nixpkgs/pull/526315) 가 머지된다. programs.onlyoffice NixOS 모듈이 같은
   일(폰트 역참조 + bwrap 노출)을 하므로 이 파일을 지우고 그 모듈로 갈아탄다.

## redisinsight-electron — electron 43 · node 26 으로 빌드한다

nixpkgs 의 redisinsight 3.6.0 은 electron_41 을 쓰는데, 41 이 EOL 이 되면서 insecure 표시가 붙었다. 그대로 두면
redisinsight 를 쓰는 NixOS 호스트 전부가 평가 단계에서 멈춘다. permittedInsecurePackages 로 여는 대신 electron 을 바꾼다.

근거:
- nixpkgs PR #555140(redisinsight 메인테이너)이 같은 교체를 한다 — electron_41 → electron_43, 앱 3.6.0 → 3.8.0,
  nodejs-slim_24 → 26. x86_64/aarch64-linux 에서 빌드와 실행을 확인했다고 적혀 있다. 여기서는 앱 버전은 그대로라 그 PR 과
  똑같은 조합은 아니다.
- 상류 RedisInsight 의 main 도 electron ^43 으로 넘어갔다.
- 네이티브 모듈(sqlite3, keytar)은 빌드 중에 electron.headers 로 `npm rebuild` 되므로 electron 을 바꾸면 ABI 도 같이 따라간다.

node 도 24 대신 26 으로 바꾼다. node 24.19 부터 node::ObjectWrap 에 cleanup hook 이 절반만 백포트되어(nodejs/node#65446)
api 의 better-sqlite3 12.x 가 종료 시 `RemoveEnvironmentCleanupHook ... (env) != nullptr` 로 abort 한다. 빌드 중
`yarn generate:api-client` 가 SIGABRT 로 죽는다. 26 은 영향이 없고 #555140 도 26 을 쓴다.

**지우는 조건:** #555140 이 병합되어 nixpkgs 의 redisinsight 가 electron_41 인자를 더 받지 않으면 이 override 가
"unexpected argument" 로 평가 에러를 낸다. 그 에러가 이 파일을 지우라는 신호다.

## vscode-xterm-hangul — 패치가 안전한 이유와 깨질 때

xterm.js 는 VS Code 통합 터미널의 터미널 에뮬레이터 라이브러리다. 원인과 조사 과정은
[postmortem](postmortems/2026-08-05-vscode-terminal-hangul.md) 에 있다.

**버그.** xterm.js 는 끝난 IME 조합을 `setTimeout(…, 0)` 으로 보내고, 대기 중인 모든 전송을 공유 불린 하나
(`_isSendingComposition`)로 지킨다. 빠르게 치면 두 조합이 같은 틱에 끝나 타이머 둘이 동시에 대기하고, 다음 비조합 키(마침표,
공백)가 `_finalizeComposition(false)` 로 그 불린을 지워 대기 전송을 전부 취소한다. 그 음절은 조용히 사라진다.

**패치.** 공유 불린을 FIFO 큐로 바꾼다.
- 동기 finalize 는 큐를 취소하지 않고 순서대로 **비운다**. 전송 워터마크(`_hSentUpTo`)가 어느 경로가 먼저 내보내든 이중
  전송을 막는다.
- 끝 경계는 `_isComposing`(비워지는 콜백이 돌 때 이미 false)이 아니라 "내 시작 오프셋 뒤에서 새 조합이 시작됐나"를 묻는다.
- keydown 의 가드도 큐를 보게 바꾼다. 불린을 그대로 두면 첫 콜백이 플래그를 지우는 순간, 남은 전송이 있어도 다음 비조합
  키가 비우기를 건너뛰어 그 전송들이 키 **뒤에** 도착한다(상류가 보장하는 순서가 깨진다).

상류 보고: https://github.com/xtermjs/xterm.js/issues/6089, PR https://github.com/xtermjs/xterm.js/pull/6090. PR 은 같은
알고리즘을 xterm.js master 에 올린 것으로(항목별 대조 확인), 프로젝트 자체 시험을 통과하고(2409 passing, 전에는 2407)
패치 없이 실패하는 회귀 시험 둘을 더한다. 여기에만 있는 것은 `_hL`/`_hSnap` 추적이다 — 원인을 찾은 수단이라 남겼고
`globalThis.__hangulDebug` 가 없으면 아무 일도 안 한다.

**이 파일을 패치해도 안전한 이유:**
- VS Code 가 실제로 로드하는 파일이다. 워크벤치가 이름으로 요청한다 — `await Qf("@xterm/xterm", "lib/xterm.js")` — 그래서
  옆의 .mjs(package.json "module")는 쓰이지 않는다. 이게 .mjs 로 바뀌면 오버레이가 .js 만 고치므로 다시 확인해야 한다
  (overlays/vscode-xterm-hangul-anchors.py 가 확인한다).
- 체크섬 대상이 아니다. product.json 의 체크섬은 정확히 10 개이고 전부 out/ 아래라 node_modules/** 는 덮이지 않는다 —
  "installation appears corrupt" 경고가 안 뜬다.
- 축소(minification)가 속성 이름(`_compositionPosition`, `_textarea`, `_coreService.triggerDataEvent` …)은 남기고 지역
  변수만 바꾸기 때문에 앵커를 맞출 수 있다.

**깨질 때.** 앵커는 축소된 VS Code 출력을 글자 그대로 잘라 온 것이라 VS Code 업데이트가 언젠가 하나를 바꾼다.
`--replace-fail` 은 일부러다 — 패치 안 된 편집기를 조용히 내놓는 대신 빌드가 크게 실패한다. 그러면 원본 번들에서 앵커를
다시 뽑는다(명령은 postmortem 에, 점검은 overlays/vscode-xterm-hangul-anchors.py).

**Linux 전용.** modules/shared/default.nix 가 이 디렉터리를 macOS 에도 넘기는데(hosts/darwin 이 modules/shared 를
import), 거기서 VS Code 는 .app 번들이라 경로가 없어 substituteInPlace 가 darwin 빌드를 깬다. 버그 자체도
Linux/Wayland/fcitx5 의 것이다.

**지우는 조건:** PR #6090 이 들어가고 그 xterm.js 가 VS Code 에 실리면 유지하지 말고 지운다.
