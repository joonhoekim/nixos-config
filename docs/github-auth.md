# 새 기계에서 비공개 레포 받기 — gh 빌려 쓰기

이 레포와 그것이 끌어오는 `subline`·`subline-terminal` 은 비공개 GitHub 레포다. 새 기계에서는
레포를 받는 것부터 첫 빌드까지 GitHub 로그인이 필요하다.

**gh** 는 GitHub 공식 CLI 다. 로그인을 하고, 그 로그인을 git 에 빌려준다. 이 레포가 모든 기계에
gh 를 깔고(`modules/shared/packages.nix` 의 core) git 의 GitHub 인증을 gh 에 맡기지만
(`modules/shared/programs/git.nix`), 그건 첫 switch 뒤의 일이다. 그 전에는 nixpkgs 의 gh 를
잠깐 빌려 쓴다.

## 순서

nix 만 있으면 된다(macOS 는 nix 를 깐 뒤, NixOS 설치 USB 와 NixOS 는 처음부터).

```sh
# 1. gh 가 든 셸을 연다. 아래는 전부 이 셸 안에서 한다.
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#gh

# 2. 이 셸 안의 git 이 GitHub 인증을 gh 에 묻게 한다. 셸을 닫으면 사라진다.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.https://github.com.helper GIT_CONFIG_VALUE_0='!gh auth git-credential'

# 3. 로그인. "Login with a web browser" 를 고르면 코드가 뜬다. 브라우저가 없는 기계(설치 USB)라면
#    다른 기기에서 https://github.com/login/device 를 열고 그 코드를 넣는다.
gh auth login

# 4. 레포를 받는다.
gh repo clone joonhoekim/nixos-config ~/nixos-config
```

그다음 첫 빌드(`./apps/build-switch`, 설치 USB 에서는 `nixos-install`)도 **같은 셸에서** 돌린다.
nix 가 비공개 input 을 받을 때 2 의 설정으로 gh 에게 인증을 묻는다.

첫 switch 가 끝나면 이 셸은 필요 없다. 그 뒤로는 레포가 깐 gh 와 git 설정이 같은 일을 한다.
3 의 로그인은 gh 의 설정에 남으므로 다시 할 필요가 없다. 단, 설치 USB 에서 한 로그인은 USB 와
함께 사라지므로 설치한 기계에서 한 번 더 `gh auth login` 한다.

## 왜 이렇게 하나

- **2 를 빼면 첫 빌드가 실패한다.** git 의 인증 설정은 첫 switch 가 만들기 때문에, 맨 기계의 nix 는
  비공개 input 앞에서 `could not read Username for 'https://github.com'` 로 멈춘다.
- **`gh auth setup-git` 을 쓰지 않는다.** 그 명령은 `~/.gitconfig` 에 gh 의 스토어 경로를 박는데,
  git 은 이 파일을 home-manager 의 `~/.config/git/config` 보다 나중에 읽어서 레포의 설정을 덮는다.
  gc 가 그 경로를 지우는 날 GitHub 인증이 조용히 깨진다. 2 의 환경 변수는 셸과 함께 사라진다.
- **`gh repo clone` 은 2 없이도 된다.** gh 가 clone 할 때 자기 인증을 git 에 직접 넘긴다. 2 가
  필요한 것은 gh 를 거치지 않는 git, 곧 nix 의 input 받기와 `git push` 다.

2026-11-01 에 이 Mac 에서 빈 HOME 으로 확인했다: 1·2 없이 nix 가 `subline-terminal` 을 받으면
위 오류로 실패하고, 2 를 두면 받는다. `gh repo clone` 은 `~/.gitconfig` 를 만들지 않는다.
