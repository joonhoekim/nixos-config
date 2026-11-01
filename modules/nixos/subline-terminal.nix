{ pkgs, subline-terminal, ... }:

# 창을 닫아도 세션이 사는 터미널. 세 창 관리자의 Mod+Return 이 띄운다. 설명은 docs/subline-terminal.md.
# 데몬은 systemd 유닛이 아니다 — 처음 붙는 창이 띄우고, 리빌드 뒤 첫 창이 세션을 살린 채 새 판으로 갈아태운다.
{
  environment.systemPackages = [
    subline-terminal.packages.${pkgs.stdenv.hostPlatform.system}.subline-terminal
  ];
}
