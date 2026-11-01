# 맨 땅에서 첫 로그인까지 — macOS 설치와 제거

macOS 를 막 설치한 Mac 에 이 레포를 얹는 절차와, 그걸 다시 걷어 내는 절차. NixOS 쪽은
[clean-install.md](clean-install.md) 다. 일상 운용(리빌드, 롤백)은 [README](../README.md),
macOS 설정이 왜 이렇게 생겼는지는 [03-operating-on-macos.md](03-operating-on-macos.md).

이 문서의 기준은 **공식 설치기 + CppNix** 다(`local.nix.implementation = "cppnix"`,
`modules/shared/nix-implementation.nix`). 다른 설치기로 깔아도 동작은 한다 — 아래
"다른 설치기로 깔았을 때" 를 볼 것.

---

## 설치

### 1. macOS 첫 설정

- 계정 이름은 `users/<이름>.nix` 의 이름과 같게 만든다. 다르면 activation 이 계정을 하나
  **더** 만든다(`apps/setup` 이 이 경우를 묻는다).
- 시스템 설정 > 일반 > 공유 의 "로컬 호스트 이름" 이 `hosts/darwin/<이름>/` 이 된다.
  전용 디렉토리가 없으면 공용 설정(`aarch64-darwin`)을 쓴다.

### 2. Command Line Tools

```bash
xcode-select --install
```

git 과 Homebrew 가 요구한다. 처음 `git` 을 칠 때 macOS 가 같은 설치 창을 띄우기도 한다.
Xcode 전체는 필요 없다 — iOS 를 빌드하는 호스트만 `ios` 묶음으로 받는다
(`modules/darwin/ios.nix`).

### 3. Nix (공식 설치기)

```bash
curl -L https://nixos.org/nix/install | sh
```

macOS 에서는 다중 사용자(데몬) 설치가 기본이다. 하는 일: `Nix Store` APFS 볼륨,
`/etc/synthetic.conf`·`/etc/fstab` 항목, `nixbld` 그룹과 `_nixbld*` 사용자,
`org.nixos.nix-daemon` LaunchDaemon, 그리고 `/etc/zshrc`·`/etc/bashrc`·`/etc/bash.bashrc` 에
훅을 넣고 원본을 `*.backup-before-nix` 로 남긴다. 제거 도구는 없다 — 그래서 아래 제거 절이 있다.

새 터미널을 열고 `nix --version` 이 `nix (Nix) …` 인지 본다.

### 4. 레포와 비공개 input

레포와 `subline`·`subline-terminal` input 이 비공개라 GitHub 로그인이 먼저다. gh 는 아직 없으니
nixpkgs 에서 빌려 쓴다. 왜 이 모양인지는 [github-auth.md](github-auth.md).

```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#gh   # 6 까지 이 셸 안에서
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.https://github.com.helper GIT_CONFIG_VALUE_0='!gh auth git-credential'
gh auth login                                          # 이미 했다면 건너뛴다
gh repo clone joonhoekim/nixos-config ~/nixos-config
cd ~/nixos-config
```

### 5. 호스트 붙이기

```bash
./apps/setup     # users/<이름>.nix, hosts/darwin/<hostname>/ 를 만들고 git add
./apps/doctor    # hostname · 계정 · 추적 안 된 파일
```

### 6. 첫 switch

4 에서 연 셸 안에서:

```bash
./apps/build-switch
```

- flakes 는 이번 한 번만 플래그로 켠다. switch 뒤로는 nix-darwin 의 `/etc/nix/nix.conf` 가 켠다.
- 4 의 셸 밖에서 돌리면 비공개 input 앞에서 `could not read Username` 으로 멈춘다. git 이 gh 에
  인증을 묻는 설정은 첫 switch 가 만든다. switch 뒤로는 레포의 gh 와 git 설정이 그 일을 한다.
- `/etc` 의 파일이 가로막으면(`Unexpected files in /etc`) 그 파일을 `.before-nix-darwin` 으로
  옮기고 다시 — [03 §3](03-operating-on-macos.md) 의 2·3 번. 공식 설치기는 `/etc/nix/nix.conf`,
  `/etc/bashrc`, `/etc/zshrc` 를 남긴다.
- **두 번 돌린다.** 첫 번째에는 mise 가 rust 를 까는 중이라 rift-grid·subline-terminal 이
  "cargo 가 없어 건너뛴다" 로 넘어갈 수 있다.
- 끝에서 `apps/check/pending` 이 사람이 할 단계를 보인다. 아래 7 이 그 목록이다.

