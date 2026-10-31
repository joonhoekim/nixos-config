{ lib, pkgs, ... }:

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
}
