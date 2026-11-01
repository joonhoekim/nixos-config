# galaxy-chromebook-1

Galaxy Chromebook 1 에 NixOS 를 올린 호스트(`hosts/nixos/galaxy-chromebook-1/`). Intel(UHD 620), 팬리스 2-in-1,
Wacom 스타일러스와 터치스크린, 4K AMOLED 패널. 이 문서는 그 디렉토리 파일들의 전체 그림이다.

## 개요

- 전체 개발을 돌릴 성능이 아니라서 디스크를 많이 쓰는 개발 묶음과 그림·개발용 GUI 를 뺀다. core 의 CLI 와
  GUI(VS Code, ghostty)는 항상 깔린다. 무게는 [`packages/footprint.md`](packages/footprint.md), 지금 고른 것은
  `nix run .#inventory`.
- stateVersion(시스템·home 모두)은 실제로 설치한 릴리스 25.11 에 묶는다. stateVersion 은 상태 데이터 레이아웃을
  묶을 뿐 nixpkgs 채널이 아니라서, flake 는 여전히 nixos-unstable 을 따라가고 패키지는 계속 움직인다.
  `common.nix` 의 26.11 은 새로 설치하는 호스트를 위한 `mkDefault` 다.
- 파일 나눔: `hardware.nix` 는 "이 하드웨어가 이래서 이 줄이 있다", `touch.nix` 는 "이 하드웨어로 무엇을 하겠다".
- EFI: 이 기계의 NVRAM 에는 죽은 "Linux Boot Manager" 항목이 BootOrder 에서 살아 있는 항목보다 앞에 쌓일 수 있고,
  그러면 펌웨어가 `Booting from 'Linux Boot Manager' failed: Not Found` 를 찍은 뒤에야 넘어간다. `bootctl status` 는
  장치 경로를 풀 수 있는 항목만 보여서 바로 그 항목을 숨긴다. `efibootmgr -v` 로 보고 `efibootmgr -b <ID> -B` 로
  지운다. `efibootmgr` 는 `nix run` 이 아니라 설치해 둔다 — 부팅이 안 되는 기계는 패키지를 내려받기 나쁜 곳이다.
  경위는 [postmortem](postmortems/2026-08-14-galaxy-chromebook-1-efi-boot-entries.md).

## 내비게이션 레이어가 없는 이유

`modules/nixos/keyboard.nix` 의 레이어는 Caps Lock 을 누르고 있는 데 걸린다([키맵](keymap.md)). 이 섀시에는 Caps
Lock 키가 없고 그 자리는 Chromebook 런처/검색 키인데, 그건 modifier 라 레이어를 실을 수 없다. Space 에 걸 수는
있지만 타이핑을 방해하지 않으려면 타이밍 가드가 붙어야 하고, 이 기계는 타이핑보다 브라우징을 훨씬 많이 한다.
그래서 이 호스트에는 설정할 것도 없다.

## 4K eDP 패널을 FHD 로 쓰기

eDP 는 노트북 내장 패널용 DisplayPort 이고, EDID 는 패널이 "나는 이 모드들을 받는다"고 알리는 정보 블록이다.
Samsung AMOLED(ATNA33TP04-0)의 EDID 는 detailed timing 을 하나(3840x2160@60)만 광고한다. 그래서 DRM 은 모드 하나만
내놓고, niri 는 고를 것이 없으며, DMS 의 해상도 드롭다운은 비어 있다. 컴포지터 scale 은 UI 만 키우고 프레임버퍼는
4K 그대로라 소용이 없고, UHD 620 은 4K 합성을 버거워한다.

세 조각이 함께 일한다.

1. **커널 패치** `kernel/i915-edp-scaled-modes.patch` — i915 는 eDP 커넥터에서 패널 고정 모드와 해상도가 다른
   모드를 전부 버린다. 드라이버의 나머지는 이미 작은 모드를 패널 피터(panel fitter, 하드웨어 스케일러)로 키울 줄
   안다(패치 머리말). 커널을 올릴 때마다 로컬에서 전체 빌드한다.
