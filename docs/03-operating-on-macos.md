# 03. macOS 관리와 운영

Mac에서 이 저장소를 실제로 굴릴 때 필요한 전부: 무엇까지 선언적으로 관리할 수 있고
그 한계는 어디인지, defaults가 왜 취약한지, 최초 셋업의 함정, 일상 명령어,
그리고 명령형 설치를 선언형으로 졸업시키는 절차.

---

## 1. macOS 설정을 어디까지 관리할 수 있나

진짜 경계는 "nix-darwin이 구현한 것"이 아니라 **"macOS가 스크립트로 노출한 것 전부"**다.

### macOS가 설정을 노출하는 방식

설정 대부분은 `defaults` 시스템에 저장된다(`defaults write com.apple.dock autohide -bool true`).
System Settings에서 토글을 누르면 내부적으로 거의 다 이런 `defaults write`로 plist에 기록된다.
macOS는 "쉽게" 노출하진 않았지만 스크립트 뒷문은 열어 뒀다 — `defaults`, `launchctl`, `nvram`,
`/usr/bin/*`. nix-darwin이 건드리는 통로:

- `defaults` → `system.defaults.*` · `/etc` → `environment.etc` · launchd → `launchd.*`
- nvram → `system.nvram.*` · 임의 명령 → `system.activationScripts.*`

### 두 개의 층

- **층 1 — 타입 붙은 큐레이션 옵션(유한).** `system.defaults.dock.autohide = true` 처럼 자주 쓰는
  설정을 골라 타입·검증을 붙인 것. 유한해서 "지원하는 것만 가능"처럼 보이지만 그게 끝이 아니다.
- **층 2 — 탈출구: `defaults`로 닿는 모든 것.** 타입 옵션이 없어도 임의 domain/key를 쓸 수 있다.

  ```nix
  system.defaults.CustomUserPreferences = {
    "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
    NSGlobalDomain.AppleSpacesSwitchOnActivate = false;
  };
  # 그것마저 안 되면 활성화 때 임의 명령:
  system.activationScripts.postActivation.text = '' /usr/bin/defaults write ... '';
  ```

따라서 진짜 경계는 "nix-darwin이 구현했는가"가 아니라 "이 설정이 애초에 스크립트/명령으로 닿는가"다.

### 그럼 진짜 못 하는 것

`defaults`/명령으로 노출되지 않은 영역(진짜 천장):

- TCC(개인정보) 권한: 전체 디스크 접근, 카메라/마이크 등 — Apple이 선언 설정을 일부러 막음. GUI 필수.
- SIP 보호 영역, 일부 보안/커널 설정(복구 모드에서만).
- GUI 상호작용 필수(로그인, iCloud 로그인 등).
- defaults domain이 아예 없는 설정.

추가로, `defaults`로 써도 즉시 반영 안 되고 로그아웃/재시작이나 `killall Dock`이 필요한 경우가 많다.

### TCC는 못 하지만, 그 비용을 1회로 줄일 수는 있다

TCC 허가를 **주는 것**은 위에 적은 대로 GUI로만 된다. 그건 안 바뀐다. 하지만 그 GUI 비용을
**몇 번 치르는가**는 우리가 정할 수 있고, 명령형으로 빌드하는 `.app`에서는 이게 꽤 큰 차이다.

TCC는 허가를 앱의 **지정 요구사항**에 묶어 저장한다. 임의 서명(`codesign -s -`)한 앱은 인증서가
없으므로 요구사항이 이렇게 된다:

```
designated => cdhash H"6d3a31a07290c00701e45474884eb5b0138c2657"
```

곧 **바이너리가 한 바이트만 달라져도 허가가 안 맞는다.** 손으로 빌드하는 앱은 고칠 때마다 다시
빌드하므로, 재빌드마다 권한이 끊긴다.

제일 고약한 것은 이때 macOS가 **다시 묻지 않는다**는 점이다. TCC 항목 자체는 남아 있어서 System
Settings의 체크박스는 켜진 채이고, 앱만 거절당한다. 그래서 증상이 "권한은 분명히 켜 뒀는데 그냥
안 된다"가 된다. 추측하지 말고 로그를 본다:

