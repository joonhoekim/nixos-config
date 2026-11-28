{ config, user, ... }:

# 이 레포의 Dock 구성. 옵션과 적용 방법은 ./default.nix.
{
  local.dock = {
    enable = true;
    username = user;
    # 없는 앱을 남기면 dockutil 이 못 넣어 원하는 목록과 Dock 이 영영 안 맞고, activation 마다 Dock 을
    # 비우고 다시 채운다.
    entries = let
      casks = map (c: c.name) config.homebrew.casks;
    in map (e: removeAttrs e [ "cask" ])
      (builtins.filter (e: !(e ? cask) || builtins.elem e.cask casks) [
      # NOTE: Finder is auto-pinned at the far left (slot 1) by macOS, so it is
      # not listed here — adding it would create a duplicate icon.
      { path = "/Applications/Visual Studio Code.app/"; cask = "visual-studio-code"; }
      { path = "/Applications/Google Chrome.app/"; cask = "google-chrome"; }
      # 손으로 까는 앱이라 없을 수 있다. 경로가 없으면 dockutil 이 경고만 하고 넘어간다.
      { path = "/Applications/Claude.app/"; }
      { path = "/Applications/Zed.app/"; cask = "zed"; }
      { path = "/Applications/Brave Browser.app/"; cask = "brave-browser"; }
      { path = "/Applications/Ghostty.app/"; cask = "ghostty"; }
      { path = "/Applications/DBeaver.app/"; cask = "dbeaver-community"; }
      { path = "/Applications/Redis Insight.app/"; cask = "redis-insight"; }
      { path = "/Applications/Bruno.app/"; cask = "bruno"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "/System/Applications/Utilities/Activity Monitor.app/"; }
      { path = "/System/Applications/System Settings.app/"; }
    ]);
  };
}
