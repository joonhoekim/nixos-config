{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [
  dockutil

  # iOS-native toolchain (darwin-only in nixpkgs — putting these in
  # ../shared/packages.nix would break the NixOS eval; verified via drvPath).
  # Cross-platform mobile tools (adb/scrcpy/maestro/...) live in shared.
  #
  # Xcode itself cannot come from nix — App Store or `xcodes install`; the
  # CLI below only manages versions. fastlane is deliberately absent: it's
  # pinned per-project via Gemfile/bundler by convention.
  cocoapods      # still required for RN/Flutter iOS builds (SPM hasn't displaced it there)
  xcbeautify     # readable xcodebuild output
  ios-deploy     # install/debug on a physical device (RN CLI uses it)
  xcodes         # install/switch Xcode versions from the CLI
  swiftformat    # Swift formatter
  swiftlint      # Swift linter
]