2. **`video=eDP-1:1920x1080@60`** — 커넥터의 목록에 모드를 **더하고** EDID 는 건드리지 않는다. eDP 에서는 이 차이가
   전부다. i915 는 eDP 패널의 *preferred* 타이밍을 네이티브 타이밍으로 보고 링크를 그걸로 몰며, 더 작은 모드는
   패널 피터로 그 위에 키운다. 3840x2160 이 preferred 로 남으면 1080p 는 스케일된 모드가 되고, 1080p 가 preferred
   가 되면 i915 는 패널이 정말 1080p 라고 결론 내려 고정 화소 4K 패널에 1080p 타이밍을 보내고 패널은 아무것도
   안 띄운다.
3. **`display-try`** — 재빌드 없이 다른 표시 설정으로 다시 시작한다. 아래 절.

까만 화면이 되면 부팅 메뉴에서 이전 세대를 고른다.

### EDID 를 통째로 바꾸지 않는 이유

`drm.edid_firmware` 로 EDID 를 통째로 바꿔 부팅하면 greetd 까지 i915 오류 없이 올라오지만 패널은 내내 까맣다
(2026-08-02 확인). 1080p 를 preferred 로 만드는 블롭은 모두 위 2번의 결함을 가진다.

### debugfs 의 edid_override 가 안 되는 이유

`/sys/kernel/debug/dri/*/eDP-1/edid_override` 는 외부 HDMI/DP 에서는 먹지만 eDP 에서는 무력하다. i915 는 고정 모드
목록을 커넥터 초기화 때 한 번 만들고 reprobe 때 다시 만들지 않는다. override 는 저장되지만(128 바이트를 다시
읽힌다) 실제 커넥터 EDID 는 패널 자신의 256 바이트 그대로다. 그래서 `display-try` 는 kexec 를 한다.

### EDID 후보 블롭

최신 커널에는 내장 범용 EDID 블롭이 없다. `CONFIG_DRM_LOAD_EDID_FIRMWARE` 는 *로더*만 켜고, 로더는
/lib/firmware/edid/ 에서 아무것도 못 찾으면 -2 로 실패한다. 그래서 직접 만들어 `hardware.firmware` 에 싣는다.
지금은 `video=` 가 주 방식이고 블롭은 대체용이지만, `display-try` 가 재빌드 없이 어느 것으로든 kexec 할 수 있어서
두는 비용이 작다.

| 파일 | 내용 | 결과 |
|---|---|---|
| `1920x1080.bin` | 범용, CEA-861 1080p60 | 1080p 가 preferred |
| `1920x1080rb.bin` | 범용, CVT reduced-blanking(픽셀 클럭이 낮다) | 1080p 가 preferred |
| `panelfhd2.bin` | 패널 자신의 EDID, DTD 2 를 1080p 로 | 4K 가 preferred 로 남는 유일한 블롭. 시험해 볼 가치가 있는 것은 이것뿐 |
| `panelfhd.bin` | 패널 자신의 EDID, DTD 1 을 1080p 로 | greetd 까지 오고 패널은 까맣다. 음성 결과를 재현할 수 있게만 남긴다 |

- `edid-generator` 의 `clean = true` 는 같이 들어 있는 프리셋을 빼고 적힌 modeline 만 빌드한다. .bin 이름은
  modeline 이름에서 오고, 커널 인자가 그 이름을 쓴다.
- 범용 블롭은 edid-generator 템플릿에 박힌 사정 때문에 자기를 *아날로그*로 선언한다. 패널 유래 블롭은 실제 vendor
  블록을 지녀서 커넥터가 여전히 10bpc 디지털 DisplayPort 싱크로 읽힌다.
- 패널 유래 블롭은 `compressFirmware = false` 로 평범한 .bin 으로 둔다. 커널은 .zst 도 풀지만 `display-try` 가 모든
  후보를 예측 가능한 한 이름으로 찾게 하려는 것이다.

### make-panel-fhd.py 의 슬롯

`edid/make-panel-fhd.py <panel-native.hex> <out.bin> <1|2>` 는 패널의 두 DTD(detailed timing descriptor, 둘 다
3840x2160) 중 하나를 1920x1080 으로 다시 쓴다.

- **슬롯 2**: DTD 1 이 3840x2160 으로 남아 preferred 를 유지한다. i915 가 그걸 네이티브로 보고 링크를 몰고,
  1080p 는 목록의 추가 항목이 된다. 실제로 될 수 있는 배치다.
