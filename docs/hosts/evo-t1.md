# evo-t1

GMKtec EVO-T1 미니 PC. 이 문서는 `hosts/nixos/evo-t1/default.nix` 의 각 줄이 왜 있는지와,
첫 부팅 때 확인한 하드웨어 사실을 모은다. 코드에는 그 줄이 없으면 무엇이 깨지는지만 남긴다.

## 기계 개요

- 모델: NucBox_EVO-T1, 보드 V1.1, 펌웨어 V2.03 (2025-12-16)
- CPU: Core Ultra 9 285H (Arrow Lake-H). 16코어/16스레드, SMT 없음, 400 MHz~5.4 GHz
- GPU: Arc 140T iGPU. NPU: NPU 4 ("Intel AI Boost")
- 메모리: 64 GB (32 GB DDR5-5600 ×2)
- 팬으로 식히고, 배터리 없이 늘 AC 전원에 물려 있다.

벤더 공통 Intel CPU/GPU 설정은 `modules/nixos/intel.nix`([벤더 공통 층](../hardware-vendors.md))에 있고,
`default.nix` 에는 이 섀시에만 해당하는 것만 둔다. 처음 짐작과 실제가 달랐던 항목은 따로 표시했다
(네트워크 절).

`modules/nixos/nginx.nix`(mn56 에서만 쓰는 회사 작업 설정, [nginx](../nginx.md))는 일부러 import 하지 않는다.

## stateVersion

stateVersion 은 "이 기계의 상태 데이터가 만들어진 릴리스"이지 "따라가는 채널"이 아니다. flake 는 계속
nixos-unstable 을 따라가므로 패키지는 그대로 새 버전으로 올라간다.

- `system.stateVersion = "26.05"`: 26.05 설치본으로 깔았다(설치 미디어에서 `nixos-version` 으로 확인).
  새로 설치한 기계가 common.nix 의 `mkDefault 26.11` 을 받으면 안 된다.
- `home.stateVersion` 은 기본값 26.11(`modules/nixos/home-manager.nix`)로 둔다. 이 기계에는
  home-manager 상태가 없었으므로, 첫 활성화 때 26.05 시절 호환 shim 이 아니라 지금 기본값을 받는 편이 맞다.
  두 값은 서로 상관없이 정한다.

## GPU: i915 가 맞는 경로다

00:02.0 은 [8086:7d51], lspci 이름은 "Arrow Lake-P [Arc Pro 130T/140T]". i915 와 xe 가 둘 다 이 장치를
지원 목록에 올려 두지만 **실제로 붙는 것은 i915** 다. 경쟁의 결과가 아니라 설계다: Arrow Lake-H 는
Meteor Lake 의 Xe-LPG 그래픽·디스플레이 IP 를 그대로 쓰므로 i915 는 이 장치를 `meteorlake`, display
version 14.00 stepping D0 로 인식한다. xe 는 Lunar Lake(Xe2)부터 맡는다.

force_probe 도 펌웨어 수작업도 없이 전부 알아서 올라온다:

| 블롭 | 파일 / 버전 | 역할 |
|---|---|---|
| DMC | i915/mtl_dmc.bin v2.23 | 디스플레이 전원 관리 |
| GuC | i915/mtl_guc_70.bin 70.53.0 | GT0·GT1 둘 다, submission + SLPC + RC |
| HuC | i915/mtl_huc_gsc.bin 8.5.4 | "authenticated for all workloads" |
| GSC | i915/mtl_gsc_1.bin r102.1.15.1926 | |

눈여겨볼 것은 HuC 다. 저전력 고정기능 영상 인코딩을 fallback 이 아니라 진짜로 쓰게 해 주는 것이 HuC 이고,
GSC 가 1초쯤 뒤에 다 올라온 다음에야 "for all workloads" 가 찍힌다. gfx 접근에 VT-d 가 켜져 있다.

