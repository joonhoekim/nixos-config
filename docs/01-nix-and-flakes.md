# 01. Nix와 flake의 개념

저장소와 무관한 토대 이론. Nix가 어떻게 동작하고, flake가 무엇이며,
NixOS·nix-darwin·home-manager가 어떻게 갈라지고, 왜 nixpkgs가 세계 최대인지.

---

## 1. Nix는 어떻게 동작하는가

### `/nix/store`와 순수 함수

Nix의 모든 것은 한 규칙에서 나온다.

> 모든 빌드 결과물은 `/nix/store/<해시>-<이름>`에 저장된다.
> 해시는 "그것을 만든 모든 입력"(소스·의존성·빌드 옵션)으로 계산된다.

- 입력이 같으면 같은 해시 → 같은 경로 (재현성).
- 입력이 하나라도 다르면 다른 경로 → 버전이 충돌 없이 공존.
- store는 읽기 전용·불변. 패키지는 `/usr/bin`이 아니라 store 안에만 있다.
- "설치"란 store 경로를 가리키는 심볼릭링크(프로필)를 만드는 것일 뿐.

즉 Nix에게 "빌드"는 입력 → 출력의 순수 함수다.

### 시스템 전체도 하나의 빌드 결과물

핵심 도약:

> 당신의 Mac 설정 전체도 하나의 패키지(derivation)다.

`flake.nix`부터 모든 모듈을 평가하면 거대한 attribute set(설정 데이터)이 나오고,
그걸로 `darwin-system`이라는 store 경로 하나를 빌드한다. 그 안에는 깔 패키지 목록,
생성된 `/etc/*`, launchd 서비스 정의, 활성화 스크립트가 들어 있다. 빌드 때 보이는
`result -> /nix/store/...-darwin-system`이 바로 이것 — "원하는 상태"가 통째로
store에 박제된다. 패키지든 시스템 설정이든 Nix에겐 똑같이 "입력으로부터 빌드된 출력"이라,
패키지 매니저가 시스템 설정까지 함께 관리한다.

### 적용의 3단계

`nix run .#build-switch`가 하는 일:

1. **평가(evaluate)** — `flake.nix` + 모든 모듈을 읽어 설정 attrset → `.drv`(설계도) 생성.
   순수 단계라 시스템 변화 없음.
2. **빌드(build)** — `.drv`를 실현. 패키지를 받거나 컴파일해 `/nix/store`를 채운다.
   store만 변하고 라이브 시스템은 그대로. `nix build`까지가 여기며 `result` 링크가 생긴다.
3. **활성화(activate)** — 빌드된 system을 실제 머신에 반영. **시스템을 건드리는 유일한 단계.**
   `/etc` 링크, `defaults write`, launchd 등록, Homebrew, home-manager(dotfile·dock)가 여기서.

활성화 내부 순서(로그 기준):
groups → users → /etc → system defaults → launchd → networking → firewall →
fonts → nvram → Homebrew → home-manager(checkLinkTargets → backup → linkGeneration → dock).

### Generation과 롤백

활성화할 때마다 번호가 매겨진 "generation"이 새로 생기고, 시스템 프로필 심볼릭링크가
새 generation을 가리키도록 **원자적으로** 바뀐다. 옛 generation은 store에 그대로 남는다.

- 망가지면 이전 generation으로 링크만 되돌리면 끝 (`darwin-rebuild rollback`).
- 시스템을 "수정"하는 게 아니라 "통째로 만든 새 버전으로 포인터를 옮기는" 것.
- 이것이 "선언적이라 안전하다"의 진짜 의미다.

---

## 2. Flake

`flake.nix`는 이 저장소의 진입점이지만, "flake가 대체 무엇인가"는 따로 짚을 가치가 있다.

### flake가 푸는 문제

flake 이전 Nix는 의존성을 `nix-channel`/`NIX_PATH`라는 **전역·가변 상태**로 가져왔다.
내 머신 채널 상태에 따라 같은 코드가 다르게 빌드돼 재현성이 깨졌고, 입력을 고정(pin)하는
표준도, "무엇을 제공하는지"의 표준 구조도 없었다. flake는 셋을 한 번에 해결한다.

- 입력을 명시적으로 선언하고 정확한 버전을 `flake.lock`에 고정.
- 출력을 표준 스키마로 노출.
- 평가를 순수(pure)하게 만들어 외부 가변 상태에 의존 못 하게.

