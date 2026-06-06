# 02. 이 저장소의 구조

진입점이 어디고, 파일들이 어떻게 연결되며, macOS/Linux 분기가 어디서 일어나는지.
그리고 이 저장소를 읽는 데 꼭 필요한 Nix 문법.

## 진입점: `flake.nix`

모든 것의 시작점. 크게 두 부분이다.

- `inputs` — 외부 의존성 (nixpkgs, home-manager, nix-darwin, nix-homebrew, disko ...)
- `outputs` — 그 의존성들로 "무엇을 만들지" 정의

`outputs`가 만드는 네 가지:

- `darwinConfigurations.<system>` → `hosts/darwin/` (macOS 시스템) — 이 Mac에서 쓰는 것
- `nixosConfigurations.<system>` → `hosts/nixos/` (Linux 시스템)
- `apps.<system>.{build-switch, ...}` → `apps/<system>/` (`nix run .#build-switch`의 실체)
- `devShells`

흐름: `nix run .#build-switch` → `apps.aarch64-darwin.build-switch` →
`apps/aarch64-darwin/build-switch` 스크립트 실행 → 내부에서
`darwinConfigurations.aarch64-darwin`을 빌드·활성화.

## macOS / Linux 분기는 두 군데서 일어난다

### (A) 최상위 분기 — `flake.nix`

```nix
linuxSystems  = [ "x86_64-linux" "aarch64-linux" ];
darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];

# macOS: darwin.lib.darwinSystem + ./hosts/darwin
# Linux: nixpkgs.lib.nixosSystem  + ./hosts/nixos
```

플랫폼별로 완전히 다른 빌더(`darwinSystem` vs `nixosSystem`)와
다른 진입 디렉토리(`hosts/darwin` vs `hosts/nixos`)를 쓴다. 이것이 큰 갈래다.

### (B) 파일 안에서의 세밀한 분기 — `isDarwin` / `isLinux`

공유 파일은 한 파일에서 두 OS를 모두 다루므로 줄 단위로 갈라낸다.
(`modules/shared/home-manager.nix`)

```nix
size = lib.mkMerge [
  (lib.mkIf pkgs.stdenv.hostPlatform.isLinux  10)   # 리눅스면 폰트 10
  (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)   # macOS면 폰트 14
];
```

`mkIf <조건> <값>` = "조건이 참일 때만 이 값을 적용". 거짓이면 그 줄은 없는 셈이 된다.

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

modules/shared/   ← darwin과 nixos가 둘 다 가져다 쓰는 공통부
├─ home-manager.nix   zsh, git, vim, alacritty, ssh, atuin ... (셸/프로그램)
├─ packages.nix       공통 CLI 패키지
├─ files.nix          공통 dotfile
└─ default.nix        nixpkgs.config + overlays
```

리눅스 쪽도 대칭이다. `hosts/nixos/default.nix` → `modules/nixos/*` → 같은 `modules/shared/*`를 재사용.

핵심 원칙:

- `modules/shared/`를 고치면 두 OS 모두에 영향을 준다.
- `modules/darwin/`을 고치면 macOS만 영향을 받는다.
- 어디를 고칠지 헷갈리면 "이게 리눅스에도 해당되나?"를 물어보면 된다.

## 꼭 알아야 할 Nix 문법

### Attribute set `{ }` vs List `[ ]`

```nix
{ a = 1; b = 2; }     # 키-값. 세미콜론 필수(끝에도).
[ "x" "y" "z" ]       # 리스트. 쉼표 없이 공백으로 구분.
```

### 모듈 함수 패턴 `{ config, pkgs, lib, ... }:`

거의 모든 `.nix` 파일의 첫 줄이다.

```nix
{ config, pkgs, lib, ... }:   # "이 인자들을 받는 함수야"
{ ... 설정 ... }               # 반환하는 attribute set
```

`...`는 "나머지 인자는 무시". nix-darwin/home-manager가 `config`, `pkgs` 등을 자동으로 넣어준다.

### `let ... in` — 지역 변수

```nix
let user = "jh"; in
{ home = "/Users/${user}"; }
```

### `import` — 파일은 곧 함수

```nix
import ./packages.nix { inherit pkgs; }
#  파일을 불러와 그 함수에 { pkgs = pkgs; } 를 넘겨 실행
```

`.nix` 파일이 `{ pkgs }: [ ... ]` 같은 함수면, `import`는 그것을 호출하는 것이다.

### `inherit` — 축약

```nix
{ inherit pkgs; }              # = { pkgs = pkgs; }
{ inherit user config pkgs; }  # 세 개를 한꺼번에
```

### `with` — 네임스페이스 풀기

```nix
with pkgs; [ git vim curl ]    # pkgs.git, pkgs.vim ... 대신
```

`packages.nix`가 `with pkgs; [ ... ]`인 이유.

### 합치기 연산자

```nix
listA ++ listB         # 리스트 이어붙이기 (packages 합칠 때)
setA // setB           # attribute set 병합, 오른쪽 우선 (files 합칠 때)
lib.mkMerge [ a b ]    # 모듈 값 여러 개 병합
```

### 문자열 보간

```nix
"/Users/${user}/.config"
```

### 자주 쓰는 lib 헬퍼

- `lib.mkIf 조건 값` — 조건부 적용 (플랫폼 분기)
- `lib.mkMerge [ ... ]` — 여러 정의 병합
- `lib.mkDefault 값` — 기본값(다른 데서 덮어쓸 수 있음)
- `pkgs.callPackage ./x.nix {}` — import와 비슷하나 `pkgs`의 내용을 자동 주입

## 무엇을 어디서 고치나

- CLI 패키지 (양쪽 OS): `modules/shared/packages.nix`
- 셸/git/vim/alacritty 설정: `modules/shared/home-manager.nix`
- GUI 앱 (cask): `modules/darwin/casks.nix`
- macOS 시스템 설정: `hosts/darwin/default.nix`의 `system.defaults`
- Dock 항목: `modules/darwin/home-manager.nix`의 `local.dock.entries`
- dotfile 심볼릭링크: `modules/shared/files.nix` 또는 `modules/darwin/files.nix`
- 외부 의존성 추가/변경: `flake.nix`의 `inputs`
