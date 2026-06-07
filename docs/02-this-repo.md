# 02. 이 저장소의 구조

진입점이 어디고, 파일들이 어떻게 연결되며, macOS/Linux 분기가 어디서 일어나는지.
`apps/`의 정체와 부트스트랩(플레이스홀더) 구조. 그리고 이 저장소를 읽는 데 필요한 Nix 문법.

---

## 진입점: `flake.nix`

모든 것의 시작점. `inputs`(외부 의존성)와 `outputs`(그걸로 무엇을 만들지)로 나뉜다.
`outputs`가 만드는 네 가지:

- `darwinConfigurations.<system>` → `hosts/darwin/` (macOS) — 이 Mac에서 쓰는 것
- `nixosConfigurations.<system>` → `hosts/nixos/` (Linux)
- `apps.<system>.{build-switch, ...}` → `apps/<system>/` (`nix run .#build-switch`의 실체)
- `devShells`

흐름: `nix run .#build-switch` → `apps.aarch64-darwin.build-switch` →
`apps/aarch64-darwin/build-switch` 실행 → 내부에서 `darwinConfigurations.aarch64-darwin`을 빌드·활성화.
(`apps/`의 자세한 구조는 아래 "apps/ 와 부트스트랩" 절.)

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

리눅스도 대칭이다. `hosts/nixos/default.nix` → `modules/nixos/*` → 같은 `modules/shared/*` 재사용.

핵심 원칙:

- `modules/shared/`를 고치면 두 OS 모두 영향. `modules/darwin/`은 macOS만.
- 헷갈리면 "이게 리눅스에도 해당되나?"를 물어보면 된다.

---

## `apps/` 와 부트스트랩

### `apps/`의 정체: "내용은 bash, 진입은 Nix"

흔한 오해: "그냥 clone할 때 돌리는 CLI고 Nix와 무관하다." → **반은 맞고 반은 틀리다.**
`apps/<system>/` 안의 파일은 평범한 **bash 스크립트**(Nix 언어 아님)지만, flake의 **`apps` 출력**으로
노출되어 `nix run`으로 실행된다. 즉 Nix가 진입점(`nix run .#<name>`)을 제공하고 실제 일은 bash가 한다.

연결 고리(`flake.nix`):

```nix
mkApp = scriptName: system: {
  type = "app";
  program = "${(writeScriptBin scriptName ''
    #!/usr/bin/env bash
    PATH=${git}/bin:$PATH                       # git을 PATH에 보장
    exec ${self}/apps/${system}/${scriptName}   # 실제 bash 스크립트 실행
  '')}/bin/${scriptName}";
};
```

`${self}`는 flake 소스 루트. 흐름: `nix run .#build-switch` → flake 출력 → writeScriptBin 래퍼 →
`apps/<system>/build-switch` bash → 내부에서 `darwinConfigurations.<system>` 빌드·활성화.

디렉터리는 system마다 따로다(상수 `SYSTEM_TYPE`가 박혀 있음). `aarch64-linux`는 `x86_64-linux`
심링크. 새 app 추가 시 각 system 디렉터리에 파일을 두고 `flake.nix`의
`mkDarwinApps`/`mkLinuxApps`에 `"name" = mkApp "name" system;`를 등록한다.

### 각 app이 하는 일

| app | 용도 | 비고 |
|-----|------|------|
| `apply` | **부트스트랩(1회)**. 플레이스홀더 치환 | clone 직후 한 번. 대화형 |
| `build` | 빌드만 (활성화 X) | `nix build .#…system`, 결과 확인용 |
| `build-switch` | 빌드 + 활성화 | **일상 명령.** `sudo darwin-rebuild switch` |
| `clean` | 구 세대 GC | `nix-collect-garbage --delete-older-than 7d` |
| `rollback` | 이전 세대로 복구 | 세대 번호 입력 (darwin 전용) |
| `*-keys` | SSH/GPG 키 생성·복사·확인 | `create-/copy-/check-keys` |

