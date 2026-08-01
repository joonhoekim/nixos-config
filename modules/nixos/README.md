# NixOS 모듈

NixOS 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── amd.nix            # AMD Ryzen/Radeon 공통 레이어 (AMD 호스트에서 import)
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + GTK 다크 테마 + mise 활성화)
├── keyboard.nix       # keyd 키 리맵 (한/영, Caps Lock 네비게이션 레이어)
├── korean.nix         # 로케일, fcitx5-hangul IME, CJK 폰트
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
- **한/영 전환** — 오른쪽 Alt → `hangeul` 리맵. 실제 설정은 [`keyboard.nix`](keyboard.nix)에
  있다(아래 참고)
- **IME** — fcitx5 + fcitx5-hangul(두벌식), `waylandFrontend = true`(Wayland
  text-input-v3). GTK 앱은 `fcitx5-gtk`, GNOME 위에서 도는 Qt 앱은
  `qt6Packages.fcitx5-qt`가 담당한다
- **Chromium 계열** — Ozone Wayland 브라우저는 `--enable-wayland-ime` 플래그가 없으면
  한글이 안 들어간다. 예시는
  [`hosts/nixos/galaxy-chromebook-1/home.nix`](../../hosts/nixos/galaxy-chromebook-1/home.nix)
- **폰트** — Noto CJK / Nanum / D2Coding / Pretendard + fontconfig 폴백

> fcitx5는 `~/.config/fcitx5/*`를 `/etc/xdg/fcitx5/*`보다 먼저 읽는다. 선언적 프로필이
> 안 먹으면 유저 로컬 설정이 남아 있는 것이니 지우고 다시 로그인한다.

## 키보드 리맵

전부 [`keyboard.nix`](keyboard.nix)의 `keyd`가 담당한다. keyd는 evdev 레벨(xkb *아래*)에서
동작하므로 niri / GNOME / Xwayland / TTY 어디서나 똑같이 먹는다. **`services.xserver.xkb.options`는
쓰지 않는다** — niri는 자기 설정(`niri/rice/config.kdl`)에서, mutter는 dconf에서 각자
키맵을 만들기 때문에 xkb 옵션은 X11 앱에만 닿는다. `boot.kernelModules`의 `uinput`이
필요하다(`hosts/nixos/common.nix`에서 로드).

- **오른쪽 Alt → `hangeul`** — fcitx5-hangul이 이걸 받아 한/영을 토글한다
- **Caps Lock 홀드 → 네비게이션 레이어** — macOS의 Karabiner 설정을 그대로 포팅한 것.
  탭하면 평범한 Caps Lock 토글, 홀드하면 vim/neovim 키맵이 뜬다

키 표와 설계 의도는 [`../darwin/config/karabiner/README.md`](../darwin/config/karabiner/README.md)가
원본이고, 동작만 Linux 대응으로 바뀐다(단어 이동 `⌥←/→` → `Ctrl+←/→`, 줄 끝 `⌘→` → `End`,
`⌘C/V/Z` → `Ctrl+C/V/Z`).

| 키 | 동작 | | 키 | 동작 |
|----|------|-|----|------|
| `h` `j` `k` `l` | ← ↓ ↑ → | | `/` | 찾기 (`C-f`) |
| `w` `e` / `b` | 단어 앞/뒤 (`C-→` / `C-←`) | | `n` / `N` | 다음/이전 찾기 (`C-g` / `C-S-g`) |
| `0` / `$` | 줄 처음 / 끝 (`Home` / `End`) | | `u` / `U` | 실행 취소 / 다시 실행 |
| `{` / `}` | 문단 위 / 아래 (`C-↑` / `C-↓`) | | `x` / `X` | `Delete` / `Backspace` |
| `g` / `G` | 문서 처음 / 끝 (`C-Home` / `C-End`) | | `y` / `p` | 복사 / 붙여넣기 |
| `i` / `m` | PageUp / PageDown | | | |

- 매핑되지 않은 키는 홀드 중에도 **그냥 그 글자**가 입력된다(`[nav]`는 modifier 레이어가
  아니라 평범한 레이어다)
- 이동 계열은 Shift가 그대로 통과해서 **선택 확장**이 된다 (`Caps+Shift+j` = 아래로 선택)
- Shift 자체가 커맨드인 키(`$ { } G N X U`)는 composite 레이어 `[nav+shift]`에 있다.
  composite 레이어는 구성 레이어의 modifier를 출력에서 제거해주기 때문에 `$`가
  `Shift+End`(선택)가 아니라 `End`(이동)로 나간다. keyd는 composite를 구성 레이어보다
  **뒤에** 선언할 것을 요구하므로 이것만 `extraConfig`에 들어간다
- **galaxy-chromebook-1은 예외** — 그 섀시엔 손가락이 기대하는 자리에 Ctrl이 없어서
  Caps Lock을 레이어 대신 Ctrl로 쓴다([호스트 파일](../../hosts/nixos/galaxy-chromebook-1/default.nix)에서
  `mkForce`로 덮어씀)

리빌드하면 keyd 유닛이 자동으로 재시작된다(nixpkgs 모듈이 `/etc/keyd/*.conf`를
`restartTriggers`에 걸어둔다). 문법 검증은 `keyd check /etc/keyd/default.conf`,
실제로 뭐가 나가는지 보려면 `sudo keyd monitor`.

## 호스트 추가하기

호스트는 아키텍처가 아니라 **hostname**으로 키잉된다. 현재 `mn56`(Firebat MN56, Ryzen
7840HS)와 `galaxy-chromebook-1` 둘이 있고, 새 호스트는 이들을 그대로 따라 하면
된다. CPU 벤더가 아니라 **머신 이름**으로 짓는다 — 같은 칩을 쓰는 기기가 둘 이상이면
`amd`나 `intel` 같은 이름은 바로 무너진다.

호스트 디렉토리는 **실제로 존재하는 머신**만 만든다. 그 머신에서 생성한 진짜
`hardware-configuration.nix` 없이는 호스트 항목이 아무 쓸모가 없고, placeholder를
커밋해두면 `nix flake check`만 깨진다. 예전에 있던 `intel` 호스트가 정확히 그 상태여서
제거했다.

벤더 공통 설정(예: AMD의 `radeontop`/전력 관리 주석)은 호스트 디렉토리가 아니라
[`amd.nix`](amd.nix) 같은 모듈에 두고 여러 호스트가 import한다. 호스트 디렉토리에는
그 섀시에만 해당하는 것만 남긴다.

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
