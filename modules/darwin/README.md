# Darwin 모듈

macOS(nix-darwin) 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── config/            # Nix로 쓰지 않은 정적 설정 파일 (aerospace.toml, karabiner/)
├── dock/              # macOS Dock 항목을 선언적으로 관리하는 모듈
├── casks.nix          # Homebrew cask 목록 (macOS GUI 앱)
├── eul.nix            # eul(메뉴바 시스템 모니터) UserDefaults 설정
├── files.nix          # home.file로 심링크할 정적 파일 (karabiner, aerospace)
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + macOS 고유분)
├── ios.nix            # iOS / Apple 플랫폼 개발 툴체인
└── packages.nix       # macOS 전용 패키지
```

시스템 레벨 설정(nix-darwin 옵션, macOS defaults, homebrew 블록)은 이 디렉토리가 아니라
[`../../hosts/darwin/default.nix`](../../hosts/darwin/default.nix)에 있다.

darwin 설정은 hostname이 아니라 **아키텍처**로 키잉된다 — 현재는 `.#aarch64-darwin`
하나뿐이다(인텔 Mac은 nixpkgs 26.11에서 지원 중단으로 제외). 자세한 건 저장소 루트
[README](../../README.md) 참고.
