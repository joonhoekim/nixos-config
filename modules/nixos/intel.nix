{ config, pkgs, ... }:

# Intel CPU + iGPU 공통 층(evo-t1, galaxy-chromebook-1). 섀시별 사정은 hosts/nixos/<hostname>/.
# 마이크로코드와 펌웨어는 hardware-configuration.nix(not-detected.nix)가 이미 켠다.

{
  # 렌더링은 mesa 만으로 되지만 비디오 가속(VAAPI/QSV)은 이 둘이 있어야 한다(AMD 는 radeonsi 가 VAAPI 를 싣는다).
  # 확인: `vainfo` — evo-t1 에서 iHD 26.1.6 / VA-API 1.24, AV1·HEVC·VP9·H.264 디코드와 인코드.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # evo-t1 은 끈다 — 그 CPU 는 적응 모드에서만 돌고 펌웨어가 그걸 못 준다(hosts/nixos/evo-t1/default.nix).
  services.thermald.enable = true;

  # cpuFreqGovernor 는 일부러 안 둔다. intel_pstate 는 일반 governor 를 무시하고 power-profiles-daemon 이 EPP 를
  # 정한다(scaling_governor 가 늘 "powersave" 인 건 이름일 뿐). powerprofilesctl set {power-saver|balanced|performance}

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    nvtopPackages.intel
    libva-utils         # vainfo

    # i7z 대신이다 — 하드코딩된 CPU 표라 Arrow Lake-H 에서 가짜 코어 하나를 보여 주고도 0 으로 끝난다.
    # 커널 패키지 세트에서 가져와야 부팅한 커널의 토폴로지(P/E/LPE)를 안다.
    #   sudo turbostat --quiet --show PkgWatt,Busy%,Bzy_MHz,PkgTmp
    config.boot.kernelPackages.cpupower
    config.boot.kernelPackages.turbostat
  ];
}
