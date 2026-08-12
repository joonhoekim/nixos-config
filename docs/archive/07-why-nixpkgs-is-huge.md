# 07. 왜 Nixpkgs는 세계 최대 패키지 저장소인가

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

Nix의 사용자(특히 데스크탑 OS로서 NixOS) 점유율은 작은데, 패키지 수는 압도적으로 세계 1위다.
이 역설이 어떻게 가능한가.

## 규모: 실제 수치 (Repology 기준)

총 패키지(packaged projects) 수 1위는 압도적으로 nixpkgs다.

- nix (nixpkgs unstable): 약 114,770개 — 1위
- AUR (Arch User Repository): 약 89,581개 — 2위
- Debian + 파생: 약 44,894개
- FreeBSD Ports: 약 32,762개
- GNU Guix: 약 30,957개

2025년 1월 기준으로는 12만 개 이상으로 더 늘었고, 2위 AUR보다 30% 가까이 많다.
게다가 일시적 1위가 아니라 여러 달째 지속적으로 1위를 지키고 있다.

## 더 인상적인 점: 크면서 신선하다

보통 패키지가 많으면 관리가 안 되어 버전이 낡기 마련인데, nixpkgs는 최신성(up-to-date 비율)도 1위다.
Repology에서 "패키지 수 vs 신선도" 그래프를 그리면 nixpkgs만 혼자 다른 구역에 동떨어져 찍힌다 —
많으면서 동시에 새것. 보통 이 둘은 트레이드오프인데 둘 다 잡았다.

## 진짜 이유 (영향력 순)

### 1. 모노레포 + 낮은 기여 장벽 (가장 큰 이유)

Homebrew·AUR·Debian은 패키징이 분산돼 있거나(별도 tap/PPA) 메인테이너 승인 절차가 무겁다.
Nixpkgs는 전부 한 저장소다. 패키지 하나 추가 = 작은 `.nix` 파일 하나 + PR 하나.

게다가 패키지 정의가 보통 짧다.

```nix
stdenv.mkDerivation {
  pname = "foo"; version = "1.2.3";
  src = fetchFromGitHub { ... };
  buildInputs = [ ... ];
}
```

"내가 쓰려고 추가했다가 그냥 올림"이 매우 쉽다. 이 마찰의 낮음이 누적 규모를 만든 핵심이다.
실제로 Nixpkgs는 GitHub에서 가장 활발한 저장소 중 하나이고, 기여자가 수천 명(대략 5,000명+)에 이른다.

### 2. 재현성 모델이 "대량 수입"을 가능하게 함

이게 미묘하지만 결정적이다. 전통적 배포판은 패키지가 늘수록 의존성 충돌(dependency hell)이 폭증해
규모에 한계가 있다. 하나의 전역 `/usr/lib`를 공유하기 때문이다.

Nix는 각 패키지가 자기 입력으로 해시된 격리된 derivation이라,
같은 라이브러리의 여러 버전이 충돌 없이 공존한다.
그래서 충돌 걱정 없이 거대한 레지스트리를 기계적으로 통째로 import할 수 있다.
모델 자체가 스케일을 허용하는 것이다. (원리는 01번 문서 참고.)

### 3. 언어 생태계 제너레이터 (코드모드 기반 자동 생성)

Nixpkgs는 상류 레지스트리를 통째로 자동 생성해서 끌어온다.

- Haskell: Hackage/Stackage 전체를 `hackage2nix`로 자동 생성 → 수천 개
- Emacs(MELPA), Vim/Neovim 플러그인, R(CRAN/Bioconductor), Perl(CPAN), TeX Live, Python, Node, Rust 등도 마찬가지

`haskellPackages.*`, `vimPlugins.*`, `rPackages.*` 같은 세트가 각각 수천 개씩 기여한다.
10만이라는 숫자의 상당 부분이 이 자동 생성 세트다.
즉 "자동 생성이 많아서"는 메인 동력은 아니지만 숫자를 부풀리는 큰 승수로서 정확하다.

### 4. "패키지"의 정의 문제

Nixpkgs는 derivation(attribute) 수를 센다. 위 언어 세트가 다 카운트되니,
"패키지 수"는 부분적으로 무엇을 세느냐의 함수다.
사과 대 사과로 비교하면 격차가 조금 줄지만, 그래도 여전히 1위다.

## "점유율은 미미한데?" 역설의 해소

- 데스크탑 OS로서의 NixOS는 점유율이 작다. 사실이다.
- 하지만 Nix/Nixpkgs는 개발 환경·CI·재현 빌드 도구로 훨씬 넓게 쓰인다.
  "데스크탑은 안 써도 빌드는 Nix로" 하는 회사가 많다.
- 즉 기여자 풀이 개발자·파워유저에 편중돼 있다. 일반 사용자 점유율은 작아도,
  패키지를 직접 추가할 능력·동기가 있는 사람의 비율이 비정상적으로 높은 모집단이다.
  그래서 "점유율 대비 패키지 수"가 과대해 보인다.

비유하자면, 동네 인구는 적은데 주민 전원이 목수인 마을이라 집(패키지)이 엄청 많이 지어진 셈이다.

## 정리

- "기여자가 많아서" → 맞지만, 더 정확히는 모노레포라 기여 마찰이 극도로 낮아서.
- "자동 생성이 많아서" → 언어 세트에 한해 맞고, 숫자를 크게 부풀리는 승수.
  다만 토대는 재현성 모델이 대량 import를 충돌 없이 허용한다는 점이다.

가장 깊은 한 줄: 충돌 없는 격리 모델 + 단일 저장소 + 자동 생성기의 조합이,
작은 사용자 기반으로도 세계 최대 패키지 컬렉션을 만들어낸 비결이다.

## 출처

- [NixOS Discourse — Nixpkgs has been the largest repository for months](https://discourse.nixos.org/t/nixpkgs-has-been-the-largest-repository-for-months/10667)
- [Repology — Raw repository package counts](https://repology.org/repositories/packages)
- [Repology — nixpkgs unstable repository info](https://repology.org/repository/nix_unstable)
- [Nix (package manager) — Wikipedia](https://en.wikipedia.org/wiki/Nix_%28package_manager%29)
