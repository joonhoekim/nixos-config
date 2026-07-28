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

**KDE Plasma 6 / Wayland** 기준이다. SDDM(Wayland)으로 로그인하고 기본 세션은 `plasma`.
`services.xserver.enable`이 켜져 있지만 이건 Xwayland와 xkb 설정을 위한 것이지 X11 세션을
쓰기 위한 게 아니다.

Plasma 자체의 패널/테마/단축키는 선언적으로 관리하지 않는다(`plasma-manager` 미사용).
시스템 설정 앱에서 수동으로 잡는다. `home-manager.nix`의 `gtk` 블록은 Plasma 아래에서
도는 GTK 앱만 다크 테마로 맞추기 위한 것이다.

## 한글 입력

`korean.nix`가 담당한다:

- **로케일** — UI는 `en_US.UTF-8`, 날짜/통화/주소 등 지역 포맷만 `ko_KR.UTF-8`
- **한/영 전환** — `keyd`로 오른쪽 Alt를 `hangeul` 키심으로 리맵. keyd는 evdev 레벨(xkb
  아래)에서 동작해서 X11 / Wayland / TTY 어디서나 동일하게 먹는다. `boot.kernelModules`에
  `uinput`이 필요하다(`common.nix`에서 로드)
- **IME** — fcitx5 + fcitx5-hangul(두벌식), `waylandFrontend = true`.
  Plasma 6는 Qt6라서 `qt6Packages.fcitx5-qt`가 들어간다
- **폰트** — Noto CJK / Nanum / D2Coding / Pretendard + fontconfig 폴백

> fcitx5는 `~/.config/fcitx5/*`를 `/etc/xdg/fcitx5/*`보다 먼저 읽는다. 선언적 프로필이
> 안 먹으면 유저 로컬 설정이 남아 있는 것이니 지우고 다시 로그인한다.

## 호스트 추가하기

호스트는 아키텍처가 아니라 **hostname**으로 키잉된다. 기존 `amd` / `intel`을 그대로 따라
하면 된다.

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
