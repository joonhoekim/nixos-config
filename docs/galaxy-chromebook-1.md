# galaxy-chromebook-1

Galaxy Chromebook 1 에 NixOS 를 올린 호스트(`hosts/nixos/galaxy-chromebook-1/`). Intel(UHD 620), 팬리스 2-in-1,
Wacom 스타일러스와 터치스크린, 4K AMOLED 패널. 이 문서는 그 디렉토리 파일들의 전체 그림이다.

## 개요

- 전체 개발을 돌릴 성능이 아니라서 디스크를 많이 쓰는 개발 묶음과 그림·개발용 GUI 를 뺀다. core 의 CLI 와
  GUI(VS Code, ghostty 등)는 항상 깔린다. 무게는 [`packages/footprint.md`](packages/footprint.md), 지금 고른 것은
  `nix run .#inventory`.
- stateVersion(시스템·home 모두)은 실제로 설치한 릴리스 25.11 에 묶는다. stateVersion 은 상태 데이터 레이아웃을
  묶을 뿐 nixpkgs 채널이 아니라서, flake 는 여전히 nixos-unstable 을 따라가고 패키지는 계속 움직인다.
  `common.nix` 의 26.11 은 새로 설치하는 호스트를 위한 `mkDefault` 다.
- EFI: 이 기계의 NVRAM 에는 죽은 "Linux Boot Manager" 항목이 BootOrder 에서 살아 있는 항목보다 앞에 쌓일 수 있고,
  그러면 펌웨어가 `Booting from 'Linux Boot Manager' failed: Not Found` 를 찍은 뒤에야 넘어간다. `bootctl status` 는
  장치 경로를 풀 수 있는 항목만 보여서 바로 그 항목을 숨긴다. `efibootmgr -v` 로 보고 `efibootmgr -b <ID> -B` 로
  지운다. `efibootmgr` 는 `nix run` 이 아니라 설치해 둔다 — 부팅이 안 되는 기계는 패키지를 내려받기 나쁜 곳이다.
  경위는 [postmortem](postmortems/2026-08-14-galaxy-chromebook-1-efi-boot-entries.md).

## 내비게이션 레이어가 없는 이유

kanata 의 레이어(`modules/shared/kanata/nav.kbd`)는 Caps Lock 을 누르고 있는 데 걸린다([키맵](keymap.md)). 이 섀시에는 Caps
Lock 키가 없고 그 자리는 Chromebook 런처/검색 키인데, 그건 modifier 라 레이어를 실을 수 없다. Space 에 걸 수는
있지만 타이핑을 방해하지 않으려면 타이밍 가드가 붙어야 하고, 이 기계는 타이핑보다 브라우징을 훨씬 많이 한다.
그래서 이 호스트에는 레이어가 없다.

## 4K eDP 패널을 FHD 로 쓰기

eDP 는 노트북 내장 패널용 DisplayPort 이고, EDID 는 패널이 "나는 이 모드들을 받는다"고 알리는 정보 블록이다.
Samsung AMOLED(ATNA33TP04-0)의 EDID 는 detailed timing 을 하나(3840x2160@60)만 광고한다. 그래서 DRM 은 모드 하나만
내놓고, 컴포지터는 고를 것이 없다. 컴포지터 scale 은 UI 만 키우고 프레임버퍼는
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
- IIO 센서(가속도계, 자이로, 조도, cros_ec_sensorhub 의 lid-angle)는 subline 의 자동 회전과 태블릿 모드
  스위치에 필요하다.
- `services.xserver.wacom` 은 X11 의 xf86-input-wacom 드라이버다. Wayland 컴포지터는 펜을 libinput+evdev
  로 읽으므로 Xwayland 에만 의미가 있다. `services.xserver.dpi = 192` 도 컴포지터 scale 을 무시하는 Xwayland 앱용이고,
  Wayland 세션은 컴포지터의 모니터별 스케일을 쓴다.
- `home.nix` 의 Brave 플래그 중 `--top-chrome-touch-ui` 는 이 터치 기계 전용이다.

## 터치 자세: 화면 키보드, 자동 회전, 태블릿 모드

셋 다 subline 이 한다. 이 호스트가 더하는 것은 센서(`hardware.sensor.iio`, `hardware.nix`)와 아래 kanata 설정뿐이다.

- 자동 회전: subline 이 iio-sensor-proxy(`net.hadess.SensorProxy`)에서 방향을 받아 출력과 터치 입력을 같이 돌린다.
- 화면 키보드: subline 자체 OSK. 한글도 그 자판이 낸다.
- 태블릿 모드: subline 이 SW_TABLET_MODE 스위치를 읽는다.

### kanata 를 끄는 이유

libinput 은 SW_TABLET_MODE 스위치가 서면 내장 키보드와 터치패드를 알아서 끈다(libinput 문서 Switches) — 360도로
접히는 2-in-1 에서는 자판이 등 뒤로 가기 때문이다. kanata 가 돌면 이게 키보드에 안 먹는다. kanata 가 물리 키보드를
EVIOCGRAB 으로 잡고 자기 uinput 장치로 다시 내보내는데, libinput 이 보는 그 가상 키보드는 억제 대상이 아니다. 결과는
"접었는데 등 뒤 자판이 그대로 살아 있다" 다.

그래서 이 호스트는 `services.kanata.enable = false` 다(`default.nix`). 잃는 것은 없다. Caps 레이어는 걸 키가 없고(위
「내비게이션 레이어가 없는 이유」), Right Alt 한/영은 subline 의 xkb 옵션 기본값 `korean:ralt_hangul` 이 같은 Hangul
keysym 을 낸다([한국어 입력](korean-input.md)).
