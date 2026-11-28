# Darwin 모듈

macOS(nix-darwin) 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── rice/              # 시드하는 설정 — 심은 뒤엔 ~/.config 쪽이 원본이다.
│                      #   왕복은 apps/rice/save ↔ apps/rice/restore
├── dock/              # macOS Dock 항목을 선언적으로 관리하는 모듈
├── scripts/           # 셸이 소싱하는 macOS 전용 헬퍼
├── casks.nix          # Homebrew cask (macOS GUI 앱) — core + 호스트가 고르는 local.casks
├── default-apps.nix   # 파일 종류별 기본 앱. plist 쓰기는 set-default-handlers.py
├── home-manager.nix   # 계정·homebrew·home-manager 배선 (shared/home-manager.nix + macOS 고유분)
├── ios.nix            # Xcode (App Store, masApps)
├── kanata.nix         # Caps Lock 레이어·한/영 (kanata + 드라이버, 설정은 ../shared/kanata)
├── launchd-names.nix  # launchd 서비스가 Background App Activity 에 제 이름으로 보이게 하는 래퍼
└── packages.nix       # macOS 전용 패키지 (shared/packages.nix + macOS 전용 도구)
```

시스템 레벨 설정(nix-darwin 옵션, macOS defaults, 로그인 항목)은 이 디렉토리가 아니라
[`../../hosts/darwin/common.nix`](../../hosts/darwin/common.nix)에 있다.

## 호스트

`hosts/darwin/` 아래 디렉토리 하나가 Mac 한 대이고, 디렉토리 이름이 flake 타겟이자
`LocalHostName` 이다. 전용 디렉토리가 없는 Mac 은 아키텍처로 키잉한 공용 설정
(`hosts/darwin/default.nix`)을 쓴다. 두 층의 관계와 새 Mac 을 붙이는 법은
[docs/02-this-repo.md](../../docs/02-this-repo.md)의 "macOS 호스트의 두 층".

기계마다 갈리는 값(stateVersion, 고른 묶음과 cask)은 호스트 파일이 정한다. 공용 쪽의
stateVersion 은 `mkDefault` 이고 공용 `.#<arch>` 에만 쓰인다.
