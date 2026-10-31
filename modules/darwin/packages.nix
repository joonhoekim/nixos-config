{ pkgs, lib, bundles }:

with pkgs;
let
  shared = import ../shared/packages.nix { inherit pkgs; };
  # iOS-native toolchain (darwin-only in nixpkgs — putting these in
  # ../shared/packages.nix would break the NixOS eval; verified via drvPath).
  # Cross-platform mobile tools (adb/scrcpy/maestro/...) live in shared.
  #
  # Xcode itself cannot come from nix — App Store or `xcodes install`; the
  # CLI below only manages versions. Xcode is declared in ./ios.nix behind the
  # same `ios` bundle. fastlane is deliberately absent: it's pinned
  # per-project via Gemfile/bundler by convention.
  ios = [
    cocoapods      # still required for RN/Flutter iOS builds (SPM hasn't displaced it there)
    xcbeautify     # readable xcodebuild output
    ios-deploy     # install/debug on a physical device (RN CLI uses it)
    xcodes         # install/switch Xcode versions from the CLI
    swiftformat    # Swift formatter
    swiftlint      # Swift linter
  ];
in
shared.core
++ lib.concatMap (b: if b == "ios" then ios else shared.${b}) bundles
++ [
  dockutil
]
