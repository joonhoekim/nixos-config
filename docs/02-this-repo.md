# 02. 이 저장소의 구조

진입점이 어디고, 파일들이 어떻게 연결되며, macOS/Linux 분기가 어디서 일어나는지.
`apps/`(`nix run` 래퍼)의 구조와 머신 고유 부분. 그리고 이 저장소를 읽는 데 필요한 Nix 문법.

---

## 진입점: `flake.nix`

모든 것의 시작점. `inputs`(외부 의존성)와 `outputs`(그걸로 무엇을 만들지)로 나뉜다.
`outputs`가 만드는 네 가지:

- `darwinConfigurations.<arch>` → `hosts/darwin/` (macOS) — 이 Mac에서 쓰는 것
- `nixosConfigurations.<hostname>` → `hosts/nixos/<host>/` (Linux, 예: `amd`/`intel`)
- `apps.<system>.{build-switch, build, rollback, clean}` → `apps/<name>` (`nix run`의 실체)
- `devShells`

흐름: `nix run .#build-switch` → `apps.<현재system>.build-switch` → 공유 스크립트 `apps/build-switch`
실행 → `uname`으로 OS를 감지해 macOS면 `darwinConfigurations.<arch>`, NixOS면
`nixosConfigurations.<hostname>`을 빌드·활성화. (`apps/`의 자세한 구조는 아래 "apps/" 절.)

---

## macOS / Linux 분기는 두 군데서 일어난다

### (A) 최상위 분기 — `flake.nix`

```nix
linuxSystems  = [ "x86_64-linux" "aarch64-linux" ];
darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
# macOS: darwin.lib.darwinSystem + ./hosts/darwin
# Linux: nixpkgs.lib.nixosSystem  + ./hosts/nixos
```

플랫폼별로 완전히 다른 빌더와 다른 진입 디렉토리를 쓴다. 이것이 큰 갈래다.

### (B) 파일 안에서의 세밀한 분기 — `isDarwin` / `isLinux`

공유 파일은 한 파일에서 두 OS를 다루므로 줄 단위로 갈라낸다(`modules/shared/home-manager.nix`).

```nix
size = lib.mkMerge [
  (lib.mkIf pkgs.stdenv.hostPlatform.isLinux  10)   # 리눅스면 10
  (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)   # macOS면 14
];
```

`mkIf <조건> <값>` = "조건이 참일 때만 적용". 거짓이면 그 줄은 없는 셈.

---

## 전체 import 그래프

```text
hosts/darwin/default.nix          ← macOS 진입점 (시스템 레벨 설정)
│   imports = [
├──→ modules/darwin/home-manager.nix   ← macOS 유저/홈 레벨
│    │   imports ./dock              (Dock 관리 모듈)
│    │   casks   = ./casks.nix       (GUI 앱)
│    │   home-manager.users.<user>:
│    │     packages = ./packages.nix             (macOS 전용 패키지)
│    │     file     = ../shared/files.nix + ./files.nix   (dotfile 링크)
│    │     programs = ../shared/home-manager.nix          ← 공유
│    └
└──→ modules/shared (= modules/shared/default.nix)   ← nixpkgs 설정 + overlays

modules/shared/   ← darwin과 nixos가 둘 다 쓰는 공통부
├─ home-manager.nix   zsh, git, vim, alacritty, ssh, atuin ... (셸/프로그램)
├─ packages.nix       공통 CLI 패키지
├─ fonts.nix          공통 폰트 (fonts.packages로 등록)
├─ files.nix          공통 dotfile
└─ default.nix        nixpkgs.config + overlays
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
# 스크립트가 플랫폼을 자체 감지하므로 모든 system이 같은 앱을 노출
mkApps = system: {
  "build-switch" = mkApp "build-switch" system;
  "build"        = mkApp "build" system;
  "rollback"     = mkApp "rollback" system;
  "clean"        = mkApp "clean" system;
};
```

