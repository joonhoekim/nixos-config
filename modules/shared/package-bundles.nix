{ config, lib, pkgs, user, ... }:

# 이 기계에 깔 도구 묶음. 묶음의 내용은 ./packages.nix(공유)와
# ../darwin/packages.nix 의 `ios`(macOS 전용)에 있고, `core` 는 항상 깔리므로 여기서
# 고르지 않는다.
#
# 기본값은 전부다. 호스트가 덮어쓰면 목록이 통째로 바뀐다(리스트 옵션의 mkDefault).
#
# 고른 값은 home-manager 쪽에 extraSpecialArgs 의 `bundles` 로 넘긴다
# (../darwin/home-manager.nix, hosts/nixos/common.nix). 도구 자체만이 아니라 그 도구를
# 전제로 한 셸 설정(PLAYWRIGHT_BROWSERS_PATH, colima-up)과 Xcode(../darwin/ios.nix)도
# 이 값을 본다 — 묶음을 빼도 그런 줄이 남으면 패키지가 경로 참조로 다시 끌려 들어온다.
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

  # 묶음에 넣을 만큼 여러 기계가 쓰지는 않는, 이 기계에서만 쓰는 패키지. 호스트
  # 파일에 `local.packages.extra = with pkgs; [ blender ];` 처럼 적고, 빼면 다음
  # switch 에서 PATH 에서 사라진다(디스크는 gc 가 비운다).
  #
  # 묶음과 같은 자리(home.packages → /etc/profiles/per-user/<user>/bin)에 깐다.
  # environment.systemPackages 로 보내면 같은 패키지가 묶음에도 들어 있을 때 PATH 에
  # 두 벌이 생기고, 어느 쪽이 먼저 잡히는지가 플랫폼마다 다르다.
  options.local.packages.extra = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "묶음 밖에서 이 기계에만 더 까는 패키지.";
  };

  config.home-manager.users.${user}.home.packages = config.local.packages.extra;
}
