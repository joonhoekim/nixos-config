{ config, pkgs, ... }:

# AMD Ryzen + Radeon iGPU 공통 층(mn56). 섀시별 사정은 hosts/nixos/<hostname>/.
# 마이크로코드와 펌웨어는 hardware-configuration.nix(not-detected.nix)가 이미 켠다.

{
  # radeonsi 가 VAAPI 까지 실어 extraPackages 가 필요 없다(Intel 은 iHD 를 따로 넣는다, ./intel.nix).
  # OpenCL(ROCm)이 필요하면 rocmPackages.clr.icd — 빌드가 무거워 쓸 때만 켠다.

  # cpuFreqGovernor 는 일부러 안 둔다. Zen4 의 amd_pstate(EPP)는 일반 governor 를 무시하고 power-profiles-daemon 이 정한다.

  environment.systemPackages = with pkgs; [
    radeontop
    nvtopPackages.amd
    # 커널 패키지 세트에서 가져와 boot.kernelPackages 와 맞춘다. turbostat 은 AMD 의 RAPL/MSR 도 읽는다.
    config.boot.kernelPackages.cpupower
    config.boot.kernelPackages.turbostat
  ];
}
