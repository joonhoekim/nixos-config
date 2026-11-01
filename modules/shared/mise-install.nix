# home.activation 조각: programs.mise.globalConfig 의 도구를 switch 때 깐다(`mise install` 은 멱등).
# curl 은 rust 백엔드의 rustup-init 이 부르는데 활성화 환경에는 curl/wget 이 없어서 얹는다.
# 실패는 switch 를 죽이지 않되(오프라인 머신) 경고한다 — 삼키면 도구가 빠진 채로 아무도 모른다.
{ pkgs, lib, config }:
lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  PATH="${pkgs.curl}/bin:$PATH" $DRY_RUN_CMD ${config.programs.mise.package}/bin/mise install \
    || echo "WARNING: 'mise install' failed — some tools declared in programs.mise are missing. Run 'mise install' by hand for the error." >&2
''
