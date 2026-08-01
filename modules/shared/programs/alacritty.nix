# Alacritty terminal configuration. Returns a `programs`-shaped fragment.
{ pkgs, lib, ... }:
{
  alacritty = {
    enable = true;
    settings = {
      # Imports are *defaults*: alacritty lets this file's own keys win over
      # anything imported, which is why the hard-coded `colors` block that used
      # to live here had to go — it would have silently beaten both imports.
      #
      #   dank-theme.toml  written by DMS/matugen on every wallpaper or theme
      #                    change (its matugenTemplateAlacritty template), so
      #                    the terminal tracks the shell's palette.
      #   rice.toml        written by apps/rice-switch — the per-profile bits
      #                    that are not colors (opacity, padding, font size).
      #
      # Both are seeded by the niri module's activation so they always exist;
      # alacritty logs an error and falls back to defaults for a missing
      # import, which is survivable but noisy.
      general.import = [
        "~/.config/alacritty/dank-theme.toml"
        "~/.config/alacritty/rice.toml"
      ];

      cursor = {
        style = "Block";
      };

      # No `window` block either: opacity and padding are per-profile and live
      # in rice.toml. Setting them here would win over the import and pin every
      # profile to the same terminal.

      # Fix for shell path when launching from desktop
      # When launching from desktop, $SHELL may point to /bin/zsh instead of
      # the Nix-managed shell, causing environment issues
      terminal.shell = {
        program = "${pkgs.zsh}/bin/zsh";
      };

      font = {
        normal = {
          family = "MesloLGS Nerd Font";
          style = "Regular";
        };
        size = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 10)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)
        ];
      };

      # No `colors` block on purpose — see the import comment above.
    };
  };
}
