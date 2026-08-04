_:

# Homebrew *formulae* (CLI/daemon packages), as opposed to ./casks.nix which
# holds the .app bundles.
#
# Almost nothing belongs here — anything with a nixpkgs build should be in
# modules/shared/packages.nix instead, where it is pinned by flake.lock rather
# than by whatever brew last fetched. The bar for a line in this file is "no
# nixpkgs package exists".
[
  # rift — tiling window manager, the AeroSpace replacement.
  #
  # Not in nixpkgs (as of 2026-08). Upstream publishes a prebuilt universal
  # binary and the formula ad-hoc codesigns it on install, which matters:
  # macOS ties the Accessibility grant to the signature, so a binary rebuilt
  # under a different identity would have to be re-approved.
  #
  # The tap is declared in flake.nix under nix-homebrew, so a fresh machine
  # never needs an imperative `brew tap`. Fully qualified here (tap/name)
  # rather than bare "rift" so it cannot resolve to a homebrew-core formula of
  # the same name if one ever appears.
  "acsandmann/tap/rift"
]
