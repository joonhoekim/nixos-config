{ pkgs, ... }:

# iOS / Apple-platform development toolchain.
#
# Xcode itself CANNOT come from nixpkgs: Apple forbids redistribution, so the
# iOS SDK, the simulator runtimes and the code-signing tooling only exist
# inside Xcode.app. (`xcbuild` in nixpkgs reimplements `xcodebuild`, but ships
# no SDK — it can't build an iOS app.) The closest we get to declaring it is
# the Mac App Store, driven by `mas` through nix-darwin's `homebrew.masApps`.
#
# After the first `darwin-rebuild switch` that installs Xcode:
#   1. open /Applications/Xcode.app once so it installs its extra components
#   2. sudo xcodebuild -license accept
#   3. sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#   4. xcodebuild -downloadPlatform iOS   # simulator runtime, if not bundled
#
# Command Line Tools alone (`xcode-select --install`) are NOT enough for iOS —
# they carry the macOS SDK only.

{
  homebrew.masApps = {
    # Requires being signed in to the App Store. ~10GB download, so the
    # activation that first installs it takes a long while.
    "Xcode" = 497799835;
  };

  # Only machine-level tooling goes here. Per-project Swift/iOS tools —
  # cocoapods, fastlane, swiftlint, xcodegen — are deliberately NOT installed
  # globally: projects pin them in a Gemfile (`bundle exec fastlane`) or as SPM
  # plugins, and a global copy on PATH just fights that pin. Same reasoning as
  # the language runtimes in modules/shared/packages.nix, which are left to
  # mise/uv. swift-format needs no entry either — Xcode 16+ ships it in the
  # toolchain (`xcrun swift-format`).
  environment.systemPackages = with pkgs; [
    # Xcode version manager — install/switch multiple Xcodes side by side
    # (`xcodes install 16.2`). Still downloads from Apple and needs an Apple ID,
    # so the versions themselves aren't declarative; only the tool is.
    xcodes

    # Readable formatter for `xcodebuild` output. Cosmetic, so a global version
    # can't disagree with a project's expectations.
    xcbeautify

    # Physical-device install/launch/debug is Xcode's own `xcrun devicectl`.
    # `ios-deploy` (the pre-Xcode-15 way) is deliberately NOT here: it links
    # against MobileDevice.framework under
    # /Library/Apple/System/Library/PrivateFrameworks, which nix's
    # `allowed-impure-host-deps` doesn't permit, so it fails to build.
  ];
}