비유: `package.json` + `package-lock.json`을 Nix 전체(패키지뿐 아니라 OS 설정까지)에 적용한 것.

> 이름의 유래: Nix 로고가 눈송이(snow**flake**)라서 "생태계를 이루는 자기완결적 조각 하나"라는
> 뉘앙스. 공식 어원이라기보다 커뮤니티 정설.

### 구조

flake = `flake.nix`(정해진 스키마)를 가진 디렉토리. 핵심은 `outputs`가 함수라는 점이다.

```nix
{
  description = "...";
  inputs  = { /* 외부 의존성 */ };
  outputs = { self, nixpkgs, ... }: { /* 제공하는 것들 */ };
}
```

**inputs — 고정된 의존성.** 각 input은 다른 flake/저장소를 가리킨다.

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  darwin = {
    url = "github:LnL7/nix-darwin/master";
    inputs.nixpkgs.follows = "nixpkgs";   # darwin도 우리 nixpkgs를 쓰게 통일
  };
};
```

`follows`가 중요하다. 여러 input이 각자 nixpkgs를 끌어오면 여러 벌이 되어 용량·일관성 문제가
생긴다. `follows = "nixpkgs"`는 "너도 최상위 nixpkgs를 써라"라고 통일시킨다.
URL 형식: `github:owner/repo[/branch]`, `path:/local/dir`, tarball(`flake = false`면 일반 소스).

**`flake.lock` — 재현성의 핵심.** 모든 input의 정확한 커밋 해시·내용 해시(narHash)를 박아둔
파일(`package-lock.json` 역할). 있으면 1년 뒤 다른 기계에서도 똑같이 빌드된다. 업데이트 전엔
바뀌지 않으며, **반드시 git에 커밋**해야 재현성이 보장된다.

```bash
nix flake update            # 모든 input 갱신 (flake.lock 재작성)
nix flake update nixpkgs    # 특정 input만
```

### 순수 평가 — git 추적 파일만 본다

flake는 샌드박스에서 순수 평가되어 임의 환경변수·디렉토리 바깥 파일·**git 미추적 파일**을 못 읽는다.
마지막 항목이 셋업 중 흔히 만나는 에러다.

```text
error: Path '.../karabiner.json' ... is not tracked by Git
```

새 파일을 만들고 모듈에서 참조했는데 `git add`를 안 했을 때 난다. 버그가 아니라 재현성을
지키려는 의도된 동작이다.

### outputs와 flake reference

이 저장소가 내보내는 표준 출력:

- `darwinConfigurations.<system>` — nix-darwin이 읽는 macOS 시스템 정의
- `nixosConfigurations.<system>` — NixOS가 읽는 Linux 시스템 정의
- `apps.<system>.<name>` — `nix run`으로 실행할 스크립트
- `devShells.<system>` — `nix develop`으로 들어가는 개발 셸

명령의 `.#build-switch` 같은 표기는 `<flake위치>#<출력경로>` 형식이다.

- `.#build-switch` = 현재 flake의 `apps.<현재system>.build-switch`
- `.#darwinConfigurations.aarch64-darwin.system` = 그 시스템 빌드 산출물
- `nixpkgs#hello` = nixpkgs flake의 `hello`

`apps`/`packages`는 현재 시스템이 자동으로 끼워지지만, `darwinConfigurations`는 전체 경로를 적는다.

### experimental feature

flake와 새 `nix` CLI는 아직 experimental이라 활성화가 필요하다. nix 설정에 다음이 있어야 한다.

```text
experimental-features = nix-command flakes
```

빠지면 `nix run`이 "experimental feature ... is disabled"로 막힌다. 임시론 플래그로:

```bash
nix --extra-experimental-features 'nix-command flakes' run .#build-switch
```

---

## 3. NixOS vs nix-darwin vs home-manager

### 공유: 언어 + 모듈 시스템

셋 다 같은 Nix 언어와 같은 "모듈 시스템"을 쓴다. 그래서 파일이 똑같아 보인다 —
`{ config, pkgs, ... }: { ... }`, `options`, `mkIf`, `mkOption`. 이 저장소의
`modules/darwin/dock/default.nix`가 좋은 예로, `mkOption`으로 `local.dock` 옵션을 정의하고
`config = mkIf cfg.enable (...)`로 구현한다. 이 "옵션 정의 → 값 병합 → 활성화" 패턴은 셋 다 동일.

### 다름: 누가 무엇을 지배하는가

