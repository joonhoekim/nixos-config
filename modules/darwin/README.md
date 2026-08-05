# Darwin 모듈

macOS(nix-darwin) 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── config/            # set-default-handlers.py (default-apps.nix가 쓴다)
├── rice/              # 시드하는 설정 — 심은 뒤엔 ~/.config 쪽이 원본이다.
│                      #   karabiner/, rift/, aerospace/, wezterm/, borders/,
│                      #   bin/, workspacepeek/
│                      #   왕복은 apps/rice-save ↔ apps/rice-restore
├── dock/              # macOS Dock 항목을 선언적으로 관리하는 모듈
├── casks.nix          # Homebrew cask 목록 (macOS GUI 앱)
├── default-apps.nix   # 파일 종류별 기본 앱 (터미널 → Ghostty, 코드 → VS Code)
├── eul.nix            # (미사용) eul UserDefaults 설정 — stats로 대체되어 import 제외
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + macOS 고유분)
├── ios.nix            # iOS / Apple 플랫폼 개발 툴체인
└── packages.nix       # macOS 전용 패키지
```

시스템 레벨 설정(nix-darwin 옵션, macOS defaults, homebrew 블록)은 이 디렉토리가 아니라
[`../../hosts/darwin/default.nix`](../../hosts/darwin/default.nix)에 있다.

darwin 설정은 hostname이 아니라 **아키텍처**로 키잉된다 — 현재는 `.#aarch64-darwin`
하나뿐이다(인텔 Mac은 nixpkgs 26.11에서 지원 중단으로 제외). 자세한 건 저장소 루트
[README](../../README.md) 참고.
