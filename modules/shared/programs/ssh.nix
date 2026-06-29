# SSH client configuration. Returns a `programs`-shaped fragment.
{ pkgs, lib, user, ... }:
{
  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux
        "/home/${user}/.ssh/config_external"
      )
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
        "/Users/${user}/.ssh/config_external"
      )
    ];
    # Host blocks now live under `settings`, keyed by host pattern, using
    # upstream OpenSSH directive names (PascalCase).
    settings = {
      # Global defaults (formerly the `Host *` match block)
      "*" = {
        SendEnv = [ "LANG" "LC_*" ];
        HashKnownHosts = true;
      };
      # Example SSH configuration for GitHub
      # "github.com" = {
      #   IdentitiesOnly = true;
      #   IdentityFile = [
      #     (lib.mkIf pkgs.stdenv.hostPlatform.isLinux
      #       "/home/${user}/.ssh/id_github"
      #     )
      #     (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      #       "/Users/${user}/.ssh/id_github"
      #     )
      #   ];
      # };
    };
  };
}
