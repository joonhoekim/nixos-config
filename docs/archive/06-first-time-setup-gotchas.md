# 06. 최초 셋업에서 겪는 함정들

> **보관본** — 지금 `docs/` 세 편으로 압축되기 전의 원본이다. 파일 경로·앱 목록 등
> 세부는 그 시점의 레포를 서술하므로 현재와 다르다. 현행 문서는 [`../README.md`](../README.md)부터.

이미 손으로 세팅된 Mac 위에 선언적 관리를 처음 덮어씌울 때 겪는 1회성 충돌들과 해결법.
실제로 우리가 겪은 순서대로 정리했다.

중요한 관점: 이 함정들은 "Nix가 어렵다"기보다 "기존 수동 환경과 선언적 환경의 첫 만남"에서 오는 것이다.
한 번 자리 잡으면 다시 거의 안 난다. 그 뒤로는 설정 파일을 고치고 `build-switch` 한 줄이면 끝이다.

## 0. flake는 git에 추적된 파일만 본다

증상:

```
error: Path 'modules/.../karabiner.json' in the repository is not tracked by Git.
```

새 파일을 만들고 `flake.nix`/모듈에서 참조하면, 그 파일을 `git add` 하기 전에는 Nix가 보지 못한다.

해결:

```bash
git add <새 파일>
```

새 파일을 추가했는데 "그런 파일 없다"는 류의 에러가 나면 가장 먼저 이걸 의심한다.

## 1. nixpkgs-unstable의 패키지 표류

이 저장소는 `nixos-unstable` 채널을 쓴다. 빌드 도중 다음 같은 에러/경고를 만날 수 있다.

- `'du-dust' has been renamed to/replaced by 'dust'` — 패키지 개명
- `programs.thefuck ... no longer has any effect ... consider using programs.pay-respects` — 패키지 제거
- `nixfmt-rfc-style is now the same as pkgs.nixfmt` — 별칭 통합
- 특정 패키지(예: 소스 빌드되는 emacs)가 상류 호환성 문제로 컴파일 실패

해결 접근:

- 에러 메시지가 보통 대체 이름을 알려준다. 그대로 바꾸면 된다.
- 어떤 derivation이 문제인지 모를 때는 빌드 대상부터 확인한다.

```bash
# 무엇이 새로 빌드되는지(캐시에 없는지) 미리 본다
nix build .#darwinConfigurations.aarch64-darwin.system --dry-run

# 실패한 derivation의 전체 로그
nix-store -l /nix/store/<...>.drv
```

핵심 습관: 활성화(`build-switch`)까지 가기 전에 `nix build`로 먼저 빌드가 통과하는지 검증하면,
sudo·시스템 변경 없이 안전하게 문제를 잡을 수 있다.

## 2. `/etc` 파일이 가로막음 (최초 활성화)

증상:

```
error: Unexpected files in /etc, aborting activation
  /etc/nix/nix.conf
  /etc/bashrc
  /etc/zshrc
```

nix-darwin이 이 파일들을 관리하려는데, 기존 파일(애플 기본 + Nix 설치관리자 생성)이 이미 있어서
덮어쓰면 뭔가 잃을까 봐 멈춘 것이다. 에러가 아니라 안전장치에 가깝다.

해결: 기존 파일을 백업용으로 이름만 바꾼 뒤 재시도.

```bash
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/bashrc       /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc        /etc/zshrc.before-nix-darwin
nix run .#build-switch
```

백업이라 안전하다. 되돌리려면 `.before-nix-darwin`을 떼고 원래 이름으로 mv 하면 된다.
nix-darwin이 새로 만드는 `/etc/zshrc` 등도 Nix 데몬 로딩을 포함하므로 셸은 정상 동작한다.

## 3. `nix-command`/flakes가 갑자기 비활성

증상:

```
error: experimental Nix feature 'nix-command' is disabled
```