### 7. 사람이 해야 하는 단계 (TCC · 드라이버)

macOS 가 클릭을 요구해서 레포가 대신할 수 없다. activation 은 이 앞에서 멈추지 않고 성공으로
끝나고, 해당 데몬은 조용히 재시작을 반복한다.

| 순서 | 대상 | 할 일 | 설정 화면 (macOS 27 영어 표기) | 확인 |
|---|---|---|---|---|
| 1 | Karabiner VirtualHIDDevice | 드라이버 확장 승인 | General > Login Items & Extensions > (아래로) Extensions > Driver Extensions | `systemextensionsctl list` 가 `[activated enabled]` |
| 2 | `/usr/local/libexec/kanata/kanata` | **두 목록 모두** 켜기 (목록에 없으면 `+` → `⌘⇧G` 로 경로) | Privacy & Security > Input Monitoring, Privacy & Security > Device Control and Data Access | `sudo launchctl kickstart -k system/org.nixos.kanata` 뒤 `/var/log/kanata.log` 에 오류가 없다 |
| 3 | `~/.local/bin/rift-grid` | 두 목록 켜기 | Privacy & Security > Device Control and Data Access, Privacy & Security > Screen & System Audio Recording | `nix run .#check` 의 rift-grid 절 |
| 4 | LinearMouse (cask 가 있는 호스트만) | 켜기 | Privacy & Security > Input Monitoring | 외장 마우스 휠 방향 |

- **Device Control and Data Access** 는 macOS 26 까지의 **Accessibility** 다. 키는 그대로
  `ACCESSIBILITY` 이고 표시 이름만 바뀌었다(SecurityPrivacyExtension.appex 의
  `Localizable.loctable`, macOS 27.0.1. 한국어 표기는 "기기 제어 및 데이터 접근"). 사이드바 최상위의
  **Accessibility** 는 VoiceOver 같은 보조 기능 설정이라 다른 화면이다.
- kanata 는 모자란 권한을 한 번에 하나씩만 로그에 적는다 — Input Monitoring 을 주면 다음
  실행에서야 Accessibility 를 요구한다. 그래서 2 는 처음부터 둘 다 켠다.
- Driver Extensions 경로는 `systemextensionsctl list` 가 스스로 출력하는 안내와 같다.
- `apps/check/pending --open` 이 남은 단계의 화면을 차례로 띄우고, 토글이 켜질 때까지 기다렸다가
  다음으로 넘어간다(아래 "pending 이 쓰는 URL 과 판정"). Login Items & Extensions 는 페이지 맨 위로
  열리므로 Extensions 까지는 스크롤한다.

