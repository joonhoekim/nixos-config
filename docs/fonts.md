# 공유 폰트와 한글

`modules/shared/fonts.nix` 는 macOS 와 NixOS 가 같이 쓰는 폰트 목록이고, 두 플랫폼의 `fonts.packages`(hosts/darwin,
hosts/nixos)로 등록된다. 리눅스 쪽에만 있는 폰트는 [korean-input.md](korean-input.md#폰트).

- macOS 에서는 `fonts.packages` 가 앱에 폰트를 노출하는 경로다. environment.systemPackages 에 넣은 폰트는 시스템 폰트
  관리자에 등록되지 않아 터미널이 못 찾고 글리프가 깨진다.
- Nerd Font(아이콘 글리프를 덧붙인 패치판)는 powerline/devicon 글리프로 터미널·p10k·TUI 의 "기호 깨짐"을 막는다.
- `fonts.packages` 는 fontconfig(리눅스의 폰트 검색 라이브러리)으로 노출되므로 그걸 안 읽는 앱(지금은 OnlyOffice)은 혜택을
  못 받는다. 그쪽 목록은 `overlays/onlyoffice-fonts.nix` 에 따로 있고, 합치지 않은 이유(전부 넘기면 1.9GB / 378 패밀리,
  문서 편집기 폰트 드롭다운에 Nerd Font·아이콘 폰트가 쏟아짐)는
  [overlays.md](overlays.md#onlyoffice-fonts--nixos-의-onlyoffice-가-폰트를-못-보는-것).

## 한글 / CJK

noto-fonts 는 CJK 를 덮지 않고(nixpkgs 가 따로 뺀다) Nerd Font 중 한글로 패치된 것도 없다. 이 묶음이 없으면 기계에 한글
얼굴이 하나도 없을 수 있고 OS 가 고른다 — macOS 는 모노 터미널에서 한글을 명조(PCMyungjo)로 그린다. "한글만 폰트가 다르다"
의 모양이 이것이다. 확인: `ghostty +show-face --string=한글`. 두 플랫폼이 같은 얼굴을 갖도록 한 곳에 모아, 터미널 설정이
이름으로 가리킬 수 있게 한다.

- `nerd-fonts.d2coding` — "D2CodingLigature Nerd Font". 한글 셀이 라틴의 정확히 2 배라 열이 안 밀린다. 터미널 기본. 이름의
  Ligature 는 D2Coding 쪽 배포판 구분이고 Nerd 패치본은 그 갈래에만 있다.
- `sarasa-gothic` — "Sarasa Mono K" / "Sarasa Term K", Iosevka + Source Han. .ttc 컬렉션이라 파일 하나에 모든 언어 판이
  든다. 터미널 대안이지만 Nerd 글리프가 없다.
- `noto-fonts-cjk-sans-static` — □ 방지 보험. -static 인 이유: 기본 패키지는 VF(가변 폰트) 전용(wght 기본 100, CFF2)이고
  OnlyOffice 가 그걸 Thin 으로 그린다.
- `pretendard` — UI/문서용 비례 산세리프, 터미널용 아님.

ghostty 는 `font-family` 를 여러 번 적으면 위에서부터 폴백 순서로 읽는다. 앞줄에 있는 글자는 앞줄이 그리므로 라틴은
JetBrainsMono, 한글은 D2Coding 이 된다.

## UI / 라이싱

DankMaterialShell 은 Inter·FiraCode Nerd Font·Material Symbols 를 `share/quickshell/dms/assets/fonts` 에 번들하고 Qt
FontLoader 로 읽어 fontconfig 을 우회한다. 그래서 `fc-match Inter` 실패가 셸이 폴백 중이라는 뜻은 아니다. 그래도 까는 건
GTK 앱·터미널, 그리고 사용자 세션 전에 돌아 번들 대신 fontconfig 을 읽는 DMS greeter 모드가 같은 얼굴을 쓰게 하려는
것이다. caskaydia-cove·geist 는 라이싱 중 프로필 폰트를 리빌드 없이 설정만으로 바꿀 수 있게 둔 대안이다.