- **슬롯 1**: DTD 1 이 1920x1080 이 되어 preferred 가 된다. greetd 까지 깔끔하게 부팅되지만 패널은 까맣다(확인함).
  음성 결과로만 남기고 기본값으로 삼지 않는다.

그 밖은 바이트 그대로 둔다: vendor 블록, 디지털/DisplayPort 플래그, 10bpc, 색도, 제품명 descriptor, CTA-861 확장
블록(HDR 메타데이터를 싣지만 비디오 모드는 없어서 2160p 를 목록에 몰래 되돌리지 못한다). 기본 블록의 체크섬만
다시 계산하고, 확장 블록은 손대지 않아 자기 체크섬을 유지한다. 물리 크기는 원래 DTD 의 값을 다시 써서 DPI 기반
자동 스케일이 맞게 나온다.

## display-try

i915 는 두 손잡이(`video=`, `drm.edid_firmware=`)를 eDP 커넥터를 초기화할 때만 읽으므로, 무엇을 시험하든 커널을
다시 시작해야 한다. `display-try` 는 그걸 kexec(커널에서 커널로 바로 갈아타기)로 해서 펌웨어 POST 를 건너뛰고 콜드
부팅 대신 몇 초 만에 끝낸다. 아무것도 남지 않는다 — 다음 평범한 부팅은 `boot.kernelParams` 대로 돌아가므로, 패널을
까맣게 만들 수도 있는 것을 시험하는 안전한 방법이다.

```
display-try list          대상과 지금 돌고 있는 것
display-try video         video=eDP-1:1920x1080@60 (모드를 더한다)
display-try panelfhd2     그 EDID 블롭 (EDID 를 바꾼다)
display-try off           둘 다 없음 (복구)
```

끝난 뒤 확인: `cat /sys/class/drm/card1-eDP-1/modes`

## 터치패드 팬텀 터치

이 개체의 Synaptics 터치패드(Synaptics TM3579-001)는 팬텀 터치가 난다. 기본은 켜짐(커널 기본 inhibited=0)이고,
증상이 나면 `touchpad off` 로 소스에서 끊는다. `touchpad on|off|toggle|status` 는 커널 inhibit 플래그
(/sys/class/input/inputN/inhibited)를 직접 쓴다. 이 속성은 모든 evdev 노드에 있으므로 컴포지터와 무관하고, 아래
udev 규칙이 있든 없든 동작한다.

부팅부터 꺼 두고 싶으면 libinput 이나 컴포지터가 아니라 udev 에 건다. 컴포지터 설정은 세션에만 걸려 그리터와
TTY 에 안 먹고, 재개(resume)와 재열거 때 다시 걸리지 않는다 — 증상은 "껐는데 뚜껑 닫았다 열면 다시 살아 있다" 다.
udev 는 입력 노드가 나타나는 매 순간 건다.

```nix
services.udev.extraRules = ''
  SUBSYSTEM=="input", KERNEL=="input*", \
    ATTR{name}=="Synaptics TM3579-001", ATTR{inhibited}="1"
'';
```

## 기타 하드웨어 메모

- `hardware.nix` 는 이 섀시에만 해당하는 것을 둔다. 벤더 중립 도구는 `modules/nixos/packages.nix`, Intel 공통
  (thermald, iHD VAAPI 드라이버, intel_gpu_top/cpupower, intel_pstate 메모)은 `modules/nixos/intel.nix`
  ([벤더 공통 층](hardware-vendors.md))에 있고 `default.nix` 가 import 한다.
- thermald 는 이 기계가 팬리스라 어느 호스트보다 중요하지만 섀시 고유는 아니라서 `intel.nix` 에 있다.
- IIO 센서(가속도계, 자이로, 조도, cros_ec_sensorhub 의 lid-angle)는 GNOME 의 자동 회전·자동 밝기·태블릿 모드
  스위치에 필요하다.
- `services.xserver.wacom` 은 X11 의 xf86-input-wacom 드라이버다. Wayland 에서 GNOME/Mutter 는 펜을 libinput+evdev
  로 읽으므로 Xwayland 에만 의미가 있다. `services.xserver.dpi = 192` 도 컴포지터 scale 을 무시하는 Xwayland 앱용이고,
  Wayland 세션은 GNOME 의 모니터별 스케일을 쓴다.
