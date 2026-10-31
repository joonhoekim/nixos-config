# Nix 구현체

이 레포의 모든 호스트(NixOS, macOS)는 **CppNix**(NixOS/nix)를 쓴다. 고르는 자리는 옵션 하나다.

```nix
local.nix.implementation = "cppnix";   # 또는 "lix" — modules/shared/nix-implementation.nix
```

`nix.package` 는 이 값에서 나온다(`cppnix` → `pkgs.nix`, `lix` → `pkgs.lixPackageSets.stable.lix`).
그것이 정하는 것은 데몬과 `/run/current-system/sw/bin/nix` 이고, 셸의 `nix` 가 같은 판이 되는 것은
설치기의 `nix-daemon.sh` 를 source 하지 않아서다(`modules/shared/shell-init.nix` 머리말). 셋이 같은지는
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

설치기는 구현체와 따로다. 설치기는 설치·제거와 macOS 업데이트 뒤 복구에만 관여한다
(`docs/clean-install-macos.md`).

## 출처

- [Lix 2.95 "Kakigōri"](https://lix.systems/blog/2026-03-25-lix-2.95-release)
- [Nix 2.35.0 released](https://discourse.nixos.org/t/nix-2-35-0-released/78914)
- [nix-darwin 과 Determinate (`nix.enable = false`)](https://determinate.systems/blog/nix-darwin-updates/)
- [Announcing Snix](https://snix.dev/blog/announcing-snix/)
