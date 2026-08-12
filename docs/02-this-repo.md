# 02. 이 저장소의 구조

진입점이 어디고, 파일들이 어떻게 연결되며, macOS/Linux 분기가 어디서 일어나는지.
`apps/`(`nix run` 래퍼)의 구조와 머신 고유 부분. 그리고 이 저장소를 읽는 데 필요한 Nix 문법.

---

## 진입점: `flake.nix`

모든 것의 시작점. `inputs`(외부 의존성)와 `outputs`(그걸로 무엇을 만들지)로 나뉜다.
`outputs`가 만드는 네 가지:

- `darwinConfigurations.<arch>` → `hosts/darwin/` (macOS) — 이 Mac에서 쓰는 것
- `nixosConfigurations.<hostname>` → `hosts/nixos/<host>/` (Linux, 예: `mn56`)
- `apps.<system>.<name>` → `apps/<name>` (`nix run`의 실체) — 빌드 4종(build-switch,
  build, rollback, clean)과 라이싱 도구들(rice-*), demo, mac-signing-cert.
  전체 목록은 `flake.nix`의 `mkApps` 한 곳이다
- `devShells`

흐름: `nix run .#build-switch` → `apps.<현재system>.build-switch` → 공유 스크립트 `apps/build-switch`
실행 → `uname`으로 OS를 감지해 macOS면 `darwinConfigurations.<arch>`, NixOS면
`nixosConfigurations.<hostname>`을 빌드·활성화. (`apps/`의 자세한 구조는 아래 "apps/" 절.)

---

## macOS / Linux 분기는 두 군데서 일어난다

### (A) 최상위 분기 — `flake.nix`

```nix
linuxSystems  = [ "x86_64-linux" "aarch64-linux" ];
darwinSystems = [ "aarch64-darwin" ];  # 인텔 Mac은 nixpkgs 26.11에서 지원 중단
# macOS: darwin.lib.darwinSystem + ./hosts/darwin
# Linux: nixpkgs.lib.nixosSystem  + ./hosts/nixos
```

플랫폼별로 완전히 다른 빌더와 다른 진입 디렉토리를 쓴다. 이것이 큰 갈래다.

### (B) 파일 안에서의 세밀한 분기 — `isDarwin` / `isLinux`

공유 파일은 한 파일에서 두 OS를 다루므로 줄 단위로 갈라낸다. 실제 예는
`modules/shared/programs/zsh.nix` — macOS 전용 헬퍼(colima-up)를 darwin일 때만
소싱한다:

```nix
lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
  ("\n" + builtins.readFile ../../darwin/scripts/colima-up.zsh)
```

같은 감각의 도구가 둘 더 있다: `lib.mkIf <조건> <값>`(조건이 거짓이면 그 줄은
없는 셈), `lib.mkMerge [ a b ]`(여러 정의 병합). 경로 상수는 분기하지 않는다 —
`/home` vs `/Users` 는 `config.home.homeDirectory` 가 이미 알고 있다
(`modules/shared/programs/ssh.nix`).

---

## 전체 import 그래프

```text
hosts/darwin/default.nix          ← macOS 진입점 (시스템 레벨 설정)
│   imports = [
├──→ modules/darwin/home-manager.nix   ← macOS 유저/홈 레벨
│    │   imports ./dock              (Dock 관리 모듈)
│    │   casks   = ./casks.nix       (GUI 앱)
│    │   brews   = ./brews.nix       (formula — rift 등)
│    │   home-manager.users.<user>:
│    │     packages = ./packages.nix             (shared + macOS 전용 패키지)
│    │     programs = ../shared/home-manager.nix          ← 공유
│    └
└──→ modules/shared (= modules/shared/default.nix)   ← nixpkgs 설정 + overlays

modules/shared/   ← darwin과 nixos가 둘 다 쓰는 공통부
├─ home-manager.nix       ./programs 조각(zsh, git, vim, ssh, ...)을 하나로 폴드
├─ programs/              프로그램별 home-manager 조각
├─ packages.nix           공통 CLI 패키지
├─ fonts.nix              공통 폰트 (fonts.packages로 등록)
├─ ghostty/               터미널 라이싱 시드 + 심는 모듈 (양 플랫폼)
├─ mise-install.nix       mise 도구를 switch 때 까는 활성화 조각 (양 플랫폼)
├─ rice-seed-helpers.nix  라이싱 시드용 seed/ensure 셸 함수
└─ default.nix            nixpkgs.config + overlays
```

