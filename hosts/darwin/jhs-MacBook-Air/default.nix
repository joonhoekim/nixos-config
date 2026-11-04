{ ... }:

# 가볍게 쓰는 기계라 개발 묶음과 대부분의 GUI 앱을 뺐다. 호스트별 현황은 `nix run .#inventory`.

{
  imports = [ ../common.nix ];

  # core 는 항상 깔린다.
  local.packages.bundles = [ "media" "mobile" "toys" ];

  # core cask(visual-studio-code)는 항상 깔린다. 여기서 빠진 cask 에 매인 Dock
  # 항목·핸들러·LaunchAgent 도 같이 빠진다.
  local.casks = [
    "google-chrome"
    "brave-browser"
    "firefox@developer-edition"
    "onlyoffice"
    "dbeaver-community"
    "rustdesk"
  ];

  # 목록에서 뺀 brew cask·formula 가 activation 때 지워진다. 앱이 남긴 ~/Library 데이터는 남는다(zap 이 아님).
  homebrew.onActivation.cleanup = "uninstall";
}