원인: 위 2번에서 `/etc/nix/nix.conf`를 백업으로 옮겼는데, 그 파일에
`experimental-features = nix-command flakes`가 들어 있었다. 그래서 일시적으로 기능이 꺼진 것이다.
nix-darwin이 활성화를 끝내면 `/etc/nix/nix.conf`를 다시 만들어 영구 복구되는데, 그 활성화를 아직 못 끝낸 상태.

해결: 이번 한 번만 기능을 직접 켜서 부트스트랩.

```bash
nix --extra-experimental-features 'nix-command flakes' run .#build-switch
```

활성화가 끝나면 `/etc/nix/nix.conf`가 재생성되어, 다음부터는 그냥 `nix run .#build-switch`로 된다.

## 4. Homebrew Taps가 가로막음

증상:

```
Error: An existing /opt/homebrew/Library/Taps is in the way
```

원인: 설정이 `mutableTaps = false`이면 "tap은 선언한 것만 허용, Taps 폴더는 읽기 전용으로 잠금"이라는 뜻이다.
그런데 이미 수동으로 추가한 커스텀 tap(예: aerospace의 `nikitabobko/tap`)이 있으면 충돌한다.

판단 기준:

- brew를 수동으로 쓰고 커스텀 tap도 쓰는 사람이라면 `mutableTaps = false`는 맞지 않는다.
  앞으로도 계속 충돌하고 커스텀 tap을 영영 못 쓰게 된다.
- 해결: `flake.nix`의 nix-homebrew 블록에서 `mutableTaps = true`로 바꾼다.
  nix-darwin은 선언한 casks를 계속 관리하되, 수동 `brew tap`/`brew install`도 허용한다.

```nix
nix-homebrew = {
  ...
  mutableTaps = true;
};
```

## 5. home-manager가 기존 dotfile을 덮어쓰지 못함

증상:

```
Existing file '/Users/<user>/.zshrc' would be clobbered
Existing file '/Users/<user>/.zprofile' would be clobbered
Existing file '/Users/<user>/.ssh/config' would be clobbered
```

home-manager가 관리하려는 파일이 이미 홈에 있어서, 기존 내용이 날아갈까 봐 안전하게 멈춘 것이다.

해결: 기존 파일을 자동 백업하도록 설정한다. (`modules/darwin/home-manager.nix`)

```nix
home-manager = {
  useGlobalPkgs = true;
  backupFileExtension = "backup";   # 기존 파일을 <name>.backup 으로 옮긴 뒤 관리
  ...
};
```

재실행하면 기존 `.zshrc` 등이 `~/.zshrc.backup`으로 옮겨지고 home-manager 버전이 자리잡는다.
백업된 파일에 커스텀하게 넣었던 내용이 있으면 나중에 nix 설정으로 옮기면 된다(그냥 둬도 무해).

참고: 내용이 완전히 같은 파일(예: nix가 만든 것과 동일한 karabiner.json)은
"will be skipped since they are the same"으로 그냥 건너뛴다. 이건 충돌이 아니다.

주의: `.backup` 파일이 이미 존재하면 다시 에러가 난다(이전 시도 흔적). 그 파일을 지우거나 이름을 바꾸고 재시도한다.

## 적용 후 확인할 것

- 새 터미널 창을 열어야 새 zsh 설정(p10k, atuin, zoxide 등)이 완전히 뜬다.
  현재 떠 있는 셸에는 옛 설정이 남아 있다.
- 일부 macOS 설정은 로그아웃/재시작 후에 완전히 반영된다.

## 큰 그림

- `/etc/*` 백업, `nix-command disabled`, Homebrew Taps, dotfile clobber — 전부 "최초 1회" 통과의례다.
- 한 번 넘기면 이후에는 파일 수정 → `build-switch` 루프만 남는다.
- 활성화 전에 `nix build`로 먼저 검증하는 습관이 가장 큰 안전망이다.
