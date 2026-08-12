# 08. Flake 이해하기

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

`flake.nix`는 이 저장소의 진입점(02번 문서)인데, "flake가 대체 무엇인가"는 따로 짚을 가치가 있다.
flake는 Nix에 재현성과 표준 구조를 가져온 핵심 개념이다.

## 이름의 유래 (왜 "flake"인가)

명문화된 공식 이유는 없다. Eelco Dolstra가 2019 NixCon에서 flakes를 발표하며 붙인 다소 즉흥적인 이름으로,
정설처럼 받아들여지는 설명은 다음과 같다.

- Nix의 로고가 눈송이(snowflake)다 (람다 기호로 만든 눈 결정 모양).
- 그래서 "flake = 눈송이 한 조각" — Nix 생태계를 이루는 하나의 자기완결적 조각이라는 뉘앙스다.
- "눈송이는 제각각 고유하다"는 통념과도 맞는다. 각 flake가 `flake.lock`으로 고유하게·정확히
  식별되는 단위라는 성격과 사후적으로 잘 어울린다.

즉 기술적 약어가 아니라 로고(눈송이)에서 따온 가벼운 작명이며, "공식 어원"이라기보다 커뮤니티 정설이다.

## flake가 푸는 문제

flake 이전의 Nix는 다음 문제가 있었다.

- 의존성을 `nix-channel` / `NIX_PATH`라는 전역·가변 상태로 가져왔다.
  내 머신의 채널 상태에 따라 같은 코드가 다르게 빌드됐다 — 재현성이 깨졌다.
- 입력을 고정(pin)하는 표준 방법이 없었다.
- 프로젝트가 "무엇을 제공하는지"(패키지? 셸? 시스템 설정?) 표준 구조가 없었다.

flake는 이 셋을 한 번에 해결한다.

- 입력을 명시적으로 선언하고, 정확한 버전을 `flake.lock`에 고정한다.
- 출력을 표준 스키마로 노출한다.
- 평가를 순수(pure)하게 만들어, 외부 가변 상태에 의존하지 못하게 한다.

비유: `package.json` + `package-lock.json`을 Nix 전체(패키지뿐 아니라 OS 설정까지)에 적용한 것.

## flake란 무엇인가

`flake.nix` 파일을 가진 디렉토리다. 그 파일은 정해진 스키마를 따른다.

```nix
{
  description = "...";

  inputs = {
    # 외부 의존성 (다른 flake / 저장소 / tarball)
  };

  outputs = { self, nixpkgs, ... }: {
    # 이 flake가 제공하는 것들 (표준 이름의 attribute set)
  };
}
```

핵심은 `outputs`가 함수라는 점이다.
인자로 `self`(자기 자신)와 각 input을 받고, 표준 구조의 attribute set을 반환한다.

## inputs — 고정된 의존성

