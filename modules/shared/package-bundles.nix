{ config, lib, pkgs, user, ... }:

# 전체 그림: docs/packages/README.md. 고른 값은 home-manager 에 `bundles` 로 넘어간다.
# 셸 설정(PLAYWRIGHT_BROWSERS_PATH, colima-up)과 ../darwin/ios.nix 도 이 값을 봐야 한다 — 묶음을 빼도
# 그런 줄이 남으면 패키지가 경로 참조로 다시 끌려 들어온다.
let
  names = builtins.filter (n: n != "core")
    (builtins.attrNames (import ./packages.nix { inherit pkgs; })) ++ [ "ios" ];
in
{
  options.local.packages.bundles = lib.mkOption {
    type = lib.types.listOf (lib.types.enum names);
    default = names;
    description = "core 외에 깔 도구 묶음. ios 는 macOS 에서만 뜻이 있다.";
  };

  # 묶음과 같은 home.packages 에 깐다. systemPackages 로 보내면 묶음에도 있는 패키지가 PATH 에
  # 두 벌이 되고, 어느 쪽이 먼저 잡히는지가 플랫폼마다 다르다.
  options.local.packages.extra = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "묶음 밖에서 이 기계에만 더 까는 패키지.";
  };

  config.home-manager.users.${user}.home.packages = config.local.packages.extra;
}
