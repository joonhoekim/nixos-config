{ ... }:

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
#
# The CLI tools around Xcode (cocoapods, xcodes, ...) are in ./packages.nix;
# docs/packages/mobile.md has why each one is there.

{
  homebrew.masApps = {
    # Requires being signed in to the App Store. ~10GB download, so the
    # activation that first installs it takes a long while.
    "Xcode" = 497799835;
  };
}
