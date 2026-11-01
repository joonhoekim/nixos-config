{ ... }:
{
  atuin.enable = true;        # Ctrl-R
  zoxide.enable = true;       # `z <dir>`
  eza.enable = true;
  pay-respects.enable = true; # `f`
  direnv = {                  # nix-direnv caches `use flake`
    enable = true;
    nix-direnv.enable = true;
  };
  mise = {
    enable = true;
    globalConfig = {
      # On NixOS mise defaults to all_compile=true: node builds from source (minutes) instead of the
      # prebuilt tarball (~3 s). nix-ld (hosts/nixos/common.nix) makes prebuilts run.
      settings.all_compile = false;
      tools = {
        node = "lts";
        # Not via corepack: Node 25+ no longer bundles it, so pnpm would silently vanish once Node 26 is LTS.
        pnpm = "latest";
        bun = "latest";
        go = "latest";
        rust = "stable";     # mise core plugin wraps rustup
        java = "temurin-25";  # LTS
        # No python: python3 comes from nixpkgs (../packages.nix), per-project venvs from uv.
      };
    };
  };
}
