# 공유 모듈

macOS와 NixOS 양쪽에서 그대로 쓰는 설정. 대부분의 실제 설정이 여기 있고,
`../darwin`과 `../nixos`는 플랫폼 고유의 차이만 얹는다.

## 구성

```
.
├── config/            # Nix로 쓰지 않은 정적 설정 파일 (p10k.zsh)
├── default.nix        # nixpkgs 옵션(allowUnfree 등) + ../../overlays 자동 임포트
├── files.nix          # home.file로 심링크할 정적 파일 (현재 비어 있음)
├── fonts.nix          # 양 플랫폼 공용 폰트 목록
├── home-manager.nix   # ./programs 조각들을 하나의 programs 어트리뷰트셋으로 합침
├── packages.nix       # 양 플랫폼 공용 패키지 (CLI / TUI 위주)
├── programs/          # 프로그램별 home-manager 조각
└── scripts/           # zsh에서 소싱하는 셸 스크립트
```

## programs/

`home-manager.nix`가 `programs/` 안의 조각들을 왼쪽 폴드(`//`)로 합친다. 각 조각은
프로그램 이름을 키로 갖는 **평범한 어트리뷰트셋**을 반환해야 한다 — `lib.mkMerge` 썽크를
반환하면 안 된다(darwin/nixos 쪽에서 `programs = shared // {...}`로 소비하기 때문).

현재 조각: `zsh`, `git`, `cli`, `vim`, `ssh`, `tmux`.

새 프로그램을 추가하려면 `programs/`에 파일을 만들고 `home-manager.nix`의 `fragments`
목록에 넣는다. 키가 겹치지 않으므로 순서는 상관없다.

## GUI 앱은 어디에?

크로스 플랫폼 CLI/TUI는 `packages.nix`, Linux 전용·GUI는 `../nixos/packages.nix`,
macOS GUI는 Homebrew cask(`../darwin/casks.nix`)로 간다.
