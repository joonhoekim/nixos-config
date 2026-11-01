{ config, lib, ... }:


# Xcode cannot come from nixpkgs (no redistribution; nixpkgs' xcbuild ships no SDK), so mas installs it from the App Store.
# Post-install steps, and why Command Line Tools alone are not enough: docs/packages/mobile.md
# Leaving out the `ios` bundle does not delete an installed Xcode — masApps only installs.
{
  homebrew.masApps = lib.mkIf (builtins.elem "ios" config.local.packages.bundles) {
    # Requires being signed in to the App Store. ~10GB download, so the
    # activation that first installs it takes a long while.
    "Xcode" = 497799835;
  };
}
