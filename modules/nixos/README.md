# NixOS 모듈

NixOS 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── amd.nix            # AMD Ryzen/Radeon 공통 레이어 (AMD 호스트에서 import)
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + GTK 다크 테마 + mise 활성화)
├── keyboard.nix       # keyd 키 리맵 (한/영, 스페이스 홀드 TouchCursor 레이어)
├── keyboard.nix.vim   # ↑의 vim 배치 버전 (보관용, import 안 됨)
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
- **Caps Lock 홀드 → TouchCursor 네비게이션 레이어** — 윈도우 머신들이 쓰는
  [TouchCursor](https://github.com/martin-stone/touchcursor)와 같은 배치. `ijkl` 역T 화살표.
  탭하면 평범한 Caps Lock 토글

| 키 | 동작 | | 키 | 동작 |
|----|------|-|----|------|
| `i` `j` `k` `l` | ↑ ← ↓ → (역T) | | `w` `e` / `b` | 단어 앞/뒤 (`C-→` / `C-←`) |
| `u` / `o` | 줄 처음 / 끝 (`Home` / `End`) | | `g` / `G` | 문서 처음 / 끝 (`C-Home` / `C-End`) |
| `h` / `n` | PageUp / PageDown | | `/` | 찾기 (`C-f`) |
| `p` / `m` | `Backspace` / `Delete` | | `y` | `Insert` |

오른쪽 열이 TouchCursor에 없어서 vim에서 빌려온 것들이다(그쪽이 비워두는 키만 씀).

- **전 바인딩이 unshifted**라 Shift는 통째로 선택 확장에 남는다 — `Caps+Shift+j` = 왼쪽으로
  선택, `Caps+Shift+o` = 줄 끝까지 선택. vim 레이어는 `$ { } G N`에서 Shift가 커맨드
  자체였기 때문에 이게 구조적으로 불가능했다 (`G`만 여기서도 같은 이유로 이동 전용이다)
- 매핑되지 않은 키는 홀드 중에도 **그냥 그 글자**가 입력된다(`[nav]`는 modifier 레이어가
  아니라 평범한 레이어다)
- **트리거는 항상 Caps Lock** — 윈도우 TouchCursor에서 기본값(스페이스)에서 바꾸는 유일한
  설정이 이거라 여기서도 맞춘다. 덤으로 방어 로직이 통째로 사라진다: 스페이스 트리거는
  타이핑 한복판에 있어서 idle 타임아웃(`overloadi`)과 "삼킨 공백을 먼저 뱉기"
  (`macro(space <key>)`)가 필요한데, Caps Lock은 어차피 안 쓰는 키라 둘 다 필요 없다
- **galaxy-chromebook-1에는 레이어가 없다** — 그 섀시엔 Caps Lock 키 자체가 없다(그 자리가
  런처/검색 키, 즉 모디파이어다). 스페이스 트리거로는 가능하지만 그러면 방어 로직이
  따라붙고, 그 기기는 타이핑보다 웹 브라우징용이라 포기했다. 설정도 따로 없다
  ([호스트 파일](../../hosts/nixos/galaxy-chromebook-1/default.nix)의 주석 한 덩어리가 전부)

### vim 레이어 (보관)

[`keyboard.nix.vim`](keyboard.nix.vim)에 vim 배치 버전이 import되지 않은 채로 남아 있다.
`keyboard.nix` 자리에 넣으면 그대로 동작한다. 왜 접었는지, 그리고 OS 레벨 레이어가 vim의
천장에 닿을 수 없는 이유(모드/문법이 없어서 `d2w` 같은 조합이 성립하지 않는다)는 그 파일
헤더에 적어뒀다.

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