리눅스도 대칭이다. `hosts/nixos/<host>/default.nix` → `hosts/nixos/common.nix` → `modules/nixos/*`
→ 같은 `modules/shared/*` 재사용.

핵심 원칙:

- `modules/shared/`를 고치면 두 OS 모두 영향. `modules/darwin/`은 macOS만.
- 헷갈리면 "이게 리눅스에도 해당되나?"를 물어보면 된다.

---

## `apps/`

### 정체: "내용은 sh, 진입은 Nix"

`apps/`의 파일은 평범한 **POSIX sh 스크립트**(Nix 언어 아님)지만, flake의 **`apps` 출력**으로
노출되어 `nix run .#<name>`으로 실행된다. Nix가 진입점을 주고 실제 일은 셸이 한다.

예전 dustinlyons 템플릿은 system마다 디렉터리를 두고 스크립트를 중복시켰지만, 지금은
**스크립트 한 벌을 `apps/`에 평평하게 두고 런타임에 macOS/NixOS를 자동 감지**한다.

연결 고리(`flake.nix`):

```nix
mkApp = scriptName: system: {
  type = "app";
  program = "${(writeScriptBin scriptName ''
    #!/usr/bin/env bash
    PATH=${git}/bin:$PATH                  # git을 PATH에 보장
    exec ${self}/apps/${scriptName} "$@"   # 공유 스크립트 실행, 인자 전달
  '')}/bin/${scriptName}";
};
# 스크립트가 플랫폼을 자체 감지하므로 모든 system이 같은 앱을 노출.
# 이름 목록 하나가 전부다 — 스크립트를 추가하면 여기 이름만 넣는다.
mkApps = system: nixpkgs.lib.genAttrs [
  "build" "build-switch" "rollback" "clean"
  "rice-save" "rice-restore" ...  # 전체는 flake.nix
] (name: mkApp name system);
```

`${self}`는 flake 소스 루트. 흐름: `nix run .#build-switch` → writeScriptBin 래퍼 →
`apps/build-switch` → `uname`으로 OS 판별 → macOS면 `darwinConfigurations.<arch>`,
NixOS면 `nixosConfigurations.<hostname>`을 빌드·활성화. 새 app은 `apps/`에 스크립트를 두고
`mkApps`의 이름 목록에 넣으면 모든 플랫폼에 노출된다. `rice-lib.sh`·`build-lib.sh`처럼
sourced 되는 조각은 목록에 넣지 않는다.

### 각 app이 하는 일

| app | 용도 | 비고 |
|-----|------|------|
| `build-switch` | 빌드 + 활성화 | **일상 명령.** macOS=`darwin-rebuild switch`, NixOS=`nixos-rebuild switch` |
| `build` | 빌드만 (활성화 X) | 평가·빌드 검증용 |
| `rollback` | 이전 세대로 복구 | 세대 번호 입력(공백=직전). 양 OS |
| `clean` | 구 세대 GC | `nix-collect-garbage --delete-older-than 7d` (인자로 기간 변경) |
| `rice-*` | 라이싱 도구 일습 | 프로필·터미널·월페이퍼·화면 셰이더 전환과 저장/복원. 각 스크립트 머리말과 [README](../README.md)의 라이싱 절 참고 |
| `demo` | 창 관리자 실사용 재연 | 빈 워크스페이스에서 키맵대로 창을 움직여 보여준다. 시나리오 목록은 `apps/demo` |
| `mac-signing-cert` | 코드 서명 신원 고정 | macOS 전용 (docs/03 참고) |

인자 규칙 세 가지:

