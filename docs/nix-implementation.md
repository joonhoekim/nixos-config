# Nix 구현체

이 레포의 모든 호스트(NixOS, macOS)는 **CppNix**(NixOS/nix)를 쓴다. 고르는 자리는 옵션 하나다.

```nix
local.nix.implementation = "cppnix";   # 또는 "lix" — modules/shared/nix-implementation.nix
```

`nix.package` 는 이 값에서 나온다(`cppnix` → `pkgs.nix`, `lix` → `pkgs.lixPackageSets.stable.lix`).
그것이 정하는 것은 데몬과 `/run/current-system/sw/bin/nix` 이고, 셸의 `nix` 가 같은 판이 되는 것은
설치기의 `nix-daemon.sh` 를 source 하지 않아서다(아래 "셸이 설치기의 nix-daemon.sh 를 source 하지 않는 이유"). 셋이 같은지는
`nix run .#check` 의 Nix 절이 본다.

## 왜 CppNix 인가 (2026-10)

| | CppNix | Lix | Determinate Nix |
|---|---|---|---|
| nix-darwin 배선 | 기본값 | `nix.package` 한 줄 | `nix.enable = false` 가 필요하다 → 이 레포의 `nix.settings`·`nix.gc` 가 먹지 않는다 |
| 받는 곳 | nixpkgs | nixpkgs | 별도 flake |
| flakes | experimental 플래그 | 2.94 에서 동결, 2.95 부터 플러그인으로 떼어 내는 중 | 정식 기능 |

- 이 레포는 flakes 위에 서 있다: 호스트 = `hosts/` 의 디렉토리, 비공개 `git+https` input, `apps/` 가
  전부 `nix run .#…`. 그 기능이 더 자라지 않는 쪽(Lix)을 고를 까닭이 약하다.
- nix-darwin·home-manager·nixpkgs 의 기본값과 문서가 CppNix 를 전제로 하고, Nix 라이브러리를 링크하는
  도구는 구현체마다 따로 빌드된다(nixpkgs 의 `lixPackageSets`).
- Determinate 는 Nix 설정·데몬·GC 를 레포가 아니라 그쪽 모듈이 쥐게 한다. 설정을 이 레포가 선언한다는
  원칙과 반대다. Snix(Tvix 포크)는 아직 데몬을 대신할 단계가 아니다.

## 다시 볼 조건

- Lix 의 flakes 플러그인이 정착하고, 이 레포가 쓰는 flakes 기능이 그대로 돌 때
- CppNix 가 flakes 나 nix-darwin 호환을 깨는 변경을 연달아 낼 때
- nix-darwin 이나 home-manager 의 기본값이 바뀔 때

## 바꿀 때

1. `nix run .#check-eval -- --with lix` — 모든 호스트를 다른 구현체로 평가해 지금 것과 같은 drvPath 가
   나오는지, 그쪽에서만 나는 경고가 있는지 본다(통과를 강제하는 게이트는 아니다).
2. 공유 코드에 한쪽에만 있는 문법·builtin 을 쓰지 않는다. 파이프 연산자는 실험 기능의 이름부터 다르다
   (CppNix `pipe-operators`, Lix `pipe-operator`). 한쪽만 아는 `nix.conf` 키도 공용 `nix.settings` 에
   두지 않는다.
3. 옵션값을 바꾸고 switch 한 뒤 `nix run .#check` 의 "nix 한 벌" 항목을 본다.

### check-eval 결과 읽기 (`apps/check/eval`)

`nix run .#check-eval [-- --with cppnix]`(기본 lix)는 모든 호스트를 다른 구현체로도 평가해 지금 구현체와
비교한다. 아무것도 빌드하지 않고 고치지 않는다. 다른 구현체는 이 flake 가 고정한 nixpkgs 에서 받으므로 캐시에
있어 빌드가 없다.

- 같은 nixpkgs 로 평가하면 두 구현체의 drvPath 는 같아야 한다. 다르면 평가 결과 자체가 갈린 것이라 ✗.
- 다른 구현체에서만 평가되지 않으면 ✗. 한쪽에만 있는 문법·builtin 이나, Lix 가 오류로 올린 deprecation 은 그
  구현체로 평가해야만 드러난다.
- 같은 결과인데 다른 구현체에서만 나는 경고는 갈아탈 때 고칠 목록이라 ⚠.

통과를 강제하는 게이트가 아니라 갈아탈 수 있는지를 재는 용도다.

## 셸이 설치기의 nix-daemon.sh 를 source 하지 않는 이유

nix 환경은 nix-darwin 의 /etc/bashrc·/etc/zshrc 가 set-environment 로 이미 잡는다(PATH, NIX_PROFILES,
NIX_SSL_CERT_FILE, XDG_DATA_DIRS). NixOS 에는 그 파일이 없다. 설치기의 `profile.d/nix-daemon.sh` 를
`modules/shared/shell-init.nix` 에서 부르면 두 가지가 조용히 틀어진다:

- PATH 맨 앞에 `/nix/var/nix/profiles/default/bin` 을 넣는다. 셸의 `nix` 가 nix.package 가 아니라 설치할 때
  깐 판이 되고, sudo 아래도 같다. 데몬은 nix.package 라서 클라이언트와 데몬의 판(심지어 구현체)이 갈린다.
- NIX_PROFILES 를 "default ~/.nix-profile" 로 덮어써서 `/run/current-system/sw` 와 `/etc/profiles/per-user/<user>`
  가 빠진다.

확인: `command -v nix` 가 `/run/current-system/sw/bin/nix` 여야 한다(`apps/check/mac`).

## 설치기

설치기는 구현체와 따로다. 설치기는 설치·제거와 macOS 업데이트 뒤 복구에만 관여한다
(`docs/clean-install-macos.md`).

## 출처

- [Lix 2.95 "Kakigōri"](https://lix.systems/blog/2026-03-25-lix-2.95-release)
- [Nix 2.35.0 released](https://discourse.nixos.org/t/nix-2-35-0-released/78914)
- [nix-darwin 과 Determinate (`nix.enable = false`)](https://determinate.systems/blog/nix-darwin-updates/)
- [Announcing Snix](https://snix.dev/blog/announcing-snix/)
