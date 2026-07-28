# NixOS 모듈

NixOS 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + GTK 다크 테마 + mise 활성화)
├── korean.nix         # 로케일, fcitx5-hangul IME, keyd 한/영 리맵, CJK 폰트
└── packages.nix       # NixOS 전용 패키지 (shared/packages.nix + Linux 전용/GUI 앱)
```

시스템 레벨 설정(부팅, 데스크톱, 서비스, 유저 계정)은 이 디렉토리가 아니라
[`../../hosts/nixos/common.nix`](../../hosts/nixos/common.nix)에 있다.

## 데스크톱 환경

모든 NixOS 호스트가 **GNOME / Wayland** 기준이다. GDM으로 로그인하고 기본 세션은 `gnome`.
`services.xserver.enable`이 켜져 있지만 이건 Xwayland와 xkb 설정을 위한 것이지 X11 세션을
쓰기 위한 게 아니다.

GNOME 셸 자체의 확장/단축키/패널은 선언적으로 관리하지 않는다. 다크 모드만
`home-manager.nix`에서 dconf(`org/gnome/desktop/interface`)로 잡고, 같은 파일의 `gtk`
블록이 GNOME 세션 밖에서 뜨는 GTK 앱까지 커버한다.

## 한글 입력

`korean.nix`가 담당한다:

- **로케일** — UI는 `en_US.UTF-8`, 날짜/통화/주소 등 지역 포맷만 `ko_KR.UTF-8`
- **한/영 전환** — `keyd`로 오른쪽 Alt를 `hangeul` 키심으로 리맵. keyd는 evdev 레벨(xkb
  아래)에서 동작해서 X11 / Wayland / TTY 어디서나 동일하게 먹는다. `boot.kernelModules`에
  `uinput`이 필요하다(`common.nix`에서 로드)
- **IME** — fcitx5 + fcitx5-hangul(두벌식), `waylandFrontend = true`(Wayland
  text-input-v3). GTK 앱은 `fcitx5-gtk`, GNOME 위에서 도는 Qt 앱은
  `qt6Packages.fcitx5-qt`가 담당한다
- **Chromium 계열** — Ozone Wayland 브라우저는 `--enable-wayland-ime` 플래그가 없으면
  한글이 안 들어간다. 예시는
  [`hosts/nixos/galaxy-chromebook-1/home.nix`](../../hosts/nixos/galaxy-chromebook-1/home.nix)
- **폰트** — Noto CJK / Nanum / D2Coding / Pretendard + fontconfig 폴백

> fcitx5는 `~/.config/fcitx5/*`를 `/etc/xdg/fcitx5/*`보다 먼저 읽는다. 선언적 프로필이
> 안 먹으면 유저 로컬 설정이 남아 있는 것이니 지우고 다시 로그인한다.

## 호스트 추가하기

호스트는 아키텍처가 아니라 **hostname**으로 키잉된다. 현재 `amd`, `intel`,
`galaxy-chromebook-1` 셋이 있고, 새 호스트는 이들을 그대로 따라 하면 된다.

flake 속성 이름은 실제 hostname과 달라도 `--flake .#<이름>`으로 지정하면 동작하지만,
`apps/build-switch`가 인자 없이 실행될 때 `$(hostname)`으로 타겟을 고르므로 둘을 같게
맞춰두는 편이 편하다.

1. 디렉토리를 만든다:

   ```sh
   mkdir -p hosts/nixos/<hostname>
   ```

2. `hosts/nixos/<hostname>/default.nix`:

   ```nix
   { ... }:
   {
     imports = [
       ../common.nix
       ./hardware-configuration.nix
     ];

     networking.hostName = "<hostname>";
     # 머신별 튜닝(GPU 드라이버 등)은 여기에.
   }
   ```

3. **그 머신에서** hardware-configuration.nix를 생성한다. 이건 루트/부트 파일시스템, 스왑,
   initrd 커널 모듈, CPU 마이크로코드를 고정하므로 반드시 실기에서 뽑아야 한다:

   ```sh
   sudo nixos-generate-config --show-hardware-config \
     > hosts/nixos/<hostname>/hardware-configuration.nix
   ```

4. `flake.nix`의 `nixosConfigurations`에 한 줄 추가:

   ```nix
   <hostname> = mkNixosHost ./hosts/nixos/<hostname>;
   ```

5. 빌드:

   ```sh
   nix run .#build-switch                    # hostname 자동 감지
   nix run .#build-switch -- --host <name>   # 명시적 지정
   ```

### 이미 설치된 머신을 편입할 때

`common.nix`의 `system.stateVersion`과 `home-manager.nix`의 `home.stateVersion`은 둘 다
`lib.mkDefault "26.11"`이다. 이건 *새로* 설치하는 호스트 기준값이므로, 이미 돌고 있는
머신을 가져올 때는 그 머신이 설치된 릴리스로 호스트에서 덮어써야 한다:

```nix
system.stateVersion = "25.11";
home-manager.users.${user}.home.stateVersion = "25.11";
```

stateVersion은 nixpkgs 채널이 아니라 상태 데이터(DB 포맷, 기본 경로 등) 호환성을
고정하는 값이다. 채널은 flake가 계속 nixos-unstable을 따라가므로 패키지는 그대로 최신이
된다.

### 호스트별 home-manager 설정

`home-manager.users.<user>`는 서브모듈이라 정의가 병합된다. 호스트 전용 유저 설정은 호스트
디렉토리에 `home.nix`를 두고 이렇게 끼워넣는다
([galaxy-chromebook-1](../../hosts/nixos/galaxy-chromebook-1/default.nix) 참고):

```nix
{ user, ... }:
{
  home-manager.users.${user}.imports = [ ./home.nix ];
}
```