- `home.nix` 의 Brave 플래그 중 `--top-chrome-touch-ui` 는 이 터치 기계 전용이다.

## 터치 자세: 화면 키보드, 자동 회전, 태블릿 모드

저장소에서 터치스크린이 있는 기계는 이것뿐이다. 컴포지터 쪽 설정은 그래도
`modules/nixos/hyprland/rice/hyprland.lua` 에 있다 — 라이싱 파일이라 호스트별로 가를 수단이 없고, 터치 장치가 없는
기계에서는 무해하게 죽는 줄들이다([hyprland.lua 의 입력 절](hyprland.md#입력)).

`touch.nix` 가 까는 CLI 넷과 DankBar 조각(`local.dms.touchControls`, [DMS 플러그인](dms-plugins.md#touchcontrols)):

| 명령 | 하는 일 | 상태를 아는 법 |
|---|---|---|
| `osk on\|off\|toggle\|status` | 화면 키보드 wvkbd 를 보이고 감춘다(USR2 켜기, USR1 끄기, SIGRTMIN 토글) | 컴포지터에게 묻는다 |
| `autorotate on\|off\|toggle\|status` | 자동 회전(USR2/USR1, 토글 신호 없음) | 데몬이 쓴 `$XDG_RUNTIME_DIR/hypr-autorotate.state` |
| `tablet-mode enter\|leave\|status\|is-on` | 접고 펴는 한 번에 키보드·터치패드·회전·자판을 같이 움직인다 | 키보드 inhibit 값 |
| `touch-state` | 세 토글의 상태를 JSON 하나로 | 위 셋을 부른다 |

### osk: 서비스는 늘 떠 있고 신호만 보낸다

wvkbd(Wayland 화면 키보드)는 시작할 때 54 개 레이아웃을 컴파일하므로 띄웠다 죽였다 하면 손가락으로 쓰기엔 느리다.
wvkbd 에게 상태를 물을 방법은 없어서 `status` 는 컴포지터에게 묻는다. 자판이 보이면 `wvkbd` 네임스페이스의 레이어가
올라와 있고 감추면 통째로 사라진다(`hyprctl layers -j`, 실측). 자판은 Mod+B, 태블릿 모드 훅, 자판 안의 hide
키로도 움직이므로 어딘가 적어 둔 값은 금방 낡는다. 신호는 pkill 이 아니라 `systemctl --user kill
--kill-whom=main` 으로 보낸다(유닛 cgroup 안으로만 가서 이름이 겹치는 남의 프로세스를 때리지 않는다). SIGRTMIN 도
이름으로 받는다(실측).

### 한글

wvkbd 는 레이아웃을 컴파일 타임에 박는다. 패키징된 묶음은 mobintl 뿐이고(deskintl 은 nixpkgs 에 없다) 한글 자판은
없다. 없어도 된다 — wvkbd 는 virtual-keyboard-v1 로 **키코드**를 쏘고 fcitx5 는 그 위에서 텍스트를 받으므로 물리
키보드와 구분하지 않는다. 두벌식 변환은 `modules/nixos/korean.nix` 의 hangul 엔진이 한다([한국어 입력](korean-input.md)).
화면에서 한/영은 **Ctrl+space** 다 — 그쪽 Hotkey/TriggerKeys 의 두 번째 항목이고, 첫 번째(Hangul keysym)는 이 자판에
키가 없다.

### 왜 wvkbd --auto 를 안 쓰는가

`--auto` 는 텍스트 필드에 포커스가 가면 저절로 뜨게 하는 옵션으로, 터치 기계에서 제일 갖고 싶은 동작이다. 그런데 그
기능은 `zwp_input_method_v2` 로 구현돼 있고, 그 자리는 fcitx5 가 이미 잡고 있다(`korean.nix` 의
`waylandFrontend = true`). 한 시트에 input method 는 하나다.

```
wayland-info | grep input_method
#  interface: 'zwp_input_method_manager_v2', version: 1, name: 28
```

둘이 다투면 지는 쪽이 조용히 진다. 한글 입력은 이 기계에서 제일 비싼 축이라
([postmortem](postmortems/2026-08-05-vscode-terminal-hangul.md)) 그걸 걸고 자동 표시를 사지 않는다. 여기서 쓰는
virtual-keyboard-v1 경로는 덧붙이기만 해서 fcitx5 와 겹치지 않는다. 자동 표시는 태블릿 모드 훅이 대신한다 — 화면을
접으면 뜬다.

### 자판이 창을 밀지 않는다

wvkbd 는 overlay 레이어에 exclusive zone 없이 뜬다(`hyprctl layers` 로 확인: `namespace: wvkbd`, `Layer level 3
(overlay)`). 자판이 창 위를 덮을 뿐 밀어 올리지 않아서 화면 아래쪽 입력란은 가려진다. 상류가 그렇게 만든 것이고
옵션으로 못 바꾼다.

### wvkbd 서비스

- `partOf`/`after` 는 `graphical-session.target` — 로그아웃 때 같이 내려간다(dms.service 와 같은 모양).
- `wantedBy` 는 타깃이 아니라 컴포지터 유닛(`niri.service`, `wayland-wm@hyprland.desktop.service`). 타깃에 걸면
  GNOME 세션에서도 뜨는데, 그쪽은 자기 화면 키보드가 있다.
- `-L 260 -H 340`: -L 은 가로 모드 높이, -H 는 세로 모드 높이. 1920x1080 에서 260 은 화면의 24% 로 네 줄 자판이
  손가락에 맞는 최소치쯤이고, 세로(1080x1920)는 같은 비율이 훨씬 큰 픽셀이라 340 을 따로 준다.

### 태블릿 모드에서 키보드를 우리가 끄는 이유

libinput 은 SW_TABLET_MODE 스위치가 서면 내장 키보드와 터치패드를 알아서 끈다(libinput 문서 Switches) — 360도로
접히는 2-in-1 에서는 자판이 등 뒤로 가기 때문이다. 이 기계에서는 키보드에 안 먹는다. keyd 가 /dev/input/event0 을
EVIOCGRAB 으로 잡고(`lsof` 로 확인된다) 자기 uinput 장치로 다시 내보내기 때문이다. libinput 이 보는 것은
`keyd-virtual-keyboard` 인데, 가상 장치라 억제 대상이 아니다. 억제되는 `at-translated-set-2-keyboard` 는 이미 keyd 가
잡고 있어서 원래 아무 이벤트도 안 흘린다. 결과는 "접었는데 등 뒤 자판이 그대로 살아 있다" 다.

그래서 keyd 보다 아래인 커널 inhibit 로 끊는다. 물리 장치가 막히면 keyd 가 읽을 것이 없어지고 그 위의 가상 키보드도
조용해진다. `tablet-mode` 를 부르는 것은 사람이 아니라 하이프랜드의 스위치 바인드다(`rice/hyprland.lua` 의 태블릿
모드 절).

- `enter` 는 터치패드의 지금 inhibit 값을 적어 두고 끄며, `leave` 는 그 값으로 복원한다. 팬텀 터치 때문에 손으로 건
  `touchpad off` 를 접었다 펴는 것만으로 풀지 않기 위해서다.
- `enter` 는 자판도 띄운다. 접힌 상태에서는 Mod+B 를 누를 손이 없고, 감추는 것은 자판 안의 hide 키로 된다.
- `is-on` 은 스위치(`/dev/input/event6`)가 아니라 키보드가 막혀 있는지로 판정한다. 스위치는 root 가 있어야 읽히고,
  손으로 `tablet-mode enter` 를 부른 경우엔 스위치가 서 있지 않아 그쪽을 믿으면 UI 가 실제와 어긋난다.

### autorotate

기본은 꺼짐이고 켜는 것은 태블릿 모드 훅이다. 노트북 자세에서 켜 두면 책상에서 타이핑하다 화면이 돌아간다. 상태
파일 경로(`%t/hypr-autorotate.state`, %t = $XDG_RUNTIME_DIR)는 데몬과 CLI 가 따로 적고 있어서 한쪽만 고치면 status
가 영원히 "unknown" 이 된다.

### touch-state 와 DMS 플러그인

DMS 플러그인은 `touch-state` 만 부른다. QML 쪽에 상태 읽는 법을 적지 않는 것은 RiceSwitcher 가 `apps/rice/menu`
에게 목록을 통째로 받아 오는 것과 같은 방향이다 — 판정이 늘거나 바뀌어도 QML 은 그대로다. 조각은 위 CLI 를 손가락으로
부르는 유일한 길이라 CLI 를 까는 `touch.nix` 에서 켠다.

## autorotate.py 설계

`touch.nix` 가 systemd user service(`hypr-autorotate`)로 띄우고, `autorotate` CLI 가 신호로 켜고 끈다. 방향은
iio-sensor-proxy(IIO 센서를 D-Bus 로 노출하는 데몬)에게서 받는다.

### 왜 iio-hyprland 가 아닌가

nixpkgs 에 있고 하는 일도 정확히 이것인데 이 설정에서는 한 줄도 안 먹는다. 그쪽은 전부 `hyprctl keyword` 로 말하고,
하이프랜드 0.56 은 Lua 설정에서 그걸 거부한다.

```
$ hyprctl keyword input:touchdevice:transform 0
keyword can't work with non-legacy parsers. Use eval.
```

거부하면서 **종료 코드는 0** 이라 그쪽 데몬은 실패한 줄 모르고 계속 돈다. 증상은 "서비스는 active 인데 화면이 안
돈다" 하나뿐이다. 그래서 같은 일을 `hyprctl eval` 로 다시 쓴다.

### 왜 가속도계를 직접 안 읽는가

/sys/bus/iio 에 accel-display / accel-base 가 그대로 있어서 raw 값으로 각도를 풀 수도 있다. 안 하는 이유는 마운트
행렬이다 — 센서가 패널에 어느 방향으로 붙었는지는 펌웨어가 알려주는 값이고, iio-sensor-proxy 가 그걸 읽어 방향
문자열까지 풀어 준다. 직접 풀면 그 보정을 다시 구현해야 하고, 틀렸을 때 증상은 "90도씩 어긋나게 돈다" 라 눈으로
맞출 때까지 모른다.

### 클레임은 커넥션에 묶인다

ClaimAccelerometer 는 부른 **DBus 커넥션**이 살아 있는 동안만 유효하다. 셸에서 `busctl call` 로 부르면 그 프로세스가
끝나는 순간 풀리고, iio-sensor-proxy 는 (전력 때문에) 센서 폴링을 멈춘다. 그래서 이 파일은 파이썬 데몬이다
(`pygobject3` 의 GDBus). 클레임을 안 하면 AccelerometerOrientation 은 마지막 값에 머물고 PropertiesChanged 도 안 온다.

### 신호

파이썬의 signal 핸들러는 다음 바이트코드가 돌아야 실행되는데, 이 프로세스는 대부분 GLib 의 poll 안에 있으므로
신호가 몇 초씩 늦거나 다음 DBus 이벤트까지 안 온다. 그래서 `GLibUnix.signal_add` 로 받는다. 그 함수가 받는 신호는
SIGHUP/INT/TERM/USR1/USR2/WINCH 로 정해져 있고, 그 밖의 것을 주면 assertion 을 찍고 핸들러를 안 건다 — 서비스는
도는데 그 신호만 조용히 사라진다. `osk` 가 토글에 쓰는 SIGRTMIN 을 여기선 못 쓰는 이유이고, `autorotate toggle` 은
상태 파일을 읽어 USR1/USR2 중 하나를 보낸다.

### 회전 적용

하이프랜드는 출력이 돌아갈 때 매핑된 입력을 따라 돌리지 **않는다**(sway 와 다른 점). 모니터만 돌리면 화면은 세로인데
터치는 가로로 남아 찍은 자리에서 90도 떨어진 곳이 눌린다. 그래서 모니터·touchdevice·tablet 셋을 `hyprctl eval` 한
번에 보낸다. transform 0/1/2/3 은 Normal/90/180/270 이고 wlroots 계열이 다 같은 뜻으로 쓴다. "undefined"(평평하게
눕혀 센서가 판단 못 함)일 때는 마지막 방향을 둔다. 방향마다 저널에 한 줄씩 남기므로, 화면이 엉뚱하게 돌면
`journalctl --user -fu hypr-autorotate` 가 어느 문자열에 어느 각도를 줬는지 보여주고 고칠 자리는 `TRANSFORM` 표
한 곳이다.
