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

    # macOS-only helpers (e.g. colima-up) live as real shell files under
    # ../scripts and are injected here via readFile, so they keep shell syntax
    # highlighting and avoid nix string escaping.
    initContent = lib.mkBefore (''
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # Define variables for directories
      export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
      export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
      export PATH=$HOME/.local/share/bin:$PATH
      export PATH=$HOME/.local/bin:$PATH   # user-local bins (e.g. claude)

      # Remove history data we don't want to see
      export HISTIGNORE="pwd:ls:cd"

      # Editor
      export EDITOR="vim"
      export VISUAL="vim"

      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      # Use difftastic, syntax-aware diffing
      alias diff=difft

      # Always color ls and group directories
      alias ls='ls --color=auto'

      # Claude Code without permission prompts
      alias cld='claude --dangerously-skip-permissions'
    '' + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
      ("\n" + builtins.readFile ../scripts/colima-up.zsh));
  };
}