VAAPI(리눅스의 하드웨어 영상 가속 API) 확인: iHD 26.1.6 / VA-API 1.24. AV1, HEVC(4:4:4 12-bit 와 SCC 까지),
VP9, H.264 를 디코드·인코드 둘 다 지원한다. 드라이버는 `modules/nixos/intel.nix` 가 넣는다.

card1 에 출력이 다섯 개(DP-1, DP-2, DP-3, HDMI-A-1, HDMI-A-2) 있고, 지금 쓰는 것은 DP-1 이다.

`xe.force_probe=` 를 주면 드라이버가 xe 로 바뀌지만 그럴 이유가 없다. 성숙한 드라이버를 버리고 이
하드웨어를 대상으로 하지 않는 새 드라이버로 가는 셈이고, 위의 기능은 이미 다 된다.

## thermald 를 끈 이유

thermald 는 펌웨어의 열 관리 표(DPTF)를 읽어 CPU 를 스로틀링하는 데몬이다. 2.5.12 는 CPU 표
(`src/thd_platform_intel.cpp`)에서 Arrow Lake(6:197)를 adaptive_only 로 둔다. adaptive 모드는 펌웨어 DPTF
표에 GDDV 가 있어야 하는데 이 펌웨어에는 없다. 그러면 기본 엔진으로 넘어가고, 함께 들어 있는
thermal-conf.xml 에 맞는 플랫폼이 없어 기본 엔진이 이 CPU 를 거부한다("Unsupported cpu model ... THD
engine init failed", exit 2). 서비스가 부팅할 때마다 실패하고, switch 자체는 성공했는데도
`nixos-rebuild switch` 가 exit 4 로 끝난다.

`services.thermald.ignoreCpuidCheck` 로 다시 돌게 할 수는 있지만, 상류가 이 CPU 에서 빼 둔 모드를 억지로
쓰는 것이다. 스로틀링은 펌웨어와 커널의 thermal zone 에 맡긴다.

## DP-1 모니터: 스피커

DP-1 에는 HCS 40LGD5K(5120x2160, USB-C DP Alt Mode)가 물려 있고, 이 패널에는 스피커가 있다. 커널도
스피커를 본다: `/proc/asound/card0/eld#2.12` 에 monitor_present 1, eld_valid 1, monitor_name 40LGD5K,
connection_type DisplayPort, speakers FL/FR, 2ch LPCM SAD 하나. PipeWire 도 해당 포트 hdmi-output-0 을
"available"(device.product.name "40LGD5K")로 잡는다. 그런데 설정 없이는 sink 로 나타나지 않는다.

원인: 이 기계의 코덱 두 개(아날로그 잭을 맡는 Senarytech SN6186, 디스플레이를 맡는 Meteor Lake HDMI
코덱)가 ACP 카드 하나(`alsa_card.pci-0000_00_1f.3`) 뒤에 있고, 카드 프로필은 한 번에 하나만 쓸 수 있다.
WirePlumber(PipeWire 의 세션 매니저)는 프로필 우선순위로 고르는데 analog duplex(6565)가 HDMI(5965)보다
높다. 그러면 HDMI sink 는 아예 만들어지지 않는다. 모니터 스피커를 못 알아보는 것이 아니라, sink 가 생기기
전에 우선순위에서 밀린 것이다.

`device.profile.priority.rules` 가 WirePlumber 가 이런 경우에 쓰라고 둔 자리다
(`scripts/device/find-preferred-profile.lua`). 이 훅은 우선순위로 고르는 find-best-profile 보다 먼저 돌고,
프로필을 이름으로 못박는다.

이 규칙이 일부러 하지 않는 두 가지:

- **상태 파일을 이기지 못한다.** 세 선택 훅 가운데 find-stored-profile 이 *가장 먼저* 돌기 때문에,
  `~/.local/state/wireplumber/default-profile` 에 이 카드 항목이 있으면 그쪽이 이긴다. UI 에서 손으로 고른
  프로필은 사람이 내린 결정이니 남는 게 맞다. 예전에 고른 항목이 남아 있다면 한 번 지워야 이 규칙이 먹는다.
- **fallback 하지 않는다.** find-preferred-profile 은 프로필 이름만 보고 가용 여부는 보지 않는다(그건
  find-best-profile 이 본다). 모니터를 빼도 카드는 analog 로 내려가지 않고 HDMI 프로필에 머문다. 이 기계에서는
  괜찮다: 3.5 mm 잭에는 아무것도 꽂혀 있지 않고(lineout, headphones, 마이크 둘 다 "not available"), 평소 쓰는
  sink 는 HIFIMAN EF400 USB DAC 라 별도 카드여서 이 설정과 무관하다. 다른 기계에 이 규칙을 옮기면 안 된다.

## DP-1 모니터: 밝기(DDC/CI)

DDC/CI 는 모니터 케이블의 I2C 선으로 밝기·입력 같은 값을 읽고 쓰는 표준이고, 값마다 VCP 코드가 붙는다(밝기
0x10). 이 호스트에서 설정할 것은 없다.

**구조.** 외장 패널이니 `/sys/class/backlight` 가 없는 게 맞고, 경로는 DP AUX 채널 위의 I2C 다.
`/dev/i2c-10`("AUX USBC1/DDI TC1/PHY TC1", 이 커넥터의 AUX 선)이 DDC 주소 0x37 에서 응답하고, 패널은 Mstar
컨트롤러에서 MCCS 2.1 을 보고하며, capabilities 문자열에 VCP 0x10 이 있다. DMS 가 알아서 찾는다:
`dms ipc call brightness list` 에 `ddc:i2c-10 (ddc)` 로 나온다. dms 바이너리에 DDC 백엔드가 들어 있어 셸이
밝기를 조절하는 데 ddcutil 은 필요 없다(디버깅 도구로는 여전히 ddcutil 이고, `modules/nixos/packages.nix` 가
넣는다). 권한도 손댈 게 없다. `programs.dms-shell` 이 `hardware.i2c` 를 켜고, 그 udev 규칙이 `/dev/i2c-*` 에
uaccess 태그를 붙여 seat 사용자가 ACL 을 받는다. i2c 그룹에 넣을 필요가 없다.

**밝기가 안 먹을 때 먼저 볼 것.** 모니터 OSD 에서 HDR 이 Auto 면 이 패널은 수동 밝기를 무시한다. 그때도 DDC
는 정상이라 쓰기는 받아들여지고 다시 읽어도 값이 맞는데, 백라이트만 안 움직인다. 이 기계는 HDR 을 켜지
않으므로(Hyprland 는 colorManagementPreset srgb) OS 쪽에서는 이 상태가 보이지 않는다. 그래서 이 저장소를
의심하기 전에 OSD 의 HDR / DCR / dynamic contrast / eco 부터 본다.

**되읽기는 증거가 아니다.** `setvcp 10 60` 다음 `getvcp 10` 이 60 을 돌려줘도, 모니터가 값을 저장했다는
뜻일 뿐 그대로 동작했다는 뜻이 아니다. 이 패널은 레지스터 값으로 틀린 답도 한다. DisplayPort 로 연결돼
있는데 0x60(입력 소스)에 "S-Video-1" 이라고 답하고, capabilities 문자열에 없는 0x13(backlight control)에도
답하면서 같은 응답 안에서 현재값이 자기가 보고한 최대값보다 크다. 쓰기는 DDCRC_VERIFY 로 거부한다.
그래서 판정은 눈으로 하는 [`apps/ddc-probe`](../ddc-probe.md)로 한다. DDC 에 관한 주장(이 문서 포함)은
ddc-probe 로 확인한 뒤에 믿는다.

밝기 키바인드는 DMS 를 `increment(step, device)` 두 인자로 불러야 한다. 하나만 넘기면 조용히 거절된다
([hyprland.lua 절](../hyprland.md#키바인드)).

## DP-1 모니터: USB 허브가 USB 2.0 인 이유

모니터의 USB 허브는 동작하지만 USB 2.0 으로만 붙고, 설정으로는 바꿀 수 없다. 4포트 GenesysLogic 허브가
3-1 로 잡히고, 그 루트 포트의 connect_type 은 "hotplug" 다(보드에 납땜된 Bluetooth 는 "hardwired"). bMaxPower
0mA 이니 모니터 전원으로 도는 self-powered 허브다. USB3 루트 허브 둘이 비어 있는 것은 고장이 아니라 DP Alt
Mode 의 맞바꿈이다:

- DP-1 은 HBR3 4레인으로 링크돼 있고(`i915_dp_force_lane_count` 가 4*), 이 패널은 DSC(화면 압축 전송)를
  지원하지 않는다(DSC_Sink_Support: no).
- DSC 없는 5120x2160@60 에는 약 19.9 Gbit/s 가 필요한데 2레인은 실효 약 13 Gbit/s 라 감당이 안 된다.
- USB-C 커넥터에서 DP 가 4레인을 다 쓰면 옆에는 USB 2.0 만 남는다.

키보드·마우스·헤드셋·웹캠은 이 허브로 충분하고, 외장 SSD 는 본체 포트에 꽂는다.

## NPU: 커널 쪽

00:0b.0 [8086:7d1d], "Intel AI Boost". nixos-generate-config 가 이 장치를 찾아서
`hardware.cpu.intel.npu.enable = true` 를 `hardware-configuration.nix` 에 직접 써 넣는다. 보통의 디스크·
마이크로코드 스캔보다 한 발 더 나간 것이라 그 파일을 대충 훑으면 놓치기 쉽다. 이 옵션 뒤의 nixpkgs 모듈
(`nixos/modules/hardware/cpu/intel-npu.nix`)이 intel-npu-driver 의 펌웨어를 넣고, 드라이버를
`hardware.graphics.extraPackages` 에 `modules/nixos/intel.nix` 의 두 개와 나란히 넣고, level-zero(Intel 의
가속기 저수준 API)와 드라이버 검증 도구를 시스템 전체에 설치한다.

커널 쪽은 바로 동작한다. intel_vpu 가 붙고 `/dev/accel/accel0` 이 생기며(0666 root:render 라 그룹
멤버십이 필요 없다), 펌웨어 `intel/vpu/vpu_37xx_v1.bin` 이 올라오고 스케줄러는 HW 모드로 뜬다. PATH 의
`npu-kmd-test` 는 96 개 중 91 개를 통과하고, 건너뛴 다섯 개는 전부 reset-engine 케이스다.
`/sys/class/accel/accel0/device/npu_busy_time_us` 가 "뭔가 이걸 쓰고 있나"를 싸게 확인하는 카운터다.

## NPU: Level Zero 에 닿게 하기 (ZE_ENABLE_ALT_DRIVERS)

`hardware.cpu.intel.npu.enable` 은 intel-npu-driver 를 `hardware.graphics.extraPackages` 에 넣어
`libze_intel_npu.so.1` 이 `/run/opengl-driver/lib` 에 깔린다. 다른 그래픽 로더는 다 그 경로를 보는데 Level Zero
로더만 보지 않는다. 이 로더는 드라이버를 soname 만으로 dlopen 하고 일반 동적 링커 검색 경로에 맡기는데,
NixOS 에서는 그 경로에 `/run/opengl-driver/lib` 가 없다. 증상:

- `zeInitDrivers()` 가 ZE_RESULT_ERROR_UNINITIALIZED
- npu-umd-test 는 테스트를 하나도 못 돌리고 global setup 에서 실패
- OpenVINO 는 `['CPU']` 만 보인다. NPU 플러그인이 로드된 채 자기 안에서 "No available devices" 를 내므로,
  경로 문제가 아니라 하드웨어가 없는 것처럼 보인다.

`ZE_ENABLE_ALT_DRIVERS` 는 드라이버 라이브러리를 직접 지정하는 변수이고, 로더가 찾아 나서기 전에 읽는다.
`/run/opengl-driver/lib` 를 전역 `LD_LIBRARY_PATH` 에 넣는 것과 달리 부작용이 없다(그러면 기계의 모든
프로세스에서 mesa, libgbm 등을 가린다). 이 변수를 주면 npu-umd-test 의 Driver 묶음이 통과하고 OpenVINO 가
NPU 를 찾는다.

- 로더의 기본 드라이버 목록에 *더하는* 게 아니라 *대체한다*. 다른 Level Zero 드라이버가 들어오면 여기에
  손으로 덧붙인다.
- 없는 경로는 조용히 건너뛴다(확인함). 미리 넣어 둬도 안전하다.
- `environment.variables` 가 아니라 `sessionVariables` 다. GUI 앱에도 닿아야 한다.
- nixpkgs 는 이 변수를 어디서도 설정하지 않는다. NPU 모듈에 그런 개념 자체가 없다.

## NPU: 지금 어디까지 되나

위 설정이 있으면 Level Zero 스택 전체가 동작한다. npu-umd-test 는 220 개를 돌려 157 개를 통과하고, 62 개는
모델 설정 파일을 안 줘서 건너뛰며, "실패" 하나는 바로 그걸 지적하는 검사다. OpenVINO 는 장치를
"Intel(R) AI Boost" 로 찾는다.

**모델 컴파일은 안 되고, nixpkgs 가 바뀌기 전에는 계속 안 된다.** OpenVINO 에 두 연산짜리 그래프라도 NPU
용으로 컴파일하라고 하면 `ze_graph_ext_wrappers.cpp` 에서 다음을 내고 죽는다:

```
Level0 pfnCreate2 result: ZE_RESULT_ERROR_UNSUPPORTED_FEATURE
```

하드웨어나 펌웨어 한계가 아니다. `libze_intel_npu.so` 는 `dlopen("libnpu_driver_compiler.so")`("Compiler in
Driver", CiD)로 컴파일러를 부르는데, nixpkgs 의 intel-npu-driver 는 이걸 빌드하지 않는다. derivation 이
cmake 컴포넌트를 정확히 셋(level-zero-npu, validation-npu, fw-npu)만 설치하고 컴파일러는 그중에 없다.
`/nix/store` 어디에도 그 파일이 없고, 드라이버 크기가 컴파일러를 품은 빌드의 ~100 MB 가 아니라 2.1 MB 다.
CiD 자체가 OpenVINO 로 빌드되는 순환 의존 때문일 것으로 본다(확인 안 함).

정리하면 장치는 raw Level Zero 로 닿고 프로그래밍할 수 있지만, OpenVINO 로 "ONNX/IR 모델을 불러 NPU 에서
돌리는" 경로는 막혀 있다. 이미 컴파일된 blob 을 import 하는 것은 다른 드라이버 진입점을 쓰므로 될 수도 있는데,
이 기계에서 blob 을 만들 방법이 없어 시험하지 못했다. 이 저장소에서 고칠 것은 없다 — nixpkgs 가 바뀌거나
컴파일러를 직접 패키징해야 한다. 펌웨어는 의심할 자리가 아니다.

## OpenCL 과 OpenVINO

OpenVINO 는 Intel 의 추론 런타임으로, 같은 모델을 CPU·GPU·NPU 플러그인으로 돌린다.

- `hardware.graphics.extraPackages = [ pkgs.intel-compute-runtime ]`: OpenVINO GPU 플러그인이 쓰는 iGPU 용
  OpenCL. 없으면 그 플러그인은 "no supported devices found" 로 실패한다. 같은 모델로 NPU / GPU / CPU 를
  비교하는 것이 이 하드웨어의 주 용도라 NPU 옆에 둔다.
- `modules/nixos/intel.nix` 가 아니라 호스트에 두는 이유: intel-compute-runtime 은 12세대 이상만 지원한다.
  galaxy-chromebook-1(Kaby Lake UHD 620)에서는 짐일 뿐 아니라, 지원되지 않는 구성이 지원되는 것처럼 보이게 한다.
- 이 패키지에는 OpenCL ICD(`lib/intel-opencl/libigdrcl.so`)만 있고 Level Zero GPU 드라이버는 없다. GPU 쪽으로
  `ZE_ENABLE_ALT_DRIVERS` 에 더할 것이 없다.
- `pkgs.openvino`: CPU·GPU·NPU 플러그인과 `ov-compile_tool` 이 한 패키지에 있다. CPU 와 GPU 는 바로 쓰고, NPU 는
  `nix develop .#npu` 로 쓴다. NPU 플러그인이 도움 없이는 `libze_loader.so.1` 을 못 찾기 때문이다
  ([NPU 개발 셸](../local-inference.md#npu-개발-셸-nix-develop-npu-evo-t1)).

## 네트워크: 처음 짐작이 둘 다 틀렸다

**Wi-Fi 는 Wi-Fi 7 이 아니다.** 00:14.3 은 Arrow Lake CNVi MAC [8086:7740] 이지만, CNVi 는 MAC 과 RF 모듈이
따로이고 여기 달린 모듈은 Harrison Peak(RF HR B3, rfid=0x10a100)다. iwlwifi 는 이 조합을 "Intel(R) Wi-Fi 6
AX201 160MHz" 로 보고 `bz-b0-hr-b0-100.ucode` 를 올린다. 블롭은 enableRedistributableFirmware(not-detected.nix
경유)가 넣는다. Bluetooth 도 같은 모듈의 것으로 USB 8087:0026 에 있다. 새 세대 CNVi PCI ID 만 봐서는 실제
Wi-Fi 세대를 모른다 — `dmesg | grep iwlwifi` 만 알려 준다.

dmesg 의 "uses wireless extensions which will stop working for Wi-Fi 7 hardware" 경고(Chromium 스레드가 낸다)는
이 카드가 아니라 오래된 WEXT ioctl 얘기이고 해가 없다.

**이더넷도 Intel igc 가 아니다.** Realtek RTL8125 2.5GbE ×2 [10ec:8125 rev 05], 2d:00.0 과 2e:00.0, 커널 내장
r8169 가 맡는다. 펌웨어도 설정도 필요 없다. 링크가 불안정해지면: r8169 + RTL8125 는 ASPM(PCIe 절전) 관련 멈춤
이력이 있어서 `r8169.aspm=0` 이나 그 포트의 ASPM 끄기가 첫 시도다. igc 와는 대응이 다르다.

**Thunderbolt 4** — 00:0d.2 뒤의 domain0. "thunderbolt" 는 이미 `boot.initrd.availableKernelModules` 에
있으므로(스캔이 넣었다) TB 포트로 부팅해야 하는 장치도 부팅할 수 있다. 장치 인가는 boltd 가 맡는데, 이
저장소에서 boltd 를 직접 켜는 곳은 없다. common.nix 의 `services.desktopManager.gnome` 이
`services.hardware.bolt` 를 켜는 것이다. common.nix 에서 GNOME 을 빼면 bolt 를 직접 켜야 하고, 안 그러면 TB
장치를 인가할 수 없다. OCuLink 는 그냥 PCIe 라 OS 쪽에 스위치가 없다.

## 저장장치: 두 드라이브 중 NixOS 것은 하나

M.2 슬롯 두 개에 같은 모델(SOLIDIGM SSDPFKKW512H7, 512 GB)이 꽂혀 있고, 시리얼은 끝 두 글자만 다르다. 커널의
nvme0/nvme1 번호는 부팅마다 바뀔 수 있으므로(둘 다 본 적 있다) 드라이브는 시리얼로 구분한다.

| 시리얼 | 용도 |
|---|---|
| …2502602 | 이 시스템. p1 = 2 G ESP(/boot), p2 = 474.9 G ext4 "nixos"(/) |
| …250262S | NixOS 것이 아니다. Windows 11 설치용으로 비워 두었고 fileSystems 에 없어서 NixOS 는 마운트하지도 기다리지도 않는다 |

지금 어느 nvmeXn1 이 어느 것인지: `cat /sys/block/nvme*/device/serial`

2026-10-03 기준 건강 상태(nvme smart-log): 시스템 드라이브는 전원 켠 시간 3,917 시간, 22.6 TB 기록. 다른
하나는 2,537 시간, 11.0 TB. 둘 다 percentage_used 1-2%, composite 온도 warning·critical 시간 0, idle composite
~38 °C(같은 급의 부품이 팬 없는 mn56 섀시에서는 idle ~64 °C 였다).

두 번째 드라이브에 Windows 가 자기 EFI System Partition 을 만들면, 펌웨어가 다른 디스크의 부트 엔트리를
앞세우는 문제(galaxy-chromebook-1 이 efibootmgr 를 두는 이유)가 여기에도 생긴다. Windows Setup 은 Windows Boot
Manager 를 펌웨어 부트 순서 맨 앞에 둔다. systemd-boot 는 자기 ESP 의 로더만 보여 주므로, 별도 ESP 의 Windows 는
메뉴에 안 나오고 펌웨어 부트 메뉴로 들어가야 한다.

LM Studio 와 모델은 시스템 드라이브의 `~/.local/share/ai` 아래에 있다. 이 설정은 명령형이고
[`local-inference.md`](../local-inference.md) 에 적혀 있다.

## 스왑과 수면

**스왑.** 어느 드라이브에도 스왑 파티션이 없다. 스왑은 zram(RAM 안의 압축 스왑)이 전부이고, 64 GB 의
50%(common.nix)라 31 GB 다. 그래서 hibernate 도 없다.

**수면: 시험 안 함.** 펌웨어가 "ACPI: PM: (supports S0 S3 S4 S5)" 를 알린다. 이 S3 가 mn56 과의 차이다. mn56
펌웨어는 S0 S4 S5 만 제공해서 s2idle 이 고장 나면 물러설 곳이 없다([mn56](mn56.md)). 여기서는
`/sys/power/mem_sleep` 이

```
[s2idle] deep
```

이므로, s2idle 이 말썽이면 suspend 를 포기할 게 아니라 커널 파라미터 하나로 고친다:

```nix
boot.kernelParams = [ "mem_sleep_default=deep" ];
```

여기서는 아무것도 막지 않았고 suspend 를 한 번도 해 보지 않았다. 일부러다. mn56 의 마스크는 그 섀시에서 찾은
결과지 집안 규칙이 아니고, 여기에 베끼면 이 기계가 실제로 어떻게 동작하는지가 가려진다.

S4 는 알리기는 하지만 닿을 수 없다. hibernate 에는 resume 장치가 필요한데 스왑 파티션이 없고
`boot.resumeDevice` 도 비어 있다.

## 전원과 온도

intel_pstate 가 붙어 있고 scaling_governor 는 "powersave" 다(intel_pstate 의 이름일 뿐 동작은 다르다 —
[벤더 공통 층](../hardware-vendors.md)). EPP 는 balance_performance.

power-profiles-daemon 은 `balanced` 로 뜬다. 이 펌웨어에는 `/sys/firmware/acpi/platform_profile` 가 없어서
`powerprofilesctl list` 에 PlatformDriver "placeholder" 가 나오고, 프로필을 바꿔도 EPP 와 스케일링만 바뀌지 펌웨어
쪽 전력 한도는 바뀌지 않는다. 오래 무거운 일을 시키려면:

```
powerprofilesctl set performance
```

idle 온도 기준(나중에 비교용): 패키지 50 °C(critical 105 °C), DDR5 SPD 센서 39.8 °C, NVMe 둘 다 ~38 °C.
`sensors` 의 acpitz_0 zone 이 -273.3 °C 인 것은 채워지지 않은 ACPI thermal zone 이 절대영도를 읽는 것이라 무시한다.

그 밖에 dmesg 는 깨끗하다. 경고는 igen6_edac 메모리 오류 드라이버가 플랫폼을 잡을 때 igen6_probe 가 내는
"resource sanity check ... mapping multiple BARs" 두 줄뿐이고, 이 SoC 에서는 겉모양만의 경고다.

## 드라이브 건강 감시 (smartd)

smartd 는 드라이브의 SMART 속성을 주기적으로 검사하다가 임계값을 넘으면 알리는 데몬이다. autodetect 인데 지원
장치가 없으면 조용히 있는 게 아니라 시작부터 실패하므로, 드라이브가 SMART 에 응답하는지 확인한 뒤 켰다:
`smartctl --scan` 이 둘 다 NVMe 로 찾고, `-a` 도 둘 다 끝까지 읽힌다. mn56 과 같은 설정이다.

`modules/nixos/packages.nix` 의 smartmontools 는 `smartctl` CLI 뿐이라 직접 찾아보지 않으면 아무것도 알려 주지
않는다. smartd 는 뒤에서 검사하다 알린다(wall + syslog, 데스크톱까지 오는 길은
[nixos-common](../nixos-common.md#smartd-경보가-데스크톱까지-오는-길)). 각각 2,500-3,900 시간을 쓴 중고
드라이브 두 개라 추세를 잡는 것이 이 서비스의 쓸모다.

## 펌웨어 업데이트 (fwupd)

fwupd 는 LVFS(리눅스 벤더 펌웨어 저장소)에서 펌웨어를 받아 올리는 데몬이다. 꺼 둔다. fwupdmgr 는 D-Bus 로 데몬과
이야기하므로 서비스가 꺼져 있으면 장치 목록조차 볼 수 없다. 다시 확인해야 하면 잠깐 켠다.

2026-08-13 기준: fwupd 는 업데이트 가능한 장치 15 개를 찾지만, LVFS 에 펌웨어가 있는 것은 하나, UEFI dbx 다.
보드(BIOS1 / Internal SPI Controller, AMI 5.32)도, Intel ME 18.1.18.2635 도, Solidigm SSD 두 개도, Genesys Logic
허브도 없다. GMKtec 은 LVFS 에 아무것도 올리지 않고, Solidigm 도 이 부품용은 올리지 않는다. 업데이트는 벤더 도구와
USB 스틱으로 해야 한다.

dbx 업데이트(20241101 -> 20260402, Microsoft 의 Secure Boot 폐기 목록)는 일부러 적용하지 않는다. 이 펌웨어에서
Secure Boot 는 *꺼져* 있고(`bootctl status`), dbx 는 Secure Boot 가 켜졌을 때만 쓰인다. 지금 깔면 얻는 건 없고
이름 없는 보드의 펌웨어 NVRAM 에 쓰기만 한다. Secure Boot 를 켜는 날에는 무언가가 옛 서명 로더에 기대기
*전에* 먼저 적용한다 — dbx 를 올렸다가 듀얼 부팅이 벽돌이 되는 흔한 경로가 그 순서를 거꾸로 하는 것이다.

얻을 것이 원하지 않는 업데이트 하나뿐이니, 데몬을 띄워 두고 매주 메타데이터를 받을 이유가 없다.
