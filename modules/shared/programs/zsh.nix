# Shared zsh configuration. Returns a `programs`-shaped fragment merged by
# modules/shared/home-manager.nix.
{ pkgs, lib, ... }:
{
  zsh = {
    enable = true;
    autocd = false;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = lib.cleanSource ../config;
        file = "p10k.zsh";
      }
    ];

    # PATH·환경변수·alias 는 bash 와 같이 쓴다 (../shell-init.nix).
    initContent = lib.mkBefore (import ../shell-init.nix { inherit pkgs lib; });
  };
}