`${self}`는 flake 소스 루트. 흐름: `nix run .#build-switch` → writeScriptBin 래퍼 →
`apps/build-switch` → `uname`으로 OS 판별 → macOS면 `darwinConfigurations.<arch>`,
NixOS면 `nixosConfigurations.<hostname>`을 빌드·활성화. 새 app은 `apps/`에 스크립트를 두고
`mkApps`에 한 줄 등록하면 모든 플랫폼에 노출된다.

### 각 app이 하는 일

| app | 용도 | 비고 |
|-----|------|------|
| `build-switch` | 빌드 + 활성화 | **일상 명령.** macOS=`darwin-rebuild switch`, NixOS=`nixos-rebuild switch` |
| `build` | 빌드만 (활성화 X) | 평가·빌드 검증용 |
| `rollback` | 이전 세대로 복구 | 세대 번호 입력(공백=직전). 양 OS |
| `clean` | 구 세대 GC | `nix-collect-garbage --delete-older-than 7d` (인자로 기간 변경) |

인자 규칙 세 가지:

- 추가 플래그는 그대로 전달된다: `nix run .#build-switch -- --show-trace`.
- NixOS 호스트는 `hostname`에서 자동으로 잡고, `--host`로 덮어쓴다(첫 switch 전 유용):
  `nix run .#build-switch -- --host amd`.
- `build-switch`를 통째로 `sudo`로 돌리지 말 것 — 빌드는 유저로, 활성화 단계만 `sudo`.

### 머신 고유 부분: `hardware-configuration.nix`

이 fork는 재배포용 템플릿이 아니라 개인 설정이라, 예전의 `%HOST%`/`%DISK%` 플레이스홀더
치환(`apply`)·비밀키 부트스트랩(`*-keys`)·disko 포맷·`install` 앱은 **전부 제거**했다.
머신마다 다른 값은 한 곳, 각 호스트의 `hardware-configuration.nix`에만 모인다.

- NixOS 호스트는 hostname으로 키잉된다(`nixosConfigurations.amd`, `.intel`). 각
  `hosts/nixos/<host>/`는 공용 `common.nix`(하드웨어 무관 설정) + 자기
  `hardware-configuration.nix`를 import한다.
- `hardware-configuration.nix`는 커밋된 **PLACEHOLDER**다. 해당 머신에서
  `nixos-generate-config --show-hardware-config`로 생성해 교체한 뒤 빌드한다. 교체 전엔
  `fileSystems` 미정의로 빌드가 **일부러 실패**한다 — 잘못된 디스크로 빌드하는 사고 방지.
- CPU 마이크로코드·initrd 모듈·디스크 UUID는 이 파일이 자동으로 담으므로, AMD/Intel 머신
  차이는 여기서 흡수된다. GPU(amdgpu / i915·xe)는 mesa로 공통 처리.

### `nix flake check`는 여전히 NixOS 쪽에서 멈춘다

`flake check`는 darwin뿐 아니라 `nixosConfigurations`까지 평가하는데, 위 placeholder 때문에
`fileSystems` assertion에서 멈춘다(의도된 안전장치). 일상 사용(`build-switch`)에는 영향이 없고,
빨갛게 나오는 건 `flake check`뿐이다. darwin 설정만 검증하려면:

```bash
nix eval --raw '.#darwinConfigurations.aarch64-darwin.config.system.build.toplevel.drvPath'
```

---

## 무엇을 어디서 고치나

- CLI 패키지(양쪽 OS): `modules/shared/packages.nix`
- 셸/git/vim/alacritty 설정: `modules/shared/home-manager.nix`
- 폰트: `modules/shared/fonts.nix` (각 호스트의 `fonts.packages`로 등록)
- GUI 앱(cask): `modules/darwin/casks.nix`
- macOS 시스템 설정: `hosts/darwin/default.nix`의 `system.defaults`
- Dock 항목: `modules/darwin/home-manager.nix`의 `local.dock.entries`
- dotfile 심링크: `modules/shared/files.nix` 또는 `modules/darwin/files.nix`
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
