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

```bash
git clone https://github.com/joonhoekim/nixos-config ~/nixos-config
cd ~/nixos-config
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#gh -- auth login
```

`subline`·`subline-terminal` input 이 비공개 `git+https` 라서 첫 빌드 전에 gh 인증이
있어야 한다(`flake.nix` 의 그 input 주석). 이 기계의 SSH 키는 GitHub 에 없다.

### 5. 호스트 붙이기

```bash
./apps/setup     # users/<이름>.nix, hosts/darwin/<hostname>/ 를 만들고 git add
./apps/doctor    # hostname · 계정 · 추적 안 된 파일
```

### 6. 첫 switch

```bash
nix --extra-experimental-features 'nix-command flakes' run .#build-switch
```

- flakes 는 이번 한 번만 플래그로 켠다. switch 뒤로는 nix-darwin 의 `/etc/nix/nix.conf` 가 켠다.
- `/etc` 의 파일이 가로막으면(`Unexpected files in /etc`) 그 파일을 `.before-nix-darwin` 으로
  옮기고 다시 — [03 §3](03-operating-on-macos.md) 의 2·3 번. 공식 설치기는 `/etc/nix/nix.conf`,
  `/etc/bashrc`, `/etc/zshrc` 를 남긴다.
- **두 번 돌린다.** 첫 번째에는 mise 가 rust 를 까는 중이라 rift-grid·subline-terminal 이
  "cargo 가 없어 건너뛴다" 로 넘어갈 수 있다.
- 끝에서 `apps/check/pending` 이 사람이 할 단계를 보인다. 아래 7 이 그 목록이다.

### 7. 사람이 해야 하는 단계 (TCC · 드라이버)

macOS 가 클릭을 요구해서 레포가 대신할 수 없다. activation 은 이 앞에서 멈추지 않고 성공으로
끝나고, 해당 데몬은 조용히 재시작을 반복한다.

| 순서 | 대상 | 할 일 | 설정 화면 | 확인 |
|---|---|---|---|---|
| 1 | Karabiner VirtualHIDDevice | 드라이버 확장 승인 | 일반 > 로그인 항목 및 확장 > 드라이버 확장 | `systemextensionsctl list` 가 `[activated enabled]` |
| 2 | `/usr/local/libexec/kanata` | 입력 모니터링 켜기 (목록에 없으면 `+` → `⌘⇧G` 로 경로) | 개인정보 보호 및 보안 > 입력 모니터링 | `sudo launchctl kickstart -k system/org.nixos.kanata` 뒤 `/var/log/kanata.log` 에 오류가 없다 |
| 3 | `~/.local/bin/rift-grid` | 손쉬운 사용, 화면 및 시스템 오디오 녹음 | 개인정보 보호 및 보안 | `nix run .#check` 의 rift-grid 절 |
| 4 | LinearMouse (cask 가 있는 호스트만) | 입력 모니터링 | 개인정보 보호 및 보안 > 입력 모니터링 | 외장 마우스 휠 방향 |

1 이 2 보다 먼저다. 드라이버가 없으면 kanata 는 권한이 있어도 키를 내보낼 곳이 없다.
kanata·rift-grid 는 이 기계의 서명 신원(`apps/mac-signing-cert`)으로 서명되므로 허가는
기계당 한 번이다 — 판이 바뀌어도 다시 묻지 않는다.

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
`/run/current-system/sw/bin/nix` 를 집는다(`modules/shared/shell-init.nix` 머리말). 남는 차이는
설치기 쪽뿐이다: 기본 프로필에 그 설치기의 nix 가 있고, 제거가 그 설치기의 `uninstall` 로
간다. `jhs-MacBook-Air` 가 Lix 설치기로 깔린 상태다(2026-10-31).

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
| p4 | kanata | `/usr/local/libexec/kanata`, 로그 | |
| p5 | nix 밖 빌드 | `~/.local/bin` 의 rift-grid·subline-terminal, `~/Applications/subline-terminal.app` | 소스(`~/git`)는 남긴다 |
| p6 | 서명 신원 | `apps/mac-signing-cert --remove` | 지우면 그 신원에 묶인 TCC 허가도 의미를 잃는다 |
| 1 | nix-darwin | `darwin-uninstaller` (이 flake 가 고정한 판) | 로그인 셸 → `/bin/zsh`, `/etc/*.before-nix-darwin` 복원, launchd 서비스·`/etc/sudoers.d`(NOPASSWD)·`pam sudo_local` 제거 |
| 2 | home-manager | 스토어의 `home-manager-files` 를 가리키는 링크, 그 자리의 `.backup` 되돌리기 | nix-darwin 제거가 건드리지 않는다 |
| 3 | Nix | 설치기 기록이 있으면 `sudo /nix/nix-installer uninstall`, 없으면 매뉴얼 절차 | 마지막. `/nix` 를 쓰는 것이 아무것도 없어야 한다 |

p1~p6 은 `--purge` 때만. 기본 `--run` 이 kanata·드라이버·서명 신원·nix 밖 빌드를 남기는 것은
일부러다 — TCC 허가와 드라이버 승인이 거기에 묶여 있어서, 다시 깔면 7 절의 단계가 없다.

1 이 끝나면 비밀번호 없는 sudo 가 사라지므로 그 뒤의 `sudo` 는 비밀번호를 묻는다.

### 알려진 함정

- **Lix 설치기의 uninstall 이 볼륨 언마운트에서 멈춘다**는 보고가 있다(2026-05,
  lix-installer#80). 먼저 `sudo lsof +D /nix | head` 로 `/nix` 를 쓰는 프로세스를 본다.
- **공식 설치기는 fstab 을 손으로** 고쳐야 한다: `sudo vifs` 로 `/nix` 줄을 지운다. 스크립트는
  그 줄만 남기고 나머지를 한다.
- 끝나면 빈 `/nix` 와 `/run` 이 남는다. 재부팅 때 사라진다.

### 남는 것

- TCC 목록의 항목 — 없는 바이너리를 가리킬 뿐 해는 없다. 지우려면 설정 화면에서.
- `~/git` 의 소스, 앱 데이터(`~/Library/Application Support` 등), 손으로 깐 앱(Claude.app 등).
- 기본 `--run` 이면 위 p1~p6 의 것들.

### 검증 상태

- 계획 모드: `jhs-MacBook-Air`(Lix 설치기, nix-darwin, home-manager 링크 17 개)에서 단계와
  명령이 맞게 나오는 것을 확인했다. 스토어의 셸 아래에서 `--run` 을 거절하는 것도 확인했다.
- `--run`: **아직 돌려 보지 않았다.** 처음 돌린 결과로 이 절을 고친다.
