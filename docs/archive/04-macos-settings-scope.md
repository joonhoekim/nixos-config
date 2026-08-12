# 04. macOS 설정을 어디까지 관리할 수 있나

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

관리 가능한 범위의 진짜 경계. "nix-darwin이 구현한 것만"이 아니라 "macOS가 스크립트로 노출한 것 전부"다.

## 먼저, macOS가 설정을 노출하는 방식

macOS의 설정 대부분은 `defaults`라는 시스템에 저장된다.

```bash
defaults write com.apple.dock autohide -bool true
```

System Settings(시스템 설정) 앱에서 토글 하나를 누르면, 내부적으로는 거의 다 이런 `defaults write`로
plist(환경설정 파일)에 기록된다. macOS는 "관리하기 쉽게" 노출하지는 않았지만,
스크립트로 접근 가능한 뒷문은 열어 두었다 — `defaults`, `launchctl`, `nvram`, `/usr/bin/*` 명령들.

nix-darwin이 건드릴 수 있는 노출 통로:

- `defaults`(환경설정) → `system.defaults.*` (로그의 `system defaults...`)
- `/etc` 파일 → `environment.etc`, `system.defaults` (로그의 `setting up /etc...`)
- launchd 서비스 → `launchd.*` (로그의 `setting up launchd...`)
- nvram → `system.nvram.*` (로그의 `setting nvram variables...`)
- 임의 명령 → `system.activationScripts.*`

## 핵심: 두 개의 층이 있다

nix-darwin이 제공하는 것은 두 층이다. 이 구분이 중요하다.

### 층 1 — 타입이 붙은 큐레이션된 옵션 (유한함)

```nix
system.defaults.dock.autohide = true;
system.defaults.finder.FXPreferredViewStyle = "Nlsv";
```

기여자들이 자주 쓰는 설정을 골라 타입·검증을 붙여 손으로 구현한 것.
유한한 목록이라, 이것만 보면 "지원하는 것만 가능"처럼 보인다. 하지만 그게 끝이 아니다.

### 층 2 — 탈출구: `defaults`로 닿는 모든 것

타입 옵션이 없는 설정도 전부 건드릴 수 있다.

```nix
# 타입 옵션이 없는 임의의 domain/key를 직접 write
system.defaults.CustomUserPreferences = {
  "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
  "com.apple.screensaver".tokenRemovalAction = 1;
  NSGlobalDomain.AppleSpacesSwitchOnActivate = false;
};
```

`CustomUserPreferences` / `CustomSystemPreferences`는 "아무 domain, 아무 key나 써라"는 탈출구다.
그것마저 안 되면, 활성화 때 임의 명령을 실행할 수 있다.

```nix
system.activationScripts.postActivation.text = ''
  /usr/bin/defaults write ...
  /usr/bin/some-tool ...
'';
```

따라서 진짜 경계는 "nix-darwin이 구현했는가"가 아니라
"이 설정이 애초에 스크립트/명령으로 닿는가"이다.
`defaults`나 명령줄로 바꿀 수 있는 것이면, 타입 옵션이 없어도 관리할 수 있다.

## 그럼 진짜 못 하는 것은

`defaults`/명령으로 노출되지 않은 영역. 여기가 진짜 천장이다.

- TCC(개인정보) 권한: "전체 디스크 접근", 카메라/마이크 허용 등은 Apple이 일부러 선언적 설정을 막아 둠. GUI에서 직접 클릭해야 한다.
- SIP로 보호된 영역, 일부 보안/커널 설정 (복구 모드에서만 가능).
- GUI 상호작용이 필수인 것 (로그인, iCloud 로그인 등).
- defaults domain이 아예 없는 설정: 명령줄 인터페이스가 없으면 방법이 없다.

추가로 알아둘 점:

- `defaults`로 써도 즉시 반영되지 않고 로그아웃/재시작이나 `killall Dock` 같은 게 필요한 경우가 많다 (로그의 `restarting Dock...`이 그 이유).
- macOS 버전이 올라가면 key 이름이 바뀌어 깨지기도 한다. (자세한 내용은 05번 문서 참고.)

## 실전: 모르는 설정의 key를 직접 찾는 법

타입 옵션에 없는 설정을 관리하고 싶을 때의 발굴 절차.

```bash
# 1) 바꾸기 전 상태 저장
defaults read > /tmp/before.txt

# 2) System Settings에서 원하는 토글을 GUI로 바꾼다

# 3) 무엇이 달라졌는지 비교 → 바뀐 domain/key가 보인다
defaults read > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt
```

여기서 나온 domain/key/값을 위의 `CustomUserPreferences`에 그대로 옮겨 적으면,
타입 옵션이 없어도 선언적으로 관리할 수 있다.

## 한 줄 요약

관리 가능한 범위 = macOS가 스크립트로 노출한 표면 전체
(대략 `defaults`로 닿는 거의 모든 환경설정 + launchd + nvram + 임의 명령).
nix-darwin이 구현한 타입 옵션은 그중 자주 쓰는 것을 편하게 감싼 부분집합일 뿐이고,
`CustomUserPreferences`·`activationScripts`라는 탈출구로 나머지 노출부에도 닿을 수 있다.
진짜 한계는 "기여자가 안 만들어서"가 아니라 "Apple이 애초에 스크립트로 안 열어놔서"인 경우다.
