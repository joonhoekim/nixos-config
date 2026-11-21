# baldur

Lenovo Y700 Gen 5 태블릿(TB323FU, Snapdragon 8 Elite Gen 5). UFS 의 `baldur-root` 파티션에 NixOS 가 있다.
기기 층(커널 스텁·펌웨어 배치·DSP·센서·헬퍼)은 tb323fu-linux 레포의 `nixosModules.rootfs` 가 내고,
`hosts/nixos/baldur/default.nix` 는 그 모듈을 켜고 이 레포의 공통 설정을 얹는다.

다른 호스트와 다른 점은 하나다: **이 레포만 빌드하면 안 된다.** 아래 파일들이 레포 밖에 있다.

## 파일이 어디 있나

```
/etc/nixos/                 jh 소유. git 레포가 아니다
├── flake.nix               wrapper: nixos-config 의 baldur 에 local.nix 를 extendModules 로 더한다
├── flake.lock
├── local.nix               기기에만 있는 값: 비밀번호 해시, root SSH 공개키, devAccess, Android boot 해시
├── firmware/  kernel/  sensors/   Android 에서 뽑은 펌웨어, 커널 config, 센서 파일
└── src/nixos-config        ← 이 레포(git clone). 편집은 여기서 한다

~/git/nixos-config -> /etc/nixos/src/nixos-config   (symlink, 다른 기계와 같은 경로로 들어가려고)
```

- `local.nix` 와 `firmware/` 는 git 에 넣지 않는다. 키·해시가 있고, 펌웨어는 Lenovo 것이라 재배포할 수 없다.
  git 기반 flake 는 추적하지 않는 파일을 못 보므로 레포 안에 gitignore 로 둘 수도 없다. 그래서 wrapper 가 따로 있다.
- 다른 기계의 `/etc/nixos` 에 남은 `hardware-configuration.nix` 와 같은 성격이다: 그 기계에서 생긴 것.
- 이 파일들이 빠진 시스템은 평가와 빌드가 그대로 성공한다. 부팅하면 Wi-Fi · 소리 · DSP 가 없고
  USB 망(192.168.7.2)과 root SSH 가 사라진다. 원격으로 들어갈 길이 다 닫히는 셈이다.

## 고치고 바꾸기

다른 기계와 같다.

```sh
cd ~/git/nixos-config          # = /etc/nixos/src/nixos-config
vim ...
nix run .#build-switch         # 또는 ./apps/build-switch, 빌드만: nix run .#build
```

`apps/build-lib.sh` 가 `/etc/nixos/flake.nix` 에 `nixosConfigurations.<hostname>` 이 있으면 레포 대신
wrapper 를 빌드하고, `--override-input nixos-config <이 체크아웃>` 을 붙인다. 그래서

- 커밋하지 않은 수정도 빌드에 들어간다(다른 기계처럼 작업 트리를 빌드한다. 새 파일은 `git add` 해야 보인다).
- wrapper 의 `flake.lock` 이나 input URL(`?ref=main`)은 갱신하지 않아도 된다.
- 출력 첫 줄이 `Building /etc/nixos#nixosConfigurations.baldur...` 인지 본다. `.#` 로 나오면 wrapper 를 못
  찾은 것이니 멈춘다.

sudo 없이 돌린다. 빌드는 jh 로 하고, 전환 단계에서만 sudo 를 쓴다.

## push

`origin` 은 GitHub(`joonhoekim/nixos-config`)이고 이 체크아웃은 다른 기계처럼 `main` branch 다. jh 는 gh 에 로그인돼 있다
([github-auth](../github-auth.md)). 비공개 input 을 받는 데도 이 인증을 쓴다.
설치 때 bundle(`/root/nixos-config.bundle`)로 들어와서 처음에는 origin 이 그 파일이었다. bundle 은 이제 안 쓴다.

## 다른 input 을 올릴 때

wrapper 의 input 은 nixos-config 하나뿐이고, tb323fu-linux·subline 들은 이 레포의 `flake.lock` 이 정한다.
그래서 올리는 법도 다른 기계와 같다: 이 체크아웃에서 `nix flake update tb323fu-linux`,
`nix run .#subline-update`(subline 을 올리고 깔고 lock 을 커밋한다). `subline-update` 도 `build-lib.sh` 로
wrapper 를 고른다. `--local` 의 기본 경로 `~/git/subline` 은 이 기계에 없으니 DIR 을 준다.
비공개 input(subline 들)은 jh 의 gh 인증으로 받는다.

## 손으로 빌드할 때

```sh
nixos-rebuild switch --sudo --flake /etc/nixos#baldur     # jh 로. 빌드는 jh, 전환만 sudo
```

이건 `src/nixos-config` 의 **커밋된** `main` branch 를 빌드한다(`?ref=main`). 작업 트리를 빌드하려면
`--override-input nixos-config /etc/nixos/src/nixos-config` 를 붙인다.

root 로는 돌리지 않는다. root 에는 gh 인증이 없어 비공개 input 을 못 받는다. 또 nix(libgit2)가 jh 소유
clone 을 `not owned by current user` 로 거부하는데, 이건 root 의 `~/.gitconfig` 에 `safe.directory` 를 넣어 막아 두었다.
