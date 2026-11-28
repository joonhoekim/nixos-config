{ ... }:

# 양 플랫폼이 같은 값을 쓰는 nix 데몬 설정. 신뢰 그룹(@admin / @wheel)과 GC 일정의 옵션 이름은
# 플랫폼마다 달라서 hosts/<플랫폼>/common.nix 에 있다. nix.package 는 ./nix-implementation.nix.
{
  nix = {
    settings = {
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      # substituters 의 캐시마다 키가 있어야 한다. 키가 없는 캐시의 경로는 require-sigs 에
      # 걸려 전부 버려지는데, 빌드는 실패하지 않고 로컬 빌드로 조용히 넘어간다.
      # nix-community 키의 출처: https://app.cachix.org/api/v1/cache/nix-community
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Recover faster from stuck substituter connections on flaky networks.
      stalled-download-timeout = 60; # default 300s
      connect-timeout = 10;          # default 5s
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };

    # Own timer rather than auto-optimise-store, which runs inline and slows every build.
    optimise.automatic = true;

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
