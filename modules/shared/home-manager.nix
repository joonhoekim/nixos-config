{ config, pkgs, lib, user, identity, bundles, ... }:

# The result MUST stay a plain attrset: it is consumed as `programs = import ./shared/home-manager.nix {...}`,
# which cannot resolve a `lib.mkMerge` thunk. Program keys don't overlap, so the `//` fold is order-independent.
let
  args = { inherit config pkgs lib user identity bundles; };
  fragments = [
    ./programs/zsh.nix
    ./programs/bash.nix
    ./programs/git.nix
    ./programs/cli.nix
    ./programs/vim.nix
    ./programs/ssh.nix
    ./programs/tmux.nix
  ];
in
lib.foldl' (acc: frag: acc // import frag args) {} fragments