```bash
log show --last 10m --predicate 'process == "tccd"' --style compact | grep -i <앱이름>
#   Failed to match existing code requirement for subject
#   dev.jh.global-shader and service kTCCServiceScreenCapture
```

**고정된 인증서로 서명하면** 요구사항에서 cdhash가 빠진다:

```
designated => identifier "dev.jh.global-shader" and certificate leaf = H"5a9ec361…"
```

인증서는 그대로 있으므로 몇 번을 다시 빌드해도 같은 요구사항이고, 허가는 **기계당 한 번**이면
된다. 실측(2026-08-09, global-shader):

| | 값 |
|---|---|
| cdhash | `fef47451…` → `1f33c032…` (바뀜) |
| 지정 요구사항 | `identifier … certificate leaf = H"5a9ec361…"` (그대로) |
| 결과 | 재승인 없이 화면 기록 통과 |

```bash
apps/mac-signing-cert                                    # 기계당 한 번
apps/mac-signing-cert sign /Applications/Foo.app         # 남이 서명한 앱을 갈아 끼울 때
```

**왜 선언형이 아닌가.** 인증서에는 개인키가 딸린다. `/nix/store`는 월드 리더블이라 넣을 수 없고,
넣어서 여러 기계가 같은 키를 쓰게 만드는 것은 더 나쁘다. 그래서 절차만 이 레포가 갖고 산출물은
기계마다 따로다 — §5의 "여러 기계에서 똑같이면 졸업"에서 졸업하는 쪽은 **절차**다. `home.activation`
에도 넣지 않는다: 키체인 항목 생성은 GUI 인증 창을 띄우므로, 매 rebuild마다 도는 activation에
끼우면 `build-switch`가 암호 창 앞에서 멈춰 선다.

**함정 하나.** 번들 안 실행 파일을 셸에서 직접 돌리면(`./build/foo`) 잘 되는 것처럼 보인다. 그건
앱이 권한을 가져서가 아니라 **부모 프로세스(터미널)의 권한을 빌려 쓰는 것**이다. `open`이나 Finder,
launchd로 띄웠을 때와 결과가 다르면 거의 항상 이것이다.

이 인증서는 Apple이 보증하지 않으므로 배포용이 아니다. 목적은 내 기계에서 TCC 허가가 재빌드를
견디게 하는 것 하나다.

### 실전: 모르는 설정의 key 찾기

```bash
defaults read > /tmp/before.txt      # 1) 바꾸기 전 상태
# 2) System Settings에서 GUI로 토글
defaults read > /tmp/after.txt       # 3) 비교 → 바뀐 domain/key
diff /tmp/before.txt /tmp/after.txt
```

나온 domain/key/값을 `CustomUserPreferences`에 옮겨 적으면 타입 옵션 없이도 선언 관리된다.

---

## 2. macOS defaults의 취약성

Apple은 macOS를 마음대로 바꿀 수 있다 — 스크립트 해석을 바꾸거나 노출 경로를 막을 수도 있다.
**결론: 빈도 "높음", 깊이 "보통"(전면 폐기는 아직 없음).** 깨짐은 두 종류:

- **(A) key 표류** — 개별 key가 개명/삭제/무력화. 빈도 잦음(거의 매년), 깊이 얕음. 토글 하나가 조용히 안 먹음.
- **(B) 메커니즘 변경** — `defaults`/plist 동작 방식 자체가 바뀜. 빈도 드묾(몇 년에 한 번), 깊이 깊음.

역사적 랜드마크:

- **2018 Mojave** — 가장 깊은 메커니즘 변경. `cfprefsd`가 환경설정을 메모리 캐싱하면서
  `defaults write`로 직접 바꿔도 옛 값으로 덮어써지는 일이 생김. "파일에 쓰면 적용된다"는 전제가 흔들림.
- **2022 Ventura** — System Settings 전면 재작성으로 수많은 key가 제거·이동. AppleScript 자동화가
  대량으로 깨짐. nix-darwin도 "재부팅 후 `/run/current-system`이 사라지는" 버그를 겪음.
