_:

# Homebrew *formulae* (CLI/daemon packages), as opposed to ./casks.nix which
# holds the .app bundles.
#
# Almost nothing belongs here — anything with a nixpkgs build should be in
# modules/shared/packages.nix instead, where it is pinned by flake.lock rather
# than by whatever brew last fetched. The bar for a line in this file is "no
# nixpkgs package exists".
[
  # rift used to be here ("acsandmann/tap/rift"). The WM is now rift-grid, a
  # fork built and signed per machine by apps/rift-grid into ~/.local/bin —
  # see the rift agent in hosts/darwin/common.nix. The config uses commands
  # only the fork has, so upstream rift cannot read it.
  #
  # homebrew.onActivation.cleanup is off, so removing the line here does not
  # uninstall a formula that is already installed; `brew uninstall rift` does.
  # The tap stays declared in flake.nix so going back is one line.
]
