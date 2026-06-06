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
}