- **2024~ Sonoma/Sequoia** — 스크린세이버·다중 유저 적용·일부 trackpad가 "적용됐다는데 안 먹는" 표류 지속.
- **상시** — 많은 설정이 로그아웃/재시작이나 `killall Dock` 전엔 반영 안 됨(cfprefsd 캐싱 부작용).

**왜 전면 폐기는 안 일어나나:** Apple 자신이 이 기반에 의존한다(System Settings·MDM·Configuration
Profile 전부 cfprefsd/plist 위). 없애면 자기 OS가 부서진다 — 그래서 10.9(2013)부터 살아남았다.
대신 Apple은 권장 경로를 따로 민다 — `defaults write`(비공식)가 아니라 Configuration
Profile/MDM(공식, 잠금 가능). 핵심: `defaults`는 Apple이 "안정 API"라고 약속한 적 없는 반(半)비공식 표면.

실전적 함의:

- 매 메이저 OS 업그레이드 후 일부 `system.defaults`가 조용히 안 먹을 수 있다(에러도 없이). 직후엔 눈으로 확인.
- nix-darwin만의 문제가 아니라 `defaults`를 쓰는 모든 도구의 공통 리스크. 오히려 커뮤니티가 빠르게 패치해 안전망이 있다.
- 절대 안 바뀌어야 할 설정(보안 정책)은 `system.defaults`보다 Configuration Profile이 견고(Apple 공식).
- 패키지(`/nix/store`)·CLI·홈브루·dotfile은 이 리스크와 무관. 흔들리는 건 `system.defaults`뿐.

