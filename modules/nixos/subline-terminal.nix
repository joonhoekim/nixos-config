{ pkgs, subline-terminal, ... }:

# subline-terminal — 창·앱을 닫아도 세션이 사는 터미널 — 을 모든 NixOS 호스트에
# 깐다. 패키지는 그 레포의 flake(nix/package.nix)가 짓는다. 세 창 관리자의
# Mod+Return(niri·Hyprland 의 rice, subline 은 자기 기본값)이 인자 없이 띄우고,
# 그러면 세션 목록부터 연다. 설명은 docs/subline-terminal.md.
#
# 데몬(subline-terminald)은 systemd 유닛으로 두지 않는다. 처음 필요한 창이나 셸이
# 띄우고, 새 패키지로 리빌드한 뒤 처음 붙는 창이 돌고 있는 데몬을 세션을 살린 채
# 새 판으로 갈아태운다.
{
  environment.systemPackages = [
    subline-terminal.packages.${pkgs.stdenv.hostPlatform.system}.subline-terminal
  ];
}
