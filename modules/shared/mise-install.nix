# home.activation 조각 — programs.mise.globalConfig 에 선언한 도구를 switch 때
# 실제로 깐다. 두 플랫폼의 home-manager 가 같은 것을 쓴다(../nixos/home-manager.nix
# 와 ../darwin/home-manager.nix).
#
# 한 벌로 접은 이유: 원래 두 파일에 거의 같은 블록이 하나씩 있었는데, NixOS 쪽만
# `|| true` 를 경고로 고치고 darwin 쪽은 옛 판(실패를 조용히 삼키는)을 오래 들고
# 있었다. 반씩 고쳐진 채로 남는 게 이 모양의 비용이라 자리를 하나로 줄였다.
#
# `mise install` 은 멱등이다(모자란 게 없으면 no-op). curl 을 PATH 에 얹는 건
# mise 의 rust 백엔드가 rustup-init 을 부르는데, 활성화 환경에는 curl/wget 이
# 따로 없어서다.
#
# 실패가 switch 를 죽이면 안 되지만(오프라인 머신이 영영 rebuild 를 못 하게 된다),
# 조용히 지나가도 안 된다 — 한 번 그렇게 삼켰다가 bun/java/rust 가 안 깔린 채로
# `bun` 이 없다는 걸 알아챌 때까지 갔다. 크게 경고하고 계속 간다.
{ pkgs, lib, config }:
lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  PATH="${pkgs.curl}/bin:$PATH" $DRY_RUN_CMD ${config.programs.mise.package}/bin/mise install \
    || echo "WARNING: 'mise install' failed — some tools declared in programs.mise are missing. Run 'mise install' by hand for the error." >&2
''
