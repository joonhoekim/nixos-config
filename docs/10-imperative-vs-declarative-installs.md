# 10. 명령형 설치 vs 선언형 설치 (그리고 졸업 절차)

"굳이 nix로 빌드 안 하고 그냥 깔아서 써보는" 경우를 Nix 시스템에서 어떻게 다루는가.
핵심 패턴: 일단 명령형(imperative)으로 깔아 써보고, 마음에 들면 나중에 nix(선언형)로 옮긴다.
모든 것을 처음부터 선언할 필요는 없다.

## 왜 공존이 가능한가

nix-darwin은 "당신이 선언한 것"만 관리하고, 나머지 영역은 소유하지 않는다.

- `/Applications`에 드래그한 앱 → nix가 건드리지 않음
- Homebrew → 이 저장소는 `mutableTaps = true` + cleanup 꺼짐 → 수동 `brew install`이 그대로 살아있음
- `~/.npm-packages`, `~/.cargo` 같은 홈 디렉토리 → nix 영역 밖

그래서 명령형 설치와 선언형 설정이 충돌 없이 공존한다. nix가 수동 설치물을 지우지 않는다.

## "지금 깔기"의 통로 (가벼운 것 → 영구적인 것)

### 1. 그냥 한 번 써보기 (설치 안 함)

```bash
nix shell nixpkgs#ripgrep      # 임시 셸에만 추가, 닫으면 사라짐
nix run nixpkgs#ripgrep        # 설치 없이 1회 실행
```

### 2. Nix 네이티브 명령형 설치 — `nix profile`

flake를 고치지 않고 내 유저 프로필에 즉시 설치한다. `apt install`의 nix 버전이라 보면 된다.

```bash
nix profile install nixpkgs#ripgrep
nix profile list                       # 무엇을 깔았나
nix profile remove ripgrep             # 제거
nix profile upgrade --all              # 갱신
```

store 기반이라 격리·롤백은 여전히 되지만, flake 바깥의 가변 상태다.

### 3. Homebrew 수동 설치 (GUI 앱 / 포뮬러)

```bash
brew install <formula>
brew install --cask <app>
```

`mutableTaps = true`라 자유롭게 된다. macOS GUI 앱의 주된 "지금 깔기" 경로.

### 4. 언어 생태계 매니저 (홈에 설치)

```bash
npm i -g <pkg>      # → ~/.npm-packages (이 저장소 zshrc가 이미 PATH에 추가해둠)
cargo install <pkg> # → ~/.cargo
uv tool install ... / pipx install ...
```

대부분 그냥 명령형으로 두고 nix로 옮기지 않는다. 모든 것을 선언할 필요는 없다.

## 졸업 절차: 명령형 → 선언형

마음에 들어서 영구적이고 재현 가능하게 만들고 싶을 때.

1. 적절한 파일에 추가 — CLI면 `modules/shared/packages.nix`, GUI면 `modules/darwin/casks.nix`
2. `nix run .#build-switch`
3. 명령형 사본 제거 (`nix profile remove` 또는 `brew uninstall`) — 안 그러면 두 벌이 깔려 PATH 순서로 충돌

## 두 모드를 가르는 기준

- 선언형(flake 안) = 진실의 원천. 재현 가능, 핀 고정, 새 기계에서 그대로 재현됨.
- 명령형(brew / profile / npm / 수동) = 스크래치 공간. 빠르게 시도, 일회성, 재현 불필요한 것.

주의할 점:

- 명령형 설치물은 새 기계에서 flake로 살아나지 않는다(재현성 없음). 버전 핀도 없어 드리프트할 수 있다.
- "여러 기계에서 똑같이" 원하면 졸업시키고, "이 기계에서만 잠깐"이면 명령형으로 둔다.
- 같은 도구를 nix와 brew(또는 npm) 양쪽에 깔면 두 벌이 되어 PATH 순서가 승자를 정한다. 졸업 후엔 한쪽을 정리한다.

비유: flake는 이사할 때 들고 갈 짐 목록, 명령형 설치는 지금 책상에 늘어놓은 물건들.
쓸 만하면 목록에 적고, 아니면 그냥 책상에 둔다.

## 관련 문서

- 패키지를 어디(shared/darwin)에 추가하는지: 02번 문서의 "무엇을 어디서 고치나"
- 자주 업데이트되는 GUI 앱을 cask로 두는 이유(자가 업데이트 vs 재현성): 09번 치트시트의 Homebrew 항목 및 대화 메모
- 임시 사용/탐색 명령: 09번 치트시트의 "패키지 탐색 / 임시 사용"
