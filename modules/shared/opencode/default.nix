{ lib, ... }:

# opencode 와 oh-my-openagent 의 설정을 $HOME 에 심는다. 두 플랫폼이 같은 파일을 쓴다.
#
# 바이너리는 modules/shared/packages.nix 의 nixpkgs opencode 다. 플러그인
# 본체는 Nix 가 만들지 않는다 — opencode 가 시작할 때 내장 npm 라이브러리로
# ~/.cache/opencode/packages/ 아래에 직접 푼다.
#
# 설정을 home.file 심링크가 아니라 rice_sync 로 두는 이유(자세한 건 ./README.md):
#   opencode.json  설치 TUI(bunx oh-my-openagent install)가 plugin 항목을 쓴다.
#   omo.jsonc      플러그인이 시작 시 마이그레이션을 돌리고 tmp + rename 으로
#                  덮어쓴다. 심링크면 첫 마이그레이션에 일반 파일로 바뀌고 다음
#                  활성화에서 home-manager 가 거부한다. DMS 설정 GUI 와 같은 모양.
#
# 되받는 건 apps/rice-save, 밀어넣는 건 apps/rice-restore 의 `opencode` 항목이다.
# ~/.omo/omo.jsonc.migrations.json 은 머신별 상태라 왕복하지 않는다.

{
  home.activation.seedOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${import ../rice-seed-helpers.nix}
    rice_sync ${./opencode.json} "$HOME/.config/opencode/opencode.json"
    rice_sync ${./omo.jsonc}     "$HOME/.omo/omo.jsonc"
  '';
}
