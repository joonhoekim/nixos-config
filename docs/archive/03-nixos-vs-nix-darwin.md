# 03. NixOS vs nix-darwin vs home-manager

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

파일 형식은 똑같아 보이는데 무엇이 다른가. "NixOS와 같이 쓴다"는 말의 의미.

## 공유되는 것: 언어 + 모듈 시스템

셋 다 같은 Nix 언어와 같은 "모듈 시스템"을 쓴다.
그래서 파일이 똑같아 보인다 — `{ config, pkgs, ... }: { ... }`, `options`, `mkIf`, `mkOption`.

이 저장소의 `modules/darwin/dock/default.nix`가 좋은 예다.
거기서 `mkOption`으로 `local.dock`이라는 옵션을 직접 정의하고,
`config = mkIf cfg.enable (...)`로 구현한다.
이 "옵션 정의 → 값 병합 → 활성화" 패턴은 NixOS, nix-darwin, home-manager 모두 동일하다.

## 다른 것: 누가 무엇을 지배하는가 (영역)

같은 언어를 쓰지만 관할 영역과 활성화 백엔드가 다르다.

### NixOS

- 대상: Linux OS 전체
- 지배 범위: 부트로더, 커널, systemd, 서비스, 유저, `/etc` 전부
- 빌더: `nixpkgs.lib.nixosSystem`
- 활성화: systemd, 부팅 단계부터
- 대표 옵션: `services.nginx.enable`, `boot.loader.*`, `networking.*`, systemd 유닛
- 깊이: 가장 깊다. 그게 곧 OS다. 머신을 부팅 단계부터 완전히 소유한다.

### nix-darwin

- 대상: macOS 위에 얹는 레이어
- 지배 범위: Apple이 설정을 허용한 부분만 (패키지, `/etc`, launchd, `system.defaults`, homebrew)
- 빌더: `darwin.lib.darwinSystem`
- 활성화: launchd. 커널·Finder·시스템은 여전히 Apple 소유
- 대표 옵션: `system.defaults.*`(사실상 `defaults write` 대행), `launchd.*`, `homebrew.*`
- 깊이: 얕을 수밖에 없다. macOS가 닫아둔 만큼이 천장이다.

### home-manager

- 대상: 유저의 홈 (dotfile, 유저 패키지, 프로그램 설정)
- 지배 범위: `~/.zshrc`, `~/.config/*`, 유저 프로그램
- 형태: OS와 무관한 모듈. NixOS 밑에서도 nix-darwin 밑에서도 똑같이 동작
- 그래서 `modules/shared/home-manager.nix`가 양쪽에서 재사용된다.

## "NixOS가 더 깊다"는 게 맞나

맞다. NixOS는 OS 자체라서 노출부에 제한이 없다 — 커널·부팅·init까지 전부 Nix가 만든다.
nix-darwin은 macOS라는 닫힌 OS 위에 얹는 오버레이라, Apple이 스크립트로 열어둔 표면까지만 닿는다.
문법(모듈 시스템)은 같고, 다스리는 땅이 다르다.

비유하자면, 모듈 시스템은 공용 설정 언어이고,
NixOS / nix-darwin / home-manager는 그 언어를 말하는 세 개의 서로 다른 관할 기관이다 —
각각 리눅스 머신 전체 / macOS 오버레이 / 유저 홈을 담당한다.

## 이 저장소에서 "같이 쓴다"의 의미

이 저장소는 한곳에 macOS용(`darwinConfigurations`)과 Linux용(`nixosConfigurations`)을 둘 다 정의하고,
`modules/shared/*`를 공유한다.

```text
공유:  modules/shared/  (zsh, git, vim, 공통 패키지 ...)   ← home-manager 기반이라 OS 무관
         ├── macOS 가지:  hosts/darwin → modules/darwin/*  (casks, dock, system.defaults)
         └── Linux 가지:  hosts/nixos  → modules/nixos/*   (disko, systemd, polybar ...)
```

즉 "내 셸/에디터/패키지 취향은 한 곳(shared)에 적고,
맥북에는 nix-darwin으로, 리눅스 서버/데스크탑에는 NixOS로 같은 설정을 배포한다"는 의미다.
같은 dotfile이 양쪽에서 똑같이 재현된다.
