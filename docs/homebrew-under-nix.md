# Homebrew와 nix-darwin — 무엇이 핀돼 있고, 무엇을 어디서 올리는가

이 저장소에서 `brew update`는 **아무 일도 하지 않는다.** 에러도 내지 않는다. 그래서 무엇이
대신 그 일을 하고, 올리고 싶을 때 어디를 고쳐야 하는지를 적는다.

핵심은 계층을 가르는 것이다 — brew 본체 / formula·cask **정의** / 실제 **설치본**이 각각
다른 것에 의해 움직인다. 이걸 못 가르면 `brew upgrade`를 쳐 놓고 왜 아무것도 안 올라가는지
모르게 된다. 조용히 실패하기 때문이다.

확인은 aarch64-darwin, Homebrew 6.0.18 기준(2026-08-31).

---

## 세 계층

```
계층              위치                                   가변성   무엇이 움직이나
─────────────────────────────────────────────────────────────────────────────────
brew 본체         /opt/homebrew/bin/brew                 불변    flake.lock
                    → /nix/store/…-brew                          (nix-homebrew → brew-src)

정의(탭)          /opt/homebrew/Library/Taps/…           불변    flake.lock
                    formula·cask 레시피                          (homebrew-core, homebrew-cask, …)

설치본            /opt/homebrew/Cellar                   가변    brew install / brew upgrade
                  /opt/homebrew/Caskroom
```

권한이 그대로 경계다.

```
drwxr-xr-x  root  /opt/homebrew/Library/Taps/homebrew/homebrew-core   ← 읽기 전용
drwxrwxr-x  jh    /opt/homebrew/Cellar                                ← 내 것
```

선언은 두 파일에 있다 — `modules/darwin/brews.nix`(formula), `modules/darwin/casks.nix`(cask 앱).
탭 자체와 brew 본체는 `flake.nix`의 `nix-homebrew` 블록이다.

---

## brew 본체는 자기를 갱신할 수 없다

`/opt/homebrew/bin/brew`는 nix store를 가리키는 심링크이고, 그 스크립트 머리에 이렇게 적혀 있다.

```bash
export HOMEBREW_REPOSITORY="$HOMEBREW_LIBRARY/.homebrew-is-managed-by-nix"

# Homebrew itself cannot self-update, so we set
# fake before/after versions to make `update-report.rb` happy
export HOMEBREW_UPDATE_BEFORE="nix"
export HOMEBREW_UPDATE_AFTER="nix"
```

`HOMEBREW_REPOSITORY`가 실재하지 않는 경로("이건 nix가 관리한다"는 이름 자체)를 가리키고,
갱신 전후 버전은 가짜값으로 고정돼 있다. 그래서 `brew update`는 실패가 아니라 **할 일 없음**으로
끝난다. 탭 쪽도 같다.

```
$ brew --version
Homebrew 6.0.18
Homebrew/homebrew-core (no Git repository)
Homebrew/homebrew-cask (no Git repository)
```

당길 git이 없다. 탭 디렉토리는 그냥 store에서 복사돼 온 파일 더미다.

---

## 핀은 formula 정의까지 내려온다

같은 wrapper의 세 번째 줄이 제일 놓치기 쉽다.

```bash
# Disable API to use pinned homebrew-core
export HOMEBREW_NO_INSTALL_FROM_API=1
```

보통의 Homebrew는 formula/cask 정의를 GitHub의 JSON API에서 그때그때 최신으로 읽는다.
여기서는 그게 꺼져 있고, 디스크의 **핀된 탭**을 읽는다. 결과가 직관과 어긋난다.

- 명령형으로 친 `brew install jq`도 핀된 스냅샷 시점의 jq를 깐다. 최신이 아니다.
- `brew upgrade`는 flake.lock을 올린 **뒤에야** 새 버전을 본다. 그 전엔 올릴 게 없다.
- 스냅샷 시점 이후에 새로 생긴 formula는 아예 못 찾는다.

즉 "brew = 핀 밖의 스크래치 공간"은 절반만 맞다. **설치 여부**는 내 마음대로지만
**버전**은 flake.lock이 정한다.

진짜로 핀 밖에 있는 것:

- 손으로 `brew tap` 한 저장소 — 이건 진짜 git clone이라 `brew update`로 움직인다
  (`mutableTaps = true`라 공존한다)
- 앱이 자기 업데이터로 갱신하는 cask(브라우저, 에디터 등) — 설치만 brew가 했을 뿐이다
- `/Applications`에 드래그한 앱

---

## 갱신 절차 — 순서가 있다

```bash
# 1. 정의를 올린다 (flake.lock 재작성)
nix flake update nix-homebrew homebrew-core homebrew-cask homebrew-bundle \
                 nikitabobko-tap acsandmann-tap

# 2. 검증 — 시스템을 안 건드린다
nix build .#darwinConfigurations.aarch64-darwin.system

# 3. 적용 — 새 brew 본체와 새 탭이 /opt/homebrew에 걸린다
nix run .#build-switch

# 4. 이제서야 설치본을 올린다
brew upgrade
```

**3 없이 4를 치면 아무 일도 일어나지 않는다.** 옛 스냅샷이 그대로 걸려 있으니 brew 입장에서는
전부 최신이다. 여기서 "brew가 고장났나"로 새는 것이 이 문서를 쓴 이유다.

2026-08-31에 실제로 돌린 결과:

| input | 이전 | 이후 |
|---|---|---|
| `nix-homebrew/brew-src` | brew 6.0.12 | brew 6.0.18 |
| `homebrew-core` | 2026-07-31 | 2026-08-30 |
| `homebrew-cask` | 2026-08-04 | 2026-08-30 |

`brew-src`는 `flake.nix`에 없다 — nix-homebrew가 자기 lock으로 물고 있는 transitive input이라
`nix flake update nix-homebrew`에 딸려 온다. 상류 lock보다 더 최신 brew를 쓰려면 태그를 직접
박을 수 있다.

```nix
nix-homebrew = {
  url = "github:zhaofengli-wip/nix-homebrew";
  inputs.brew-src.url = "github:Homebrew/brew/6.0.20";   # 태그 고정
};
```

대신 태그를 박으면 `nix flake update`가 그 줄을 못 움직인다 — 이후 brew 버전은 영원히 손으로
올려야 한다. 상류를 따라가는 편이 기본값으로 낫고, 지금은 그렇게 두었다.

---

## 탭을 하나 더 붙일 때

두 곳을 고친다. `flake.nix`의 `inputs`에 소스를 추가하고,

```nix
someone-tap = {
  url = "github:someone/homebrew-tap";
  flake = false;
};
```

같은 파일 `nix-homebrew.taps`에 등록한다.

```nix
"someone/homebrew-tap" = inputs.someone-tap;
```

**이름이 두 벌인 게 함정이다.** flake 키는 저장소 이름 그대로 `someone/homebrew-tap`이지만,
brew는 `homebrew-` 접두어를 생략해서 `someone/tap`으로 부른다. `brews.nix`/`casks.nix`에는
brew 쪽 철자를 적어야 한다 — 지금 들어 있는 `acsandmann/tap/rift`가 그 예다.

이렇게 선언해 두면 새 기계에서 명령형 `brew tap`이 필요 없다. 아직 계속 쓸지 모르겠으면
그냥 `brew tap`으로 시작하고, 계속 쓰겠다 싶을 때 위로 옮기면 된다.

---

## 증상 → 원인

| 증상 | 원인 |
|---|---|
| `brew update`가 조용히 끝난다 | 정상. 본체·탭이 store라 당길 git이 없다 |
| `brew upgrade`가 아무것도 안 올린다 | flake.lock이 옛 스냅샷. 위 1~3을 먼저 |
| 새로 나온 formula를 못 찾는다 | 탭 스냅샷 시점 이후에 생긴 것. 탭 input 갱신 |
| brew로 깐 것이 최신이 아니다 | `NO_INSTALL_FROM_API=1`. 버전은 flake.lock이 정한다 |
| `Error: An existing /opt/homebrew/Library/Taps is in the way` | 최초 셋업 함정 — [03 문서 3장](03-operating-on-macos.md) |

명령형/선언형을 가르는 기준과 졸업 절차는 [03 문서 5장](03-operating-on-macos.md)에 있다.
