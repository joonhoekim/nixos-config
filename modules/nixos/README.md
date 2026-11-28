# NixOS 모듈

NixOS 호스트에서만 쓰는 설정. 크로스 플랫폼 설정은 [`../shared`](../shared)에 있다.

## 구성

```
.
├── amd.nix              # AMD Ryzen/Radeon 공통 레이어 (AMD 호스트에서 import)
├── desktop.nix          # 세션 밖의 데스크톱 기반 (키링, 블루투스, upower, udisks2, avahi, gsettings 스키마)
├── gui-apps.nix         # GUI 앱 (core 는 늘, 나머지는 호스트의 local.guiApps) 과 기본 앱(mime)
├── home-manager.nix     # 유저 레벨 설정 (shared/home-manager.nix + GTK 테마 패키지 + mise 활성화)
├── intel.nix            # Intel CPU/iGPU 공통 레이어 (Intel 호스트에서 import)
├── kanata.nix           # kanata 키 리맵 (한/영, Caps Lock 홀드 레이어)
├── korean.nix           # 로케일, CJK 폰트
├── libvirt.nix          # Windows 게스트용 libvirt (import 하는 호스트에서만)
├── nautice.nix          # nautice 의 로컬 음성 (home-manager 쪽)
├── nginx.nix            # 로컬 리버스 프록시 (import 하는 호스트에서만)
├── packages.nix         # NixOS 전용 패키지 (shared/packages.nix + Linux 전용 도구)
├── rustdesk.nix         # 제어받는 쪽 RustDesk 서비스
├── subline/             # subline 세션 + 로그인 화면; 패키지·배선은 그 레포의 모듈, 올리기는 `nix run .#subline-update`
├── subline-terminal.nix # subline-terminal 패키지
├── tailscale.nix        # tailnet
├── thunar.nix           # Thunar 파일 관리자와 우클릭 액션
└── wireguard.nix        # WireGuard 도구
```

시스템 레벨 설정(부팅, 서비스, 유저 계정)은 이 디렉토리가 아니라
[`../../hosts/nixos/common.nix`](../../hosts/nixos/common.nix)에 있다.

## 데스크톱 환경

로그인은 greetd 이고 화면은 subline 이 그린다(`subline --greeter`; 끄면 tuigreet 로
돌아간다 — [`subline/`](subline)). 세션은 subline 하나이고, 자기 셸(스트립·독·OSK·알림·잠금)을
들고 있다. `services.xserver.enable`이 켜져 있지만 이건 Xwayland와 xkb 설정을
위한 것이지 X11 세션을 쓰기 위한 게 아니다.

데스크톱 환경 모듈을 켜지 않으므로 그런 모듈이 기본으로 켜 주는 기반은
[`desktop.nix`](desktop.nix)가 직접 켠다. 한 줄을 빼면 빌드는 통과하고 그 기능만 조용히
사라진다(각 줄의 주석에 누가 쓰는지 적혀 있다). 다크 모드와 강조색은 subline 이 gsettings 로
GTK 앱에 알리고, Nix 는 그 테마 패키지만 깐다(`home-manager.nix`).

## 한글 입력

`korean.nix`가 담당한다:

- **로케일** — UI는 `en_US.UTF-8`, 날짜/통화/주소 등 지역 포맷만 `ko_KR.UTF-8`
- **한/영 전환** — 오른쪽 Alt → `KEY_HANGEUL` 리맵. 실제 설정은 [`kanata.nix`](kanata.nix)에
  있다(아래 참고)
- **IME** — 따로 깔지 않는다. subline 내장 입력기가 한글을 조합해 Wayland text-input 으로 앱에 넘긴다
- **Chromium 계열** — Ozone Wayland 브라우저는 `--enable-wayland-ime` 플래그가 없으면
  한글이 안 들어간다. 예시는
  [`hosts/nixos/galaxy-chromebook-1/home.nix`](../../hosts/nixos/galaxy-chromebook-1/home.nix)
- **폰트** — Noto CJK / Nanum / D2Coding / Pretendard + fontconfig 폴백

## 키보드 리맵

전부 [`kanata.nix`](kanata.nix)의 kanata 가 담당한다. kanata 는 evdev 레벨(xkb *아래*)에서
동작하므로 subline / Xwayland / TTY 어디서나 똑같이 먹는다. **`services.xserver.xkb.options`는
쓰지 않는다** — Wayland 컴포지터는 자기 설정에서 키맵을 만들기 때문에 xkb 옵션은 X11 앱에만
닿는다. uinput 은 nixpkgs 의 kanata 모듈이 켠다.

레이어 본체는 [`../shared/kanata/nav.kbd`](../shared/kanata/nav.kbd)이고 Debian 태블릿과 같이
쓴다. `kanata.nix` 는 NixOS 에만 해당하는 것(기본 레이어, Right Alt, 잡지 않을 장치)만 둔다.
Windows·macOS 는 같은 배치를 `../shared/kanata/kanata.kbd` 로 건다 — 배치를 고치면 두 파일을
같이 고친다. 수치의 근거는 [`docs/kanata.md`](../../docs/kanata.md).

- **오른쪽 Alt → `KEY_HANGEUL`** — subline 내장 입력기가 이 키의 keysym(Hangul)으로 한/영을 토글한다
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
`8`/`9`/`0`은 반대 손이 놀고 있을 때 쓴다(가운데 버튼은 이쪽에만 있다).

- **오른손 바인딩이 전부 unshifted**라 Shift는 통째로 선택 확장에 남는다 —
  `Caps+Shift+j` = 왼쪽으로 선택, `Caps+Shift+o` = 줄 끝까지 선택.
  왼손에서만 Shift가 의미를 갖는다(저속·가로 스크롤)
- 매핑되지 않은 키는 홀드 중에도 **그냥 그 글자**가 입력된다(`process-unmapped-keys yes`)
- **트리거는 항상 Caps Lock** — 윈도우 TouchCursor에서 기본값(스페이스)에서 바꾸는 유일한
  설정이 이거라 여기서도 맞춘다. 스페이스 트리거는 타이핑 한복판에 있어서 타이밍 가드가
  필요한데, Caps Lock은 어차피 안 쓰는 키라 필요 없다
- **포인터는 kanata 가 직접 움직인다** — 자기 uinput 장치로 상대 이동·휠·버튼을 낸다. 700 px/s
  등속이고 Shift 를 누르면 100 px/s 다. 움직이는 도중에 Shift 를 눌러도 그 자리에서 느려진다
- **잡지 않을 장치** — kanata 는 키 1–115 중 하나라도 가진 장치를 전부 잡는다. 볼륨 키를 가진
  장치(gpio-keys)를 잡으면 그 장치의 스위치 이벤트가 조용히 사라지므로 이름으로 뺀다.
  새 기계에서는 `journalctl -u kanata-default -b | grep -E 'registering|excluded'` 로 확인한다
- **galaxy-chromebook-1 은 kanata 를 끈다** — 그 섀시엔 Caps Lock 키 자체가 없고(그 자리가
  런처/검색 키), kanata 가 키보드를 잡으면 libinput 의 태블릿 모드 키보드 억제가 안 먹는다.
  한/영은 subline 의 xkb 옵션이 낸다
  ([호스트 파일](../../hosts/nixos/galaxy-chromebook-1/default.nix)의 주석,
  [docs](../../docs/galaxy-chromebook-1.md))

nixpkgs 모듈이 빌드 때 `kanata --check` 를 돌리므로 문법 오류는 리빌드에서 걸린다. 상태는
`systemctl status kanata-default`, 로그는 `journalctl -u kanata-default`. 비상 탈출은 왼쪽
Ctrl + Space + Esc(kanata 가 끝난다).

## 호스트 추가하기

`hosts/nixos/` 아래 디렉토리 하나가 기계 한 대다. flake 가 이 디렉토리들을 읽으므로 따로
등록할 목록이 없고, 디렉토리 이름이 flake 타겟이자 `networking.hostName` 이 된다
(flake.nix 의 `mkNixosHost` 가 `mkDefault` 로 정한다). 호스트 파일에 `networking.hostName` 을
또 적지 않는다 — 어긋나면 `apps/build-switch` 가 인자 없이 `hostname` 으로 고른 타겟이 안 맞는다.
지금 있는 호스트는 `ls hosts/nixos/`, 각자 고른 것은 `nix run .#inventory`.

