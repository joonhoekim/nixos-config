{ pkgs, lib, bundles }:

with pkgs;
let
  shared = import ../shared/packages.nix { inherit pkgs; };
  # Darwin-only in nixpkgs — putting these in ../shared/packages.nix breaks the NixOS eval (verified via drvPath).
  # fastlane is deliberately absent: it's pinned per project via Gemfile/bundler.
  ios = [
    cocoapods      # still required for RN/Flutter iOS builds (SPM hasn't displaced it there)
    xcbeautify
    ios-deploy     # install/debug on a physical device (RN CLI uses it)
    xcodes
    swiftformat
    swiftlint
  ];
in
shared.core
++ lib.concatMap (b: if b == "ios" then ios else shared.${b}) bundles
++ [
  dockutil
]
