{ config, lib, pkgs, ... }:

# 데몬과 /run/current-system/sw/bin/nix 의 구현체. 전체 그림: docs/nix-implementation.md
# Determinate 는 nix-darwin 에서 nix.enable = false 를 요구해 nix.settings·nix.gc 가 안 먹으므로 enum 에 없다.
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