이름은 CPU 벤더가 아니라 **기계 이름**으로 짓는다 — 같은 칩을 쓰는 기기가 둘이 되면
`amd`·`intel` 같은 이름은 바로 안 맞는다.

호스트 디렉토리는 **실제로 존재하는 기계**만 만든다. 그 기계에서 생성한
`hardware-configuration.nix` 가 없으면 `fileSystems` assertion 으로 `nix flake check` 가 깨진다.

벤더 공통 설정(Intel 의 thermald·VAAPI 드라이버 같은 것)은 호스트 디렉토리가 아니라
[`amd.nix`](amd.nix)·[`intel.nix`](intel.nix) 같은 모듈에 두고 여러 호스트가 import 한다.
호스트 디렉토리에는 그 섀시에만 해당하는 것만 남긴다.

새 기계에서는 `./apps/setup` 이 아래를 해 준다. 손으로 하면:

1. `hosts/nixos/<이름>/identity.nix` — 쓸 사람을 가리키는 한 줄 ([users/README.md](../../users/README.md)).

2. `hosts/nixos/<이름>/default.nix`:

   ```nix
   { ... }:
   {
     imports = [
       ../common.nix
       ./hardware-configuration.nix
     ];

     # 이 기계를 처음 설치한 릴리스(nixos-generate-config 가 쓴 값).
     system.stateVersion = "<릴리스>";
     # 머신별 튜닝(GPU 드라이버 등)은 여기에.
   }
   ```

3. **그 기계에서** hardware-configuration.nix 를 생성한다. 루트/부트 파일시스템, 스왑,
   initrd 커널 모듈, CPU 마이크로코드를 고정하므로 반드시 실기에서 뽑는다:

   ```sh
   sudo nixos-generate-config --show-hardware-config \
     > hosts/nixos/<이름>/hardware-configuration.nix
   ```

4. `git add hosts/nixos/<이름>` — flake 는 추적되지 않는 파일을 못 본다.

5. 빌드. hostname 이 아직 디렉토리 이름과 다르면 첫 번째만 `--host` 를 준다:

   ```sh
   nix run .#build-switch -- --host <이름>
   ```

### 이미 설치된 머신을 편입할 때

`common.nix`의 `system.stateVersion`과 `home-manager.nix`의 `home.stateVersion`은 둘 다
`lib.mkDefault` 로 둔 *새로* 설치하는 호스트의 기준값이다. 이미 돌고 있는 머신을 가져올
때는 그 머신이 설치된 릴리스로 호스트에서 덮어써야 한다:

```nix
system.stateVersion = "<설치한 릴리스>";
home-manager.users.${user}.home.stateVersion = "<설치한 릴리스>";
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