### `apply` = 코드모드: 플레이스홀더 치환

`apply`는 단순 빌드가 아니라 **소스 파일을 `sed`로 직접 고치는 코드모드**다. clone 직후 한 번
돌려 템플릿 토큰을 내 환경 값으로 바꾼다.

| 토큰 | 의미 | 채워지는 곳 |
|------|------|-------------|
| `%USER%` / `%EMAIL%` / `%NAME%` | 사용자명·git 신원 | 양쪽 OS |
| `%HOST%` | 호스트명 | NixOS 전용 |
| `%INTERFACE%` | 기본 네트워크 인터페이스 | NixOS 전용 |
| `%DISK%` | 부트 디스크(disko 포맷 대상) | NixOS 전용 |

**핵심: macOS(Darwin) 분기는 `%HOST%`/`%INTERFACE%`/`%DISK%`를 일부러 건너뛴다**(Linux 전용 값).
그래서 Mac에서 `apply`를 돌려도 NixOS 쪽 플레이스홀더 3개는 그대로 남는다. 현재 남은 것:

```
hosts/nixos/default.nix:37        hostName = "%HOST%"
hosts/nixos/default.nix:39        interfaces."%INTERFACE%".useDHCP
modules/nixos/disk-config.nix:7   device = "/dev/%DISK%"
```

### 그래서 `nix flake check`가 실패한다 (의도된 동작)

`nix flake check`는 darwin뿐 아니라 **`nixosConfigurations`까지 전부 평가**한다. 위 `%HOST%`는
호스트명 정규식 타입 검사를 통과 못 해 거기서 터진다:

```
error: A definition for option `networking.hostName' is not of type
`string matching the pattern ...`. Definition values:
- In `…/hosts/nixos': "%HOST%"
```

**버그가 아니라 템플릿 설계의 트레이드오프다:**

1. 이건 clone해서 자기 걸로 만드는 **템플릿**이라, `apply`가 찾아 치환하도록 플레이스홀더가
   커밋된 채 있어야 한다. 실제 값을 박으면 모두가 남의 호스트명·디스크를 clone하게 된다.
2. 안내 워크플로는 `nix run .#apply` → `nix run .#build-switch`이지 `flake check`가 아니다.
3. `%HOST%`는 일부러 유효하지 않게 생겼다(grep으로 찾기 쉽게). `"nixos"` 같은 유효 기본값은
   check는 통과시키지만 잘못된 호스트명/디스크로 빌드할 위험을 만든다(특히 `%DISK%`는 포맷 대상).

**중요: `build-switch`와 일상 사용에는 영향 없다.** 빨갛게 나오는 건 `nix flake check`뿐.
darwin 설정만 검증하려면(플레이스홀더 무관):

```bash
nix eval --raw '.#darwinConfigurations.aarch64-darwin.config.system.build.toplevel.drvPath'
```

> 플레이스홀더를 임시 더미값(`%HOST%`→`check-host`, `%DISK%`→`sda`)으로 치환했다가 check 후
> 원복하는 "검증용 코드모드"를 둘 수도 있다. `%DISK%`는 평가만으론 안 터지므로 더미값은 안전.

### 이 fork에서의 선택

이건 재배포할 템플릿이 아니라 **개인 fork**라, "남이 clone한다"는 제약이 없다. NixOS를 실제로
쓸 때 두 길:

- **(A) 템플릿 유지** — 실제 NixOS 머신에서 `nix run .#apply`로 3개 값을 그 자리에서 채운다.
  머신별 disk/interface를 의식적으로 고르게 되어 안전. Mac에선 `flake check`가 계속 실패로 남음.
- **(B) 개인 설정 전환** — 호스트명을 정했다면 실제 값을 커밋. interface는
  `networking.useDHCP = true`로 명시를 없애고 disk만 실제 장치명으로. 그러면 `flake check`도 통과.

어느 쪽이든 `%DISK%`는 그 머신에서 신중히 정한다(포맷 대상).

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
