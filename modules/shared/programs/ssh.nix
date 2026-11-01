{ config, ... }:
{
  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "${config.home.homeDirectory}/.ssh/config_external" ];
    settings = {
      # `Host *`
      "*" = {
        SendEnv = [ "LANG" "LC_*" ];
        HashKnownHosts = true;
      };
    };
  };
}