| | NixOS | nix-darwin | home-manager |
|---|---|---|---|
| 대상 | Linux OS 전체 | macOS 위 레이어 | 유저의 홈 |
| 범위 | 부트로더·커널·systemd·서비스·유저·`/etc` 전부 | Apple이 허용한 부분(패키지·`/etc`·launchd·`system.defaults`·homebrew) | dotfile·유저 패키지·프로그램 설정 |
| 빌더 | `nixpkgs.lib.nixosSystem` | `darwin.lib.darwinSystem` | OS 무관 모듈 |
| 활성화 | systemd, 부팅 단계부터 | launchd | OS 위에서 동작 |
| 깊이 | 가장 깊다(그게 곧 OS) | 얕다(macOS가 닫은 만큼이 천장) | OS 무관, 양쪽 재사용 |

"NixOS가 더 깊다"는 맞다 — OS 자체라 노출부 제한이 없다. nix-darwin은 닫힌 OS 위 오버레이라
Apple이 스크립트로 열어둔 표면까지만 닿는다. 문법은 같고 다스리는 땅이 다르다. 비유하면 모듈 시스템은 공용 설정 언어이고, 셋은 그 언어를
말하는 세 관할 기관(리눅스 전체 / macOS 오버레이 / 유저 홈)이다.

home-manager는 OS와 무관해서 `modules/shared/home-manager.nix`가 양쪽에서 재사용된다.
즉 "셸/에디터/패키지 취향은 한 곳(shared)에 적고, 맥북엔 nix-darwin으로, 리눅스엔 NixOS로
같은 설정을 배포"한다 — 같은 dotfile이 양쪽에서 똑같이 재현된다.

---

## 4. 왜 Nixpkgs는 세계 최대 패키지 저장소인가

NixOS의 데스크탑 점유율은 작은데 패키지 수는 압도적 세계 1위다(Repology 기준 약 12만+,
2위 AUR보다 ~30% 많고 여러 달째 1위). 게다가 **크면서 신선하다** — 보통 트레이드오프인
"패키지 수 vs 최신성"을 둘 다 잡았다. 이유는(영향력 순):

1. **모노레포 + 낮은 기여 장벽 (가장 큼)** — Homebrew·AUR·Debian은 패키징이 분산되거나 승인이
   무겁다. Nixpkgs는 전부 한 저장소이고 패키지 정의가 짧다(`stdenv.mkDerivation { pname; src; ... }`).
   "내가 쓰려고 추가했다가 그냥 올림"이 쉽다. 기여자 수천 명(5,000+).
2. **재현성 모델이 대량 수입을 허용** — 전통 배포판은 전역 `/usr/lib`를 공유해 패키지가 늘수록
   의존성 충돌이 폭증한다. Nix는 각 패키지가 입력으로 해시된 격리 derivation이라 같은 라이브러리
   여러 버전이 공존한다. 충돌 걱정 없이 거대 레지스트리를 통째로 import할 수 있다(원리는 1장 참고).
3. **언어 생태계 제너레이터** — Hackage·MELPA·CRAN·CPAN·TeX Live·Vim 플러그인 등을 코드모드로
   통째 자동 생성(`haskellPackages.*`, `vimPlugins.*` …). 숫자를 크게 부풀리는 승수.
4. **"패키지"의 정의** — derivation 수를 세니 위 세트가 다 카운트된다. 사과 대 사과로 비교하면
   격차가 줄지만 그래도 1위.

**점유율 역설의 해소:** Nix/Nixpkgs는 데스크탑보다 개발 환경·CI·재현 빌드 도구로 훨씬 넓게 쓰인다.
기여자 풀이 패키지를 직접 추가할 능력·동기가 있는 개발자·파워유저에 편중돼 있어, "점유율 대비
패키지 수"가 과대해 보인다. 비유: 인구는 적은데 주민 전원이 목수라 집이 엄청 많은 마을.

한 줄: **충돌 없는 격리 모델 + 단일 저장소 + 자동 생성기**의 조합이 작은 사용자 기반으로도
세계 최대 컬렉션을 만든 비결.

출처: [Discourse](https://discourse.nixos.org/t/nixpkgs-has-been-the-largest-repository-for-months/10667) ·
[Repology counts](https://repology.org/repositories/packages) ·
[Repology nixpkgs](https://repology.org/repository/nix_unstable) ·
[Wikipedia](https://en.wikipedia.org/wiki/Nix_%28package_manager%29) ·
경쟁 위치 분석은 `research/nix-competitive-position.md`.
