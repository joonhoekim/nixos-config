{ ... }:

{
  imports = [ ./nix-implementation.nix ./package-bundles.nix ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    overlays =
      # `match` 는 전체 일치라 `.*\.nix` 는 .nix 로 끝나는 이름만 잡는다 — overlays/ 의
      # README.md·헬퍼 .py 가 오버레이로 임포트되지 않는 것이 이 성질에 걸려 있다.
      let path = ../../overlays; in with builtins;
      map (n: import (path + ("/" + n)))
          (filter (n: match ".*\\.nix" n != null ||
                      pathExists (path + ("/" + n + "/default.nix")))
                  (attrNames (readDir path)));
  };
}
