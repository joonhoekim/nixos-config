{ ... }:

{

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    overlays =
      # Apply each overlay found in the /overlays directory.
      #
      # `match` 는 **전체 일치**다 — `.*\.nix` 는 이름이 .nix 로 *끝나는* 것만
      # 잡는다. overlays/ 의 README.md 나 헬퍼 .py 가 오버레이로 임포트되지 않는
      # 것이 이 성질에 걸려 있으므로, 부분 일치(grep 감각)로 읽고 고치면 안 된다.
      let path = ../../overlays; in with builtins;
      map (n: import (path + ("/" + n)))
          (filter (n: match ".*\\.nix" n != null ||
                      pathExists (path + ("/" + n + "/default.nix")))
                  (attrNames (readDir path)));
  };
}
