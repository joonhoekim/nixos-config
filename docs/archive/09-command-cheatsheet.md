# 09. 자주 쓰는 명령어 치트시트

이 저장소를 운영할 때 실제로 자주 치는 명령들. 아키텍처는 `aarch64-darwin` 기준.
(다른 Mac이면 `aarch64-darwin` 자리를 해당 system으로 바꾼다.)

## 일상 워크플로

```bash
# 빌드 + 시스템에 활성화 (가장 자주 씀). sudo 암호를 물어봄
nix run .#build-switch

# 활성화 없이 빌드만 — 변경이 깨지는지 안전하게 검증할 때
nix build .#darwinConfigurations.aarch64-darwin.system

# 빌드만 하는 저장소 전용 앱 (위 build 명령의 래퍼)
nix run .#build
```

원칙: 설정을 고치면 먼저 `nix build`로 통과를 확인하고, 괜찮으면 `build-switch`로 적용한다.
`build`는 시스템을 건드리지 않아 안전하다.

## 롤백 / generation 관리

```bash
# 직전 generation으로 되돌리기 (저장소 전용 앱)
nix run .#rollback

# nix-darwin 직접 사용
darwin-rebuild --list-generations          # generation 목록
darwin-rebuild --rollback                   # 직전으로
darwin-rebuild --switch-generation 42       # 특정 번호로
```

각 `build-switch`는 되돌릴 수 있는 새 generation을 만든다 (원리는 01번 문서 참고).

## flake / 의존성 갱신

```bash
nix flake update                 # 모든 input을 최신으로 (flake.lock 재작성)
nix flake update nixpkgs         # 특정 input만 갱신
nix flake show                   # 이 flake가 내보내는 출력 트리
nix flake metadata               # input들과 lock 상태
nix flake check                  # 출력들이 평가/빌드되는지 검사
```

`nix flake update` 후에는 `nix build`로 검증하고 `build-switch` 하는 흐름을 권장.
`flake.lock`이 바뀌므로 그 변경도 커밋해야 재현성이 유지된다.

## 패키지 탐색 / 임시 사용 (설치 없이)

```bash
nix search nixpkgs ripgrep       # 패키지 검색
nix shell nixpkgs#ripgrep        # 임시로 현재 셸에 추가 (셸 닫으면 사라짐)
nix run nixpkgs#ripgrep -- --help # 설치 없이 한 번 실행
```

"이거 영구히 쓰겠다" 싶으면 그때 `modules/shared/packages.nix`(또는 darwin 전용)에 추가.

## 진단 / 디버깅

```bash
# 무엇이 새로 빌드되는지(캐시에 없는지) 미리 확인
nix build .#darwinConfigurations.aarch64-darwin.system --dry-run

# 에러가 모호할 때 자세한 평가 추적
nix build .#darwinConfigurations.aarch64-darwin.system --show-trace

# 실패한 derivation의 전체 빌드 로그
nix log /nix/store/xxxx.drv
nix-store -l /nix/store/xxxx.drv      # 위가 안 되면 이걸로

# 왜 이 패키지가 들어왔는지 의존 경로 추적
nix why-depends .#darwinConfigurations.aarch64-darwin.system nixpkgs#<pkg>
```

## Homebrew (이 저장소는 mutableTaps = true)

```bash
# 선언적 관리: GUI 앱은 modules/darwin/casks.nix 에 추가 후 build-switch

# 수동도 허용됨 (mutableTaps = true 라서)
brew install <formula>
brew tap <user>/<repo>           # 커스텀 tap (예: aerospace)
brew list                        # 설치된 것 보기
brew update && brew upgrade      # 수동 설치분 갱신
```

## 정리 / 디스크 회수 (GC)

```bash
nix-collect-garbage -d           # 유저 프로필의 오래된 generation 삭제
sudo nix-collect-garbage -d      # 시스템 프로필까지
nix run .#clean                  # 저장소 전용 정리 앱
```

참고: 이 저장소는 `hosts/darwin/default.nix`에서 주간 자동 GC(30일 이상 된 것 삭제)가 켜져 있다.

## 적용 후 반영 / 확인

```bash
# 새 zsh 설정(p10k, atuin, zoxide)은 새 터미널 창을 열어야 완전히 뜸

# 일부 macOS 설정은 해당 앱을 재시작해야 반영됨
killall Dock
killall Finder
killall SystemUIServer
```

## 코드 품질 (Nix 파일)

```bash
nixfmt modules/shared/packages.nix     # 단일 파일 포매팅
nixfmt .                               # 디렉토리 전체
```

## 저장소 작업 시 잊지 말 것

```bash
# flake는 git에 추적된 파일만 본다. 새 파일을 추가했으면 반드시:
git add <새 파일>
# 안 하면 "Path ... is not tracked by Git" 에러 (06번 문서 0항)
```

## 가장 자주 쓰는 5개 (요약)

```bash
nix build .#darwinConfigurations.aarch64-darwin.system   # 검증
nix run .#build-switch                                    # 적용
nix run .#rollback                                        # 되돌리기
nix flake update                                          # 의존성 갱신
nix search nixpkgs <이름>                                 # 패키지 찾기
```
