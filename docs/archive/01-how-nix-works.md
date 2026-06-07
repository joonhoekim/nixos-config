# 01. Nix는 어떻게 동작하는가

단순 패키지 매니저가 왜 시스템 설정·dock·서비스까지 선언적으로 관리할 수 있는지, 그 원리와 적용 순서.

## 출발점: `/nix/store`와 순수 함수

Nix의 모든 것은 한 가지 규칙에서 나온다.

> 모든 빌드 결과물은 `/nix/store/<해시>-<이름>` 에 저장된다.
> 해시는 "그것을 만든 모든 입력"(소스, 의존성, 빌드 옵션)으로 계산된다.

특징:

- 입력이 같으면 항상 같은 해시 → 같은 경로 (재현성).
- 입력이 하나라도 다르면 다른 해시 → 다른 경로 (버전이 충돌 없이 공존).
- store는 읽기 전용·불변. 패키지가 `/usr/bin`에 깔리는 게 아니라 store 안에만 존재한다.
- "설치"란 사실 store 경로를 가리키는 심볼릭링크(프로필)를 만드는 것일 뿐이다.

즉 Nix에게 "빌드"는 입력 → 출력의 순수 함수다. 같은 입력은 같은 출력.

## 도약: 시스템 전체도 하나의 빌드 결과물이다

핵심 통찰은 이것이다.

> 당신의 Mac 설정 전체도 하나의 패키지(derivation)다.

`flake.nix`부터 모든 모듈을 평가하면 거대한 attribute set(설정 데이터)이 나오고,
그걸로 `darwin-system`이라는 store 경로 하나를 빌드한다. 그 안에는 다음이 들어 있다.

- 깔아야 할 패키지 목록
- 생성된 `/etc/*` 파일들
- launchd 서비스 정의
- 활성화 스크립트

우리가 빌드 때마다 본 `result -> /nix/store/...-darwin-system`이 바로 이것이다.
"내 컴퓨터의 원하는 상태(desired state)"가 통째로 store 안의 데이터로 박제된다.
패키지든 시스템 설정이든 Nix 입장에선 똑같이 "입력으로부터 빌드된 출력"일 뿐이라,
패키지 매니저가 시스템 설정도 함께 관리하는 것이다.

## 적용의 순서: 3단계

`nix run .#build-switch`가 하는 일을 단계로 쪼개면 이렇다.

### 1단계 — 평가 (evaluate)

`flake.nix` + 모든 모듈을 읽어 설정 attrset을 만들고, 그걸로 `.drv`(설계도)를 생성한다.
순수 단계라 시스템에는 아무 변화도 없다.

### 2단계 — 빌드 (build)

`.drv`를 실현한다. 패키지를 다운로드하거나 컴파일해 `/nix/store`를 채운다.
이때도 store만 변할 뿐, 라이브 시스템은 그대로다.
`nix build`까지가 여기에 해당하며, 결과로 `result` 심볼릭링크가 생긴다.

### 3단계 — 활성화 (activate)

빌드된 system을 실제 머신에 반영한다. 시스템을 실제로 건드리는 유일한 단계다.
`build-switch`의 "Switching to new generation..." 이후가 이 단계이며,
로그에서 본 다음 항목들이 모두 여기서 일어난다.

- `setting up /etc...` — store의 `/etc` 파일들을 심볼릭링크
- `system defaults...` — macOS `defaults write` 실행
- `setting up launchd...` — 서비스 등록
- `Homebrew bundle...` — casks 설치
- home-manager activation — dotfile 링크, dock 설정

활성화 내부의 실제 순서(우리가 로그에서 본 것):
groups → users → /etc → system defaults → launchd → networking → firewall →
fonts → nvram → Homebrew → home-manager(checkLinkTargets → backup → linkGeneration → dock).

## 안전장치: Generation과 롤백

활성화할 때마다 번호가 매겨진 "generation"이 새로 생기고,
시스템 프로필 심볼릭링크가 새 generation을 가리키도록 원자적으로 바뀐다.
옛 generation은 store에 그대로 남는다.

- 뭔가 망가지면 이전 generation으로 심볼릭링크만 되돌리면 끝이다 (`darwin-rebuild rollback`).
- 시스템을 "수정"하는 게 아니라, "통째로 만든 새 버전으로 포인터를 옮기는" 것이다.
- 이것이 "선언적이라 안전하다"의 진짜 의미다.

## 한 줄 요약

설정을 데이터로 빌드해 store에 박제하고(평가 → 빌드),
라이브 시스템이 그 데이터에 수렴하도록 활성화한다.
패키지든 `/etc`든 dock이든 전부 같은 원리이며, 각 활성화는 되돌릴 수 있는 generation이 된다.
