_:

# Homebrew *formulae* (CLI/daemon packages), as opposed to ./casks.nix which
# holds the .app bundles.
#
# Almost nothing belongs here — anything with a nixpkgs build should be in
# modules/shared/packages.nix instead, where it is pinned by flake.lock rather
# than by whatever brew last fetched. The bar for a line in this file is "no
# nixpkgs package exists".
#
# homebrew.onActivation.cleanup is off, so removing a line here does not
# uninstall a formula that is already installed; `brew uninstall` does.
[
]