- 추가 플래그는 그대로 전달된다: `nix run .#build-switch -- --show-trace`.
- NixOS 호스트는 `hostname`에서 자동으로 잡고, `--host`로 덮어쓴다(첫 switch 전 유용):
  `nix run .#build-switch -- --host mn56`.
- `build-switch`를 통째로 `sudo`로 돌리지 말 것 — 빌드는 유저로, 활성화 단계만 `sudo`.

### 머신 고유 부분: `hardware-configuration.nix`

이 fork는 재배포용 템플릿이 아니라 개인 설정이라, 예전의 `%HOST%`/`%DISK%` 플레이스홀더
치환(`apply`)·비밀키 부트스트랩(`*-keys`)·disko 포맷·`install` 앱은 **전부 제거**했다.
머신마다 다른 값은 한 곳, 각 호스트의 `hardware-configuration.nix`에만 모인다.

- NixOS 호스트는 hostname으로 키잉된다(`nixosConfigurations.mn56`,
  `.galaxy-chromebook-1`). 각 `hosts/nixos/<host>/`는 공용 `common.nix`(하드웨어 무관
  설정) + 자기 `hardware-configuration.nix`를 import한다.
- `hardware-configuration.nix`는 **그 머신에서 생성한 진짜 파일**이어야 한다. 해당
  머신에서 `nixos-generate-config --show-hardware-config`로 뽑아 커밋한다. 그래서 호스트
  디렉토리는 실제로 존재하는 머신만 만든다 — 빈 placeholder를 커밋해두면 `fileSystems`
  미정의로 평가가 깨질 뿐 얻는 게 없다.
- CPU 마이크로코드·initrd 모듈·디스크 UUID는 이 파일이 자동으로 담으므로, AMD/Intel 머신
  차이는 여기서 흡수된다. GPU(amdgpu / i915·xe)는 mesa로 공통 처리.

---

## 무엇을 어디서 고치나

- CLI 패키지(양쪽 OS): `modules/shared/packages.nix`
- 셸/git/vim 설정: `modules/shared/home-manager.nix`
- 폰트: `modules/shared/fonts.nix` (각 호스트의 `fonts.packages`로 등록)
- GUI 앱(cask): `modules/darwin/casks.nix`
- macOS 시스템 설정: `hosts/darwin/default.nix`의 `system.defaults`
- Dock 항목: `modules/darwin/home-manager.nix`의 `local.dock.entries`
- 라이싱(터미널·WM·셸 룩): 레포가 아니라 `~/.config` 쪽 라이브 파일을 고치고
  `apps/rice-save`로 되받는다 — files.nix 류의 심링크는 이제 없다
- 외부 의존성: `flake.nix`의 `inputs`

---

## 꼭 알아야 할 Nix 문법

```nix
{ a = 1; b = 2; }      # attribute set: 키-값, 세미콜론 필수
[ "x" "y" "z" ]        # list: 쉼표 없이 공백 구분

{ config, pkgs, lib, ... }:   # 모듈 함수: "이 인자들을 받는 함수야"
{ ... 설정 ... }               #   반환하는 attribute set. ...는 "나머지 인자 무시"

let user = "jh"; in { home = "/Users/${user}"; }   # 지역 변수 + 문자열 보간

import ./packages.nix { inherit pkgs; }   # 파일=함수. 불러와 { pkgs = pkgs; } 넘겨 실행
{ inherit pkgs; }                         # = { pkgs = pkgs; } 축약
with pkgs; [ git vim curl ]               # 네임스페이스 풀기 (pkgs.git ... 대신)

listA ++ listB         # 리스트 이어붙이기
setA // setB           # attribute set 병합 (오른쪽 우선)
lib.mkMerge [ a b ]    # 모듈 값 여러 개 병합
```

자주 쓰는 lib 헬퍼:

- `lib.mkIf 조건 값` — 조건부 적용(플랫폼 분기)
- `lib.mkMerge [ ... ]` — 여러 정의 병합
- `lib.mkDefault 값` — 기본값(덮어쓸 수 있음)
- `pkgs.callPackage ./x.nix {}` — import와 비슷하나 `pkgs` 내용을 자동 주입