1 이 2 보다 먼저다. 드라이버가 없으면 kanata 는 권한이 있어도 키를 내보낼 곳이 없다.
kanata·rift-grid 는 이 기계의 서명 신원(`apps/mac-signing-cert`)으로 서명되므로 허가는
기계당 한 번이다 — 판이 바뀌어도 다시 묻지 않는다. kanata 배선 전체는
[macos-internals.md](macos-internals.md#kanata-배선-modulesdarwinkanatanix).

#### pending 이 쓰는 URL 과 판정 (`apps/check/pending`)

`--open` 이 여는 URL 은 macOS 27.0.1 에서 `open` 한 뒤 화면을 찍어 확인한 것만 둔다(2026-10-31):

| URL | 열리는 화면 |
|---|---|
| `…preference.security?Privacy_ListenEvent` | Input Monitoring |
| `…preference.security?Privacy_Accessibility` | Device Control and Data Access |
| `…preference.security?Privacy_ScreenCapture` | Screen & System Audio Recording |
| `…LoginItems-Settings.extension?ExtensionItems` | Login Items 의 맨 위. Extensions 까지 내려가지 않으므로 거기서 스크롤한다 |

화면 이름의 출처는 `/System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex` 의
`Localizable.loctable` 이다. 식별자는 판마다 바뀔 수 있다. 엉뚱한 화면이 뜨면 그 바이너리를
`strings | grep '^Privacy_'` 로 다시 보고, 같은 방법(열고 화면 확인)으로 확인한 뒤 고친다.

kanata 상태 판정(kanata 1.12, macOS 27 실측): kanata 는 권한이 없어도 "starting" → "entering the event
loop" 를 지나 약 2 초 떠 있다가 오류로 끝나고, KeepAlive 가 10 초마다 다시 띄운다. 그래서 launchd 의
state = running 만으로는 승인됐다고 보지 않고, 이번 실행이 5 초 넘게 오류 없이 떠 있어야 ok 다(아니면
--open 이 아무것도 승인되지 않은 채 끝난다). --open 은 3 초마다 상태를 다시 읽고, 토글이 켜지면 다음
화면으로 넘어가며, Ctrl-C 로 그만둔다.

### 8. 로그아웃 · 다시 로그인

"Displays have separate Spaces" 와 LaunchServices 의 기본 앱 캐시는 로그인 때 읽힌다
(`hosts/darwin/common.nix`, `modules/darwin/default-apps.nix`).

### 9. 확인

```bash
nix run .#check        # 깨진 것 0 개
```

Nix 절의 "nix 한 벌: 셸·시스템·데몬 모두 …" 가 셋이 같은 판인지 본다.

### 다른 설치기로 깔았을 때

Lix·Determinate 설치기로 깔아도 nix-darwin 이 데몬을 `nix.package`(CppNix)로 바꾸고, 셸도
`/run/current-system/sw/bin/nix` 를 집는다([nix-implementation.md](nix-implementation.md#셸이-설치기의-nix-daemonsh-를-source-하지-않는-이유)). 남는 차이는
설치기 쪽뿐이다: 기본 프로필에 그 설치기의 nix 가 있고, 제거가 그 설치기의 `uninstall` 로
간다.

Determinate 설치기로 Determinate Nix 를 깔았다면 nix-darwin 이 `nix.enable = false` 를 요구해서
이 레포의 `nix.settings`·`nix.gc` 가 먹지 않는다. 이 레포가 그 구성을 지원하지 않는 이유는
docs/nix-implementation.md.

---

## 제거

```bash
/bin/sh ~/nixos-config/apps/uninstall            # 계획만
/bin/sh ~/nixos-config/apps/uninstall --run      # 다시 깔 때
/bin/sh ~/nixos-config/apps/uninstall --run --purge   # 이 Mac 에서 손을 뗄 때
```

계획 모드는 이 기계에 실제로 있는 것만 단계로 보이고 아무것도 바꾸지 않는다. `--run` 은
단계마다 묻고, 실패하면 그 자리에서 멈춘다(다시 돌리면 끝난 단계는 "없다" 로 건너뛴다).

### 먼저: 스토어 밖의 셸에서

로그인 셸이 nix 의 bash(`/run/current-system/sw/bin/bash`)인 채로는 `/nix` 볼륨을 쓰는
프로세스가 남아서 언마운트에서 멈춘다. `--run` 은 그 상태를 거절한다.

```bash
sudo dscl . -create /Users/$USER UserShell /bin/zsh
# 터미널 앱을 완전히 끄고 /System/Applications/Utilities/Terminal.app 을 새로 연다
```

subline-terminal 은 스토어 밖 바이너리지만, 그 안의 셸이 로그인 셸이라 같은 문제가 있다.

### 단계와 순서

| # | 층 | 무엇을 | 왜 이 자리인가 |
|---|---|---|---|
| p1 | brew cask | `brew uninstall --cask` 전부 | brew 가 nix-homebrew 의 스토어 링크라 Nix 를 지운 뒤에는 못 부른다 |
| p2 | Homebrew | `/opt/homebrew` | 같은 이유 |
| p3 | 드라이버 | Manager `deactivate`, `.Karabiner-VirtualHIDDevice-Manager.app` | |
| p4 | kanata | `/usr/local/libexec/kanata/`, 로그 | |
| p5 | nix 밖 빌드 | `~/.local/bin` 의 rift-grid·subline-terminal, `~/Applications/subline-terminal.app` | 소스(`~/git`)는 남긴다 |
| p6 | 서명 신원 | `apps/mac-signing-cert --remove` | 지우면 그 신원에 묶인 TCC 허가도 의미를 잃는다 |
| 1 | nix-darwin | `darwin-uninstaller` (이 flake 가 고정한 판) | 로그인 셸 → `/bin/zsh`, `/etc/*.before-nix-darwin` 복원, launchd 서비스·`/etc/sudoers.d`(NOPASSWD)·`pam sudo_local` 제거 |
| 2 | home-manager | 스토어의 `home-manager-files` 를 가리키는 링크, 그 자리의 `.backup` 되돌리기 | nix-darwin 제거가 건드리지 않는다 |
| 3 | Nix | 설치기 기록이 있으면 `sudo /nix/nix-installer uninstall`, 없으면 매뉴얼 절차 | 마지막. `/nix` 를 쓰는 것이 아무것도 없어야 한다 |

p1~p6 은 `--purge` 때만. 기본 `--run` 이 kanata·드라이버·서명 신원·nix 밖 빌드를 남기는 것은
일부러다 — TCC 허가와 드라이버 승인이 거기에 묶여 있어서, 다시 깔면 7 절의 단계가 없다.

1 이 끝나면 비밀번호 없는 sudo 가 사라지므로 그 뒤의 `sudo` 는 비밀번호를 묻는다.

### 알려진 함정

- **Lix 설치기의 uninstall 이 마지막 단계에서 멈춘다**(lix-installer#80. nix-installer 3.95.0,
  macOS 27.0.1 에서 실측). "Revert: Create an encrypted APFS volume `Nix Store`…" 를 찍은 뒤로
  끝나지 않는다. `/nix` 는 이미 언마운트돼 있고 쓰는 프로세스도 없다 — 설치기가 띄운 자식이
  `<defunct>` 로 남은 채 설치기 자신이 교착한 것이라 기다려도 소용없다. 그 앞의 되돌리기
  (nixbld 사용자, 데몬, 셸 훅, fstab)는 끝나 있으므로 설치기를 죽이고 남은 셋만 지운다:
  ```bash
  diskutil list | grep "Nix Store"                      # 남은 볼륨의 diskXsY
  sudo diskutil apfs deleteVolume diskXsY
  sudo security delete-generic-password -s "Nix Store" /Library/Keychains/System.keychain
  ```
  `/etc/synthetic.conf` 의 `nix` 줄은 바로 다시 깔 거면 남긴다(공식 설치기도 같은 줄을 쓴다).
- **darwin-uninstaller 는 사용자 에이전트를 내리지 않는다.** root 로 돌아서 `~/Library/LaunchAgents`
  의 plist 만 지우고 gui 도메인의 job 은 그대로 둔다. nix 의 bash 로 도는 `wal-watch` 가 남으면
  `/nix` 를 언마운트하지 못하므로 `apps/uninstall` 이 그 앞에서 사용자 권한으로 내린다.
- **공식 설치기는 fstab 을 손으로** 고쳐야 한다: `sudo vifs` 로 `/nix` 줄을 지운다. 스크립트는
  그 줄만 남기고 나머지를 한다.
- 끝나면 빈 `/nix` 와 `/run` 이 남는다. 재부팅 때 사라진다.

### 남는 것

- TCC 목록의 항목 — 없는 바이너리를 가리킬 뿐 해는 없다. 지우려면 설정 화면에서.
- `~/git` 의 소스, 앱 데이터(`~/Library/Application Support` 등), 손으로 깐 앱(Claude.app 등).
- 기본 `--run` 이면 위 p1~p6 의 것들.

### 검증 상태

2026-10-31, `jhs-MacBook-Air`(macOS 27.0.1)에서 Lix 설치기 판을 걷어 내고 공식 설치기로 다시 깔았다.

- 단계는 계획 모드가 찍는 명령을 그대로 손으로 돌렸다(`--run` 의 단계별 y/N 루프 자체는 쓰지 않았다).
  중간에 nix-darwin 의 NOPASSWD 가 사라지므로 `/etc/sudoers.d/` 에 같은 규칙의 임시 파일을 두고,
  첫 switch 뒤에 지웠다.
- nix-darwin 제거, home-manager 링크(17 개) 정리와 `.backup` 복원은 그대로 됐다. 사용자 에이전트가
  남는 문제와 Lix uninstall 교착은 위 "알려진 함정" 에 적었고, 앞의 것은 스크립트에 반영했다.
- 공식 설치기(2.35.4, `--daemon --yes --no-channel-add`) 뒤 `/etc/nix/nix.conf`·`/etc/bashrc`·`/etc/zshrc`
  를 `.before-nix-darwin` 으로 옮기고 `nix shell nixpkgs#gh --command ./apps/build-switch` 한 번으로
  switch 가 끝났다. 기본 `--run` 이 남긴 kanata·드라이버·서명 신원·nix 밖 빌드 덕에 TCC 와 드라이버
  승인을 다시 할 것이 없었다.
- 손으로 내린 `wal-watch` 는 activation 이 다시 올리지 않았다(plist 만 다시 깐다). 로그아웃·로그인이나
  `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/org.nixos.wal-watch.plist` 로 올린다 — 설치 8 절의
  로그아웃이 이것도 해결한다.
- 끝난 뒤 `nix run .#check` 이상 없음: 셸·시스템·데몬 모두 Nix 2.34.8, VirtualHIDDevice `activated enabled`,
  rift-grid 가 창을 본다.
