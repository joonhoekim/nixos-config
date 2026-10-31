{ config, lib, pkgs, ... }:

# 이 기계가 어느 Nix 구현체를 쓰는지 고르는 자리. NixOS 와 nix-darwin 이 같은
# 옵션을 읽고, 둘 다 nix.package 를 여기서 받는다.
#
# nix.package 가 정하는 것은 데몬과 /run/current-system/sw/bin/nix 다. 셸의 `nix`
# 가 같은 판이 되는 것은 설치기의 nix-daemon.sh 를 source 하지 않아서이고
# (../shared/shell-init.nix), 셋이 같은지는 apps/check/mac 이 본다.
#
# Determinate 가 enum 에 없는 이유: nix-darwin 에서 nix.enable = false 를 요구해서
# nix.settings·nix.gc 가 통째로 먹지 않는다. 값 하나로 바꿀 수 있는 후보가 아니다.
let
  cfg = config.local.nix;
in
{
  options.local.nix.implementation = lib.mkOption {
    type = lib.types.enum [ "cppnix" "lix" ];
    default = "cppnix";
    description = ''
      데몬과 시스템 프로필의 Nix 구현체.
        cppnix → pkgs.nix (nixpkgs 의 기본 판)
        lix    → pkgs.lixPackageSets.stable.lix
      판을 따로 고정하려면 호스트에서 nix.package 를 mkForce 한다.
    '';
  };

  config.nix.package = {
    cppnix = pkgs.nix;
    lix = pkgs.lixPackageSets.stable.lix;
  }.${cfg.implementation};
}