각 input은 다른 flake나 저장소를 가리킨다. 이 저장소의 예:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  home-manager.url = "github:nix-community/home-manager";
  darwin = {
    url = "github:LnL7/nix-darwin/master";
    inputs.nixpkgs.follows = "nixpkgs";   # darwin도 우리 nixpkgs를 쓰게 통일
  };
  ...
};
```

`follows`가 중요하다. 여러 input이 각자 nixpkgs를 끌어오면 nixpkgs가 여러 벌이 되어
용량·일관성 문제가 생긴다. `inputs.nixpkgs.follows = "nixpkgs"`는
"너도 최상위 nixpkgs를 써라"라고 통일시키는 것이다.

input URL 형식 예:

- `github:owner/repo` 또는 `github:owner/repo/branch`
- `path:/some/local/dir`
- 임의 tarball (`flake = false`로 두면 flake가 아닌 일반 소스로 취급)

## flake.lock — 재현성의 핵심

`flake.lock`은 모든 input의 정확한 커밋 해시와 내용 해시(narHash)를 박아둔 파일이다.
`package-lock.json` / `Cargo.lock`과 같은 역할.

- 이게 있으면 1년 뒤 다른 기계에서도 똑같은 입력으로 똑같이 빌드된다.
- 업데이트하기 전에는 절대 바뀌지 않는다 (자동으로 떠내려가지 않음).
- 반드시 git에 커밋해야 재현성이 보장된다.

업데이트 명령:

```bash
nix flake update            # 모든 input을 최신으로 갱신 (flake.lock 재작성)
nix flake update nixpkgs    # 특정 input만 갱신
```

## 순수 평가(pure evaluation) — git 추적 파일만 본다

flake는 샌드박스에서 순수하게 평가된다. 그래서 다음이 막힌다.

- 임의의 환경변수 읽기
- flake 디렉토리 바깥 파일 읽기
- git에 추적되지 않은 파일 읽기 (중요)

마지막 항목이 우리가 셋업 중 만난 바로 그 에러다.

```text
error: Path '.../karabiner.json' ... is not tracked by Git
```

새 파일을 만들고 모듈에서 참조했는데 `git add` 안 했을 때 나는 에러로,
"순수 평가가 추적되지 않은 파일을 일부러 무시"하기 때문이다.
즉 버그가 아니라 재현성을 지키려는 의도된 동작이다. (06번 문서 0항 참고.)

## outputs — 표준 이름들

`outputs`가 반환하는 attribute set은 정해진 이름을 쓴다. 이 저장소가 내보내는 것:

- `darwinConfigurations.<system>` — nix-darwin이 읽는 macOS 시스템 정의
- `nixosConfigurations.<system>` — NixOS가 읽는 Linux 시스템 정의
- `apps.<system>.<name>` — `nix run`으로 실행할 수 있는 스크립트
- `devShells.<system>` — `nix develop`으로 들어가는 개발 셸

그 밖에 흔히 쓰는 표준 출력: `packages`, `formatter`, `checks`, `overlays`, `nixosModules`.

## flake reference 문법: `flakeref#attrpath`

명령에서 `.#build-switch` 같은 표기를 봤을 것이다. 형식은 `<flake위치>#<출력경로>`다.

- `.#build-switch` = 현재 디렉토리 flake의 `apps.<현재system>.build-switch`
- `.#darwinConfigurations.aarch64-darwin.system` = 그 시스템 빌드 산출물
- `nixpkgs#hello` = nixpkgs flake의 `hello` 패키지
- `github:owner/repo#something` = 원격 flake의 출력

`apps`와 `packages`는 현재 시스템이 자동으로 끼워지지만(`apps.aarch64-darwin.*`),
`darwinConfigurations` 같은 건 전체 경로를 직접 적는다.

## 자주 쓰는 명령

```bash
nix flake show          # 이 flake가 내보내는 출력 트리 보기
nix flake metadata      # input들과 lock 상태 보기
nix flake check         # 출력들이 평가/빌드되는지 검사
nix build .#<출력>      # 출력을 빌드 (result 심볼릭링크 생성)
nix run .#<app>         # 앱 실행
nix develop             # devShell 진입
nix flake update        # flake.lock 갱신
```

## flakes는 experimental feature다

flake와 `nix` 새 CLI(nix-command)는 아직 experimental로 분류돼,
활성화가 필요하다. 보통 `/etc/nix/nix.conf`(또는 nix-darwin이 관리하는 설정)에 다음이 있어야 한다.

```text
experimental-features = nix-command flakes
```

이 설정이 빠지면 `nix run`이 "experimental feature 'nix-command' is disabled"로 막힌다.
임시로는 플래그로 켤 수 있다. (06번 문서 3항에서 겪은 상황.)

```bash
nix --extra-experimental-features 'nix-command flakes' run .#build-switch
```

## 한 줄 요약

flake = `flake.nix`(inputs/outputs 표준 스키마) + `flake.lock`(정확한 핀)을 가진 디렉토리.
입력을 고정하고, 출력을 표준화하고, 평가를 순수하게 만들어,
"언제 어디서 빌드해도 같은 결과"를 보장하는 Nix의 재현성 단위다.
