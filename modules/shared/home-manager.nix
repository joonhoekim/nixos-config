{ config, pkgs, lib, ... }:

# Aggregates the per-program home-manager fragments under ./programs into a
# single `programs`-shaped attrset. Each fragment returns a plain attrset keyed
# by its program name (e.g. `{ zsh = {...}; }`); they are folded together here.
#
# The result MUST stay a plain attrset: the darwin/nixos home-manager modules
# consume it as `programs = {} // import ./shared/home-manager.nix {...}`, which
# cannot resolve a `lib.mkMerge` thunk. Program keys do not overlap across
# fragments, so a left-fold with `//` is sufficient and order-independent.
let
  args = { inherit config pkgs lib; };
  fragments = [
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/cli.nix
    ./programs/vim.nix
    ./programs/alacritty.nix
    ./programs/ssh.nix
    ./programs/tmux.nix
  ];
in
lib.foldl' (acc: frag: acc // import frag args) {} fragments
