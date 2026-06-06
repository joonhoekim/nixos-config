# nixos-config 학습 문서

이 저장소(dustinlyons/nixos-config 기반)를 이해하고 운영하기 위해 정리한 문서 모음입니다.
처음 보는 순서대로 읽으면 좋습니다.

## 목차

- [01. Nix는 어떻게 동작하는가](./01-how-nix-works.md)
  패키지 매니저가 어떻게 시스템 설정까지 관리하는지 — store, derivation, 평가/빌드/활성화 3단계, generation과 롤백.

- [02. 이 저장소의 구조](./02-repo-structure.md)
  진입점(`flake.nix`), import 그래프, macOS/Linux 분기 지점, 꼭 알아야 할 Nix 문법, "무엇을 어디서 고치나" 표.

- [08. Flake 이해하기](./08-understanding-flakes.md)
  (02번과 함께 보기) flake가 푸는 문제, inputs/outputs/`flake.lock`, 순수 평가, `flakeref#attrpath` 문법, 자주 쓰는 명령.

- [03. NixOS vs nix-darwin vs home-manager](./03-nixos-vs-nix-darwin.md)
  파일 형식은 같은데 무엇이 다른가 — 공유되는 언어/모듈 시스템과, 각자 지배하는 영역.

- [04. macOS 설정을 어디까지 관리할 수 있나](./04-macos-settings-scope.md)
  관리 가능한 범위의 진짜 경계 — 타입 옵션 vs 탈출구(CustomUserPreferences, activationScripts), 못 하는 것, key 발굴법.

- [05. macOS defaults의 취약성과 리스크](./05-macos-defaults-fragility.md)
  Apple이 설정 노출부를 바꿔온 역사(Mojave/Ventura/Sequoia), 왜 전면 폐기는 안 일어나는가, 실전 대응.

- [06. 최초 셋업에서 겪는 함정들](./06-first-time-setup-gotchas.md)
  처음 `build-switch` 할 때 막히는 지점들과 해결법 — 실제로 우리가 겪은 순서대로.

- [07. 왜 Nixpkgs는 세계 최대 패키지 저장소인가](./07-why-nixpkgs-is-huge.md)
  점유율은 작은데 패키지 수는 세계 1위인 역설 — 모노레포, 재현성 모델, 자동 생성기, 실제 수치.

- [09. 자주 쓰는 명령어 치트시트](./09-command-cheatsheet.md)
  일상 워크플로, 롤백, flake 갱신, 패키지 탐색, 진단, Homebrew, GC — 실전 명령 모음.

## 한 줄 요약

설정을 "데이터"로 빌드해 `/nix/store`에 박제하고, 라이브 시스템이 그 데이터에 수렴하도록 "활성화"한다.
패키지든 `/etc`든 dock이든 전부 같은 원리. macOS에서는 Apple이 스크립트로 열어둔 표면까지만 닿을 수 있다.