출처: [eclecticlight — Mojave preferences](https://eclecticlight.co/2019/08/22/working-safely-and-effectively-with-preferences-in-mojave/) ·
[How Preferences work](https://eclecticlight.co/2023/07/28/how-preferences-do-and-dont-work/) ·
[nix-darwin #1207](https://github.com/nix-darwin/nix-darwin/issues/1207) ·
[#1148](https://github.com/nix-darwin/nix-darwin/issues/1148) ·
[Configuration Profiles](https://gordonbeeming.com/blog/2025-11-22/locking-down-macos-settings-the-real-way)

---

## 3. 최초 셋업에서 겪는 함정들

이미 손으로 세팅된 Mac 위에 선언적 관리를 처음 덮을 때 겪는 **1회성** 충돌들. "Nix가 어렵다"기보다
"기존 수동 환경과 선언적 환경의 첫 만남"에서 온다. 한 번 자리 잡으면 이후엔 파일 수정 → `build-switch`뿐.

**0. flake는 git 추적 파일만 본다.** `error: Path '...karabiner.json' ... is not tracked by Git` →
새 파일을 만들고 모듈에서 참조했으면 `git add <파일>`. "그런 파일 없다"류 에러가 나면 가장 먼저 의심.

**1. nixpkgs-unstable 패키지 표류.** `nixos-unstable` 채널이라 개명/제거/별칭통합/소스빌드 실패를 만난다
(`'du-dust' renamed to 'dust'` 등). 에러가 보통 대체 이름을 알려준다. 무엇이 문제인지 모르면:

```bash
nix build .#darwinConfigurations.aarch64-darwin.system --dry-run   # 새로 빌드되는 것 미리 보기
nix-store -l /nix/store/<...>.drv                                  # 실패 derivation 전체 로그
```

습관: 활성화 전 `nix build`로 먼저 통과를 확인하면 sudo·시스템 변경 없이 안전하게 잡는다.

**2. `/etc` 파일이 가로막음(최초 활성화).** `error: Unexpected files in /etc, aborting activation`
(`/etc/nix/nix.conf`, `/etc/bashrc`, `/etc/zshrc`). 기존 파일을 덮으면 뭔가 잃을까 봐 멈춘 안전장치.

```bash
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin
nix run .#build-switch
```

백업이라 안전(되돌리려면 `.before-nix-darwin`을 떼고 원래 이름으로 mv).

**3. `nix-command`/flakes가 갑자기 비활성.** `error: experimental Nix feature 'nix-command' is disabled`.
원인: 2번에서 옮긴 `/etc/nix/nix.conf`에 `experimental-features`가 들어 있었던 것. 이번 한 번만 직접 켜서 부트스트랩:

```bash
nix --extra-experimental-features 'nix-command flakes' run .#build-switch
```

활성화가 끝나면 `/etc/nix/nix.conf`가 재생성돼 다음부터는 그냥 `nix run .#build-switch`.

**4. Homebrew Taps가 가로막음.** `Error: An existing /opt/homebrew/Library/Taps is in the way`.
원인: `mutableTaps = false`(tap은 선언한 것만 허용, 폴더 잠금)인데 이미 수동 커스텀 tap(예: aerospace의
`nikitabobko/tap`)이 있어 충돌. 수동 brew·커스텀 tap을 쓰는 사람이면 `flake.nix`의 nix-homebrew에서
`mutableTaps = true`로. 선언한 casks는 계속 관리하되 수동 `brew`도 허용된다.
(이 레포는 이미 그렇게 돼 있다 — 새로 겪는다면 값이 되돌아갔는지부터 볼 것.)

**5. home-manager가 기존 dotfile을 못 덮음.** `Existing file '~/.zshrc' would be clobbered` 등.
`modules/darwin/home-manager.nix`에서 자동 백업 켜기 (이미 켜져 있다 — 진단용으로 적어 둔다):

```nix
home-manager.backupFileExtension = "backup";   # 기존 파일을 <name>.backup 으로 옮긴 뒤 관리
```

재실행하면 `~/.zshrc` 등이 `~/.zshrc.backup`으로 옮겨지고 hm 버전이 자리잡는다. 내용이 같은 파일은
"skipped since they are the same"으로 건너뛴다(충돌 아님). 주의: `.backup`이 이미 있으면 또 에러 — 지우고 재시도.

**적용 후 확인:** 새 zsh 설정(p10k·atuin·zoxide)은 새 터미널 창을 열어야 완전히 뜬다. 일부 macOS 설정은 로그아웃/재시작 후 반영.

**큰 그림:** `/etc` 백업·`nix-command disabled`·Taps·dotfile clobber는 전부 최초 1회 통과의례.
넘기면 파일 수정 → `build-switch` 루프만 남고, 활성화 전 `nix build` 검증이 가장 큰 안전망이다.

---

## 4. 자주 쓰는 명령어 치트시트

아키텍처는 `aarch64-darwin` 기준(다른 Mac이면 그 자리를 해당 system으로).

```bash
# ── 일상 워크플로 ──
nix run .#build-switch                                   # 빌드 + 활성화 (가장 자주). sudo 암호
nix build .#darwinConfigurations.aarch64-darwin.system  # 활성화 없이 빌드만 — 안전 검증
nix run .#build                                          # 빌드만 하는 저장소 앱(위의 래퍼)

# ── 롤백 / generation ──
nix run .#rollback                          # 직전으로 (저장소 앱)
darwin-rebuild --list-generations           # 목록
darwin-rebuild --rollback                   # 직전
darwin-rebuild --switch-generation 42       # 특정 번호

# ── flake / 의존성 갱신 ──
nix flake update [nixpkgs]    # 전체(또는 특정 input) 갱신, flake.lock 재작성 → 커밋 필요
nix flake show               # 출력 트리
nix flake metadata           # input·lock 상태

# ── 탐색 / 임시 사용(설치 없이) ──
nix search nixpkgs ripgrep         # 검색
nix shell nixpkgs#ripgrep          # 임시로 현재 셸에 추가(닫으면 사라짐)
nix run nixpkgs#ripgrep -- --help  # 1회 실행

# ── 진단 / 디버깅 ──
nix build .#...system --dry-run     # 새로 빌드되는 것(캐시에 없는 것) 미리
nix build .#...system --show-trace  # 모호한 에러의 평가 추적
nix log /nix/store/xxxx.drv         # 실패 derivation 로그 (안 되면 nix-store -l)
nix why-depends .#...system nixpkgs#<pkg>   # 왜 이 패키지가 들어왔나

# ── Homebrew (이 저장소는 mutableTaps = true) ──
brew install <formula> ; brew tap <user>/<repo> ; brew list ; brew update && brew upgrade

# ── 정리 / 디스크 회수(GC) ──
nix-collect-garbage -d        # 유저 프로필 오래된 generation
sudo nix-collect-garbage -d   # 시스템 프로필까지
nix run .#clean               # 저장소 정리 앱
# (이 저장소는 hosts/darwin에서 주간 자동 GC: 30일 이상 삭제)

# ── 적용 후 반영 ──
killall Dock ; killall Finder ; killall SystemUIServer   # 일부 macOS 설정 반영

# ── Nix 파일 포매팅 ──
nixfmt modules/shared/packages.nix   # 또는 nixfmt .

# ── 잊지 말 것 ──
git add <새 파일>   # flake는 git 추적 파일만 본다(안 하면 "not tracked by Git")
```

가장 자주 쓰는 5개: `nix build .#...system`(검증) · `nix run .#build-switch`(적용) ·
`nix run .#rollback`(되돌리기) · `nix flake update`(갱신) · `nix search nixpkgs <이름>`(찾기).

원칙: 고치면 먼저 `nix build`로 통과 확인 후 `build-switch`. `build`는 시스템을 안 건드려 안전.

---

## 5. 명령형 설치 vs 선언형 설치 (그리고 졸업)

"굳이 nix로 빌드 안 하고 그냥 깔아서 써보는" 경우. **핵심 패턴: 일단 명령형으로 깔아 써보고,
마음에 들면 나중에 nix(선언형)로 옮긴다.** 모든 것을 처음부터 선언할 필요는 없다.

**왜 공존 가능한가:** nix-darwin은 "당신이 선언한 것"만 관리하고 나머지는 소유하지 않는다.
`/Applications` 드래그 앱, 수동 `brew install`(이 저장소는 `mutableTaps = true` + cleanup 꺼짐),
`~/.npm-packages`·`~/.cargo` 등은 nix 영역 밖이라 충돌 없이 공존한다.

"지금 깔기"의 통로(가벼운 것 → 영구적인 것):

```bash
# 1. 한 번 써보기(설치 X)
nix shell nixpkgs#ripgrep      # 임시 셸에만, 닫으면 사라짐
nix run nixpkgs#ripgrep        # 1회 실행

# 2. Nix 네이티브 명령형 — nix profile (apt install의 nix 버전. flake 바깥 가변 상태)
nix profile install nixpkgs#ripgrep ; nix profile list ; nix profile remove ripgrep

# 3. Homebrew 수동 (GUI 앱의 주된 "지금 깔기" 경로)
brew install <formula> ; brew install --cask <app>

# 4. 언어 생태계 매니저 (홈에 설치, 대부분 그냥 명령형으로 둠)
npm i -g <pkg>   # → ~/.npm-packages (zshrc가 이미 PATH에 추가)
cargo install <pkg>   # → ~/.cargo
```

**졸업 절차(명령형 → 선언형):** 영구·재현 가능하게 만들고 싶을 때.

1. 적절한 파일에 추가 — CLI면 `modules/shared/packages.nix`, GUI면 `modules/darwin/casks.nix`
2. `nix run .#build-switch`
3. 명령형 사본 제거(`nix profile remove` 또는 `brew uninstall`) — 안 하면 두 벌이 깔려 PATH 순서로 충돌

**가르는 기준:** 선언형(flake 안) = 진실의 원천(재현·핀 고정·새 기계 재현). 명령형(brew/profile/npm)
= 스크래치 공간(빠른 시도·일회성). "여러 기계에서 똑같이"면 졸업, "이 기계에서만 잠깐"이면 명령형.
비유: flake는 이사 짐 목록, 명령형은 지금 책상에 늘어놓은 물건. 쓸 만하면 목록에 적고 아니면 책상에 둔다.
