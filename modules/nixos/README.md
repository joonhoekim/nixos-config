# NixOS 모듈

NixOS 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── amd.nix            # AMD Ryzen/Radeon 공통 레이어 (AMD 호스트에서 import)
├── dms/               # 두 세션이 같이 쓰는 DMS 플러그인 (RiceSwitcher)
├── home-manager.nix   # 유저 레벨 설정 (shared/home-manager.nix + dconf 다크 모드 + mise 활성화)
├── hyprland/          # Hyprland 세션 (uwsm) + 같은 셸, 라이싱 시드·셰이더·스튜디오
├── intel.nix          # Intel CPU/iGPU 공통 레이어 (Intel 호스트에서 import)
├── keyboard.nix       # keyd 키 리맵 (한/영, Caps Lock 홀드 레이어)
├── keyboard.nix.vim   # ↑의 vim 배치 버전 (보관용, import 안 됨)
├── korean.nix         # 로케일, fcitx5-hangul IME, CJK 폰트
├── nginx.nix          # 로컬 리버스 프록시 (import 하는 호스트에서만)
├── niri/              # niri 세션 + DankMaterialShell, 라이싱 시드
├── packages.nix       # NixOS 전용 패키지 (shared/packages.nix + Linux 전용/GUI 앱)
└── pointer/           # ↑ 레이어의 마우스 절반 (keyd가 못 하는 포인터 이동)
```

시스템 레벨 설정(부팅, 데스크톱, 서비스, 유저 계정)은 이 디렉토리가 아니라
[`../../hosts/nixos/common.nix`](../../hosts/nixos/common.nix)에 있다.

## 데스크톱 환경

로그인은 greetd/tuigreet이고, 세션은 셋이다 — [`niri/`](niri)(기본),
[`hyprland/`](hyprland)(uwsm), 그리고 폴백인 **GNOME / Wayland**. 앞의 둘은 같은 셸
(DankMaterialShell)을 공유하고, 셸을 어느 세션에 붙이는지는 각 모듈이 systemd
`wantedBy`로 정한다. `services.xserver.enable`이 켜져 있지만 이건 Xwayland와 xkb 설정을
위한 것이지 X11 세션을 쓰기 위한 게 아니다.

GNOME 셸 자체의 확장/단축키/패널은 선언적으로 관리하지 않는다. 다크 모드만
`home-manager.nix`에서 dconf(`org/gnome/desktop/interface`)로 잡는다. GTK 설정
파일(settings.ini, gtk.css)은 이 레포가 쓰지 않는다 — DankMaterialShell이 같은
파일을 자기가 쓰면서 경합했던 이력이 있어 그쪽에 넘겼고, 테마 패키지만 Nix가
깐다(`home-manager.nix`의 gtk 관련 주석 참고).

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
- **Caps Lock 홀드 → 손 하나씩 나눠 쓰는 레이어** — 오른손은 윈도우 머신들이 쓰는
  [TouchCursor](https://github.com/martin-stone/touchcursor)와 같은 커서 배치(`ijkl` 역T
  화살표), 왼손은 마우스. 탭하면 평범한 Caps Lock 토글

| 오른손 | 동작 | | 왼손 (마우스) | 동작 |
|----|------|-|----|------|
| `i` `j` `k` `l` | ↑ ← ↓ → (역T) | | `w` `a` `s` `d` | 포인터 ↑ ← ↓ → |
| `u` / `o` | 줄 처음 / 끝 (`Home` / `End`) | | `⇧`+`wasd` | 같은 방향, 저속 |
| `h` / `n` | PageUp / PageDown | | `q` / `e` | 휠 위 / 아래 |
| `p` / `m` | `Backspace` / `Delete` | | `⇧q` / `⇧e` | 좌 / 우 스크롤 |
| `y` | `Insert` | | `f` / `r` | 왼쪽 / 오른쪽 클릭 |
| `/` | 찾기 (`C-f`) | | `8` `9` `0` | 왼쪽 / 가운데 / 오른쪽 버튼 |

클릭이 두 벌이다. `f`/`r`은 조향하는 손 안에 있어서 마우스 전체가 한 손으로 끝나고,
`8`/`9`/`0`은 반대 손이 놀고 있을 때 쓴다(가운데 버튼은 이쪽에만 있다). `f`와 `8`은 같은
센티넬로 나가므로 데몬은 둘이 있다는 걸 모른다.

왼손에는 원래 vim에서 빌려온 `w`/`e`/`b`(단어 이동)와 `g`/`G`(문서 처음·끝)가 있었고,
마우스에 자리를 내주면서 없앴다. 포인터 쪽 구현은 [아래](#포인터-pointer) 참고.

- **오른손 바인딩이 전부 unshifted**라 Shift는 통째로 선택 확장에 남는다 —
  `Caps+Shift+j` = 왼쪽으로 선택, `Caps+Shift+o` = 줄 끝까지 선택. vim 레이어는
  `$ { } G N`에서 Shift가 커맨드 자체였기 때문에 이게 구조적으로 불가능했다.
  왼손에서만 Shift가 의미를 갖고(저속·가로 스크롤), 그건 keyd가 아니라 데몬이 해석한다
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

### 포인터 (pointer)

**keyd는 포인터를 움직이지 못한다.** 아는 키 이름 319개 중 마우스는 `leftmouse` /
`middlemouse` / `rightmouse`와 `scroll{up,down,left,right}`이 전부고, REL_X/REL_Y를 내보내는
액션이 없다. 그래서 `keyboard.nix`의 왼손은 **비어 있는 F키 센티넬**로만 나가고
([`pointer/`](pointer/))의 데몬이 그걸 포인터로 바꾼다.

| 센티넬 | 키 | | 센티넬 | 키 |
|---|---|-|---|---|
| `F13`~`F16` | `w` `a` `s` `d` | | `F19` | `f`, `8` (왼쪽 클릭) |
| `F17` `F18` | `q` `e` | | `F24` | `r`, `0` (오른쪽 클릭) |
| | | | `F22` | `9` (가운데 클릭) |

- **읽기** — keyd의 출력 장치(`keyd virtual keyboard`)를 grab 없이 구독한다. 센티넬은 앱에도
  같이 도달하는데, **높은 F키는 보이는 것만큼 비어 있지 않다.** 기본 `us` 키맵이 F13~F18에
  `XF86Tools`/`XF86Launch5-9`, F20에 `XF86AudioMicMute`, F21~F23에 터치패드 토글을 얹고,
  평범한 심볼로 남는 건 **F19와 F24뿐**이다. 초안에서 가운데 버튼이 F20에 앉는 바람에 클릭할
  때마다 마이크가 음소거됐다 — niri가 `XF86AudioMicMute`를 잡고 있다
  ([`niri/rice/config.kdl`](niri/rice/config.kdl)). 그래서 평범한 둘은 제일 많이 쓰는 두 버튼에
  주고, F20/F21/F23은 아예 피했다. 옮기기 전에 확인:
  `xkbcli compile-keymap --layout us | grep FK`
- **쓰기** — 자기 uinput 포인터 하나. 이동·휠·버튼이 **같은 장치**로 나가야 "`8`을 잡은 채
  `wasd`로 드래그"가 한 덩어리로 도착한다
- **Shift를 데몬이 직접 본다** — keyd `[nav+shift]` 조합 레이어로 하면 안 된다. keyd는 키가
  *내려가는 순간* 바인딩을 확정하므로, 이미 눌려 있는 `w`를 나중에 느리게 만들 수 없다.
  오버슈트를 Shift로 잡는 게 저속 모드의 존재 이유라서 이 차이가 결정적이다
- **가속은 없다** — 700 px/s 등속, Shift를 누르면 100 px/s. 램프(200 → 1800 px/s)를 넣었다가
  뺐다: macOS의 Karabiner `mouse_key`는 가속 자체가 안 되니 유지하면 같은 레이어가
  머신마다 다르게 굴고, 정작 써보니 그 값을 치를 만큼 편하지도 않았다. 대각선은 벡터를
  정규화해서 `w+d`가 √2배 빨라지지 않는다
- **멈춤 방지** — 올라오지 않는 센티넬은 이동 15초 / 버튼 60초에 강제로 놓는다. root로 도는
  합성 포인터라 무한 이동이나 눌린 채 남은 버튼이 곧바로 시스템을 못 쓰게 만든다

속도 상수는 [`pointer/pointerd.py`](pointer/pointerd.py) 상단에 모여 있다. 숫자를 바꿔볼
때는 리빌드 대신 유닛을 세우고 파일을 직접 실행하면 된다(파일 헤더에 명령 있음).
상태는 `systemctl status pointerd`, 로그는 `journalctl -u pointerd`.

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
7840HS), `evo-t1`(GMKtec EVO-T1, Core Ultra 9 285H), `galaxy-chromebook-1` 셋이 있고,
새 호스트는 이들을 그대로 따라 하면 된다. CPU 벤더가 아니라 **머신 이름**으로 짓는다 —
같은 칩을 쓰는 기기가 둘 이상이면 `amd`나 `intel` 같은 이름은 바로 무너진다.

호스트 디렉토리는 **실제로 존재하는 머신**만 만든다. 그 머신에서 생성한 진짜
`hardware-configuration.nix` 없이는 호스트 항목이 아무 쓸모가 없고, placeholder를
커밋해두면 `nix flake check`만 깨진다. 예전에 있던 `intel` 호스트가 정확히 그 상태여서
제거했다.

벤더 공통 설정(예: AMD의 `radeontop`/전력 관리 주석, Intel의 thermald·VAAPI 드라이버)은
호스트 디렉토리가 아니라 [`amd.nix`](amd.nix)·[`intel.nix`](intel.nix) 같은 모듈에 두고
여러 호스트가 import한다. 호스트 디렉토리에는 그 섀시에만 해당하는 것만 남긴다 —
`intel.nix`는 실제로 그렇게 생겼다. `galaxy-chromebook-1`이 혼자 들고 있던 조각을,
두 번째 Intel 호스트(`evo-t1`)가 생긴 시점에 끌어올린 것이다.

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
