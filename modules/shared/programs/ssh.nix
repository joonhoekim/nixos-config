# SSH client configuration. Returns a `programs`-shaped fragment.
#
# 경로에 플랫폼 분기(/home vs /Users)가 있었는데, home.homeDirectory 가 양쪽에서
# 이미 그 답을 들고 있어서 걷어냈다 — NixOS 는 modules/nixos/home-manager.nix 가
# 직접 적고, darwin 은 users.users.<name>.home 에서 home-manager 가 받아 적는다.
{ config, ... }:
{
  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "${config.home.homeDirectory}/.ssh/config_external" ];
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
      #   IdentityFile = [ "${config.home.homeDirectory}/.ssh/id_github" ];
      # };
    };
  };
}
