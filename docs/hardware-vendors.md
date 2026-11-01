# 벤더 공통 층 — Intel 과 AMD

`modules/nixos/intel.nix` 와 `modules/nixos/amd.nix` 는 CPU/GPU 벤더 공통 설정만 둔다. 섀시별 사정은
`hosts/nixos/<hostname>/` 에 있다.

| 모듈 | 쓰는 호스트 |
|---|---|
| intel.nix | [evo-t1](hosts/evo-t1.md)(Core Ultra 9 285H), [galaxy-chromebook-1](galaxy-chromebook-1.md)(UHD 620) |
| amd.nix | [mn56](hosts/mn56.md)(7840HS) |

마이크로코드(hardware.cpu.*.updateMicrocode)와 재배포 펌웨어는 생성된 hardware-configuration.nix 가 not-detected.nix 로
켠다. 이 층에 없다.

## 비디오 가속

렌더링은 둘 다 mesa 만으로 된다. 차이는 영상 디코드·인코드다.

- **AMD**(RDNA3 / 780M): radeonsi 가 VAAPI(리눅스의 하드웨어 영상 가속 API — H.264/HEVC/AV1 디코드)까지 실어 추가
  패키지가 없다.
- **Intel**(i915/xe): 두 개가 필요하다.
  - intel-media-driver — iHD VAAPI 드라이버, Broadwell 이후
  - vpl-gpu-rt — oneVPL 런타임. Gen12+(Tiger Lake 이후)에서 ffmpeg/OBS 의 QSV 경로. 옛 부품에서는 libvpl 이 맞는 구현을
    못 찾고 VAAPI 로 떨어져 무해하다.

확인: `vainfo`(libva-utils). evo-t1: iHD 26.1.6 / VA-API 1.24, Xe-LPG 전체 프로필(AV1/HEVC/VP9/H.264 디코드·인코드).

OpenCL(ROCm, AMD): `hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];` — 빌드가 무거워 쓸 때만 넣는다.
Intel 쪽 OpenCL 은 12세대 이상만 지원해서 evo-t1 호스트 파일에 있다.

## thermald

thermald 는 펌웨어의 열 관리 표(DPTF)를 먼저 쓰고, 없으면 패키지의 thermal-conf.xml 로 CPU 를 스로틀링하는 데몬이다.
작은/수동 냉각 섀시에서 중요하다. evo-t1 은 끈다 — 그 CPU 는 thermald 가 적응 모드에서만 돌리는데 펌웨어가 그걸 못 준다
([evo-t1](hosts/evo-t1.md#thermald-를-끈-이유)).

## cpuFreqGovernor 를 안 두는 이유

intel_pstate 와 Zen4 amd_pstate(EPP active)는 일반 governor 를 무시하고, services.power-profiles-daemon
(hosts/nixos/common.nix)이 EPP(에너지 성능 선호값)를 정한다. Intel 의 `scaling_governor` 가 늘 "powersave" 인 건
intel_pstate 의 이름일 뿐 동작이 아니다.

```
powerprofilesctl set {power-saver|balanced|performance}
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver   # 드라이버 확인
```

## i7z 대신 cpupower + turbostat

i7z 는 2020 릴리스로 하드코딩된 CPU 표에서 분기해, Arrow Lake-H 에서 "Unknown processor, not exactly based on Nehalem,
Sandy bridge or Ivy Bridge" 를 찍고 주파수도 C-state 도 없는 가짜 코어 하나를 보여 준다. 그래도 0 으로 끝나 없는
것보다 나쁘다.

cpupower + turbostat 은 config.boot.kernelPackages(common.nix 의 linuxPackages_latest)에서 가져와 부팅한 커널과 같은
트리로 빌드되므로, 그 커널이 아는 토폴로지(하이브리드의 P/E/LPE 코어)를 안다. turbostat 은 AMD 의 RAPL/MSR 도 읽는다.

```
sudo turbostat --quiet --show PkgWatt,Busy%,Bzy_MHz,PkgTmp
```
