# Shell-integrated CLI tools (zsh integration added automatically) plus the
# mise runtime version manager. Returns a `programs`-shaped fragment.
{ ... }:
{
  atuin.enable = true;        # better shell history search (Ctrl-R)
  zoxide.enable = true;       # smarter cd — use `z <dir>`
  eza.enable = true;          # modern `ls`
  pay-respects.enable = true; # correct the previous command (thefuck successor) — use `f`
  direnv = {                  # per-directory env; nix-direnv caches `use flake`
    enable = true;
    nix-direnv.enable = true;
  };
  mise = {                    # runtime version manager (node, etc.)
    enable = true;
    globalConfig = {
      tools = {
        node = "lts";
        bun = "latest";
        go = "latest";
        rust = "stable";     # mise core plugin wraps rustup
        java = "temurin-25";  # LTS (Temurin / Eclipse Adoptium)
        # Python is NOT managed by mise. The global python3 is provided by
        # nixpkgs (python3.withPackages in modules/shared/packages.nix) so the
        # shell `python3` has batteries (pymupdf, ...) pre-imported for quick
        # static analysis, fully declaratively. uv still handles per-project
        # venvs when a project needs pinned/extra deps.
      };
      settings = {
        # Run `corepack enable` after installing node, exposing the
        # project-pinned yarn/pnpm (package.json `packageManager` field).
        node.corepack = true;
      };
    };
  };
}
