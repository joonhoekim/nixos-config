{ user, config, pkgs, ... }:

let
  xdg_configHome = "${config.users.users.${user}.home}/.config";
  xdg_dataHome   = "${config.users.users.${user}.home}/.local/share";
  xdg_stateHome  = "${config.users.users.${user}.home}/.local/state"; in
{
  # Karabiner-Elements config, managed declaratively.
  # NOTE: this becomes a read-only symlink into the Nix store, so edits made
  # in the Karabiner GUI will NOT persist across `build-switch`. To change
  # keymaps, edit modules/darwin/config/karabiner/karabiner.json and rebuild.
  "${xdg_configHome}/karabiner/karabiner.json" = {
    source = ./config/karabiner/karabiner.json;
  };

  # rift config, managed declaratively (read-only symlink into the Nix store).
  # Edit modules/darwin/config/rift.toml and rebuild to change it. rift's
  # hot_reload watches this path, but a switch replaces the symlink rather than
  # the file under it — press Alt+Ctrl+R if a rebuild seems to change nothing.
  #
  # Declarative rather than seeded (which is how the borders and the terminal
  # looks are handled, see modules/darwin/rice) because this file is a keymap,
  # not a look: there is nothing to tune by eye, and losing it to an unbacked
  # $HOME would cost every binding.
  "${xdg_configHome}/rift/config.toml" = {
    source = ./config/rift.toml;
  };

  # AeroSpace config, kept alongside rift's. AeroSpace is no longer started at
  # login (see hosts/darwin/default.nix) but is still installed, so this stays
  # valid for the `open -a AeroSpace` fallback. Delete both together once rift
  # has proven itself.
  "${xdg_configHome}/aerospace/aerospace.toml" = {
    source = ./config/aerospace.toml;
  };
}
