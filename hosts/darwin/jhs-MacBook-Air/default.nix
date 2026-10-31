{ ... }:

# jhs-MacBook-Air — 이 Mac 전용 설정.
#
# 공유부는 ../common.nix 에 있다. 여기에는 이 기계에서만 다른 것만 적는다.
# localHostName 은 이 디렉토리 이름에서 온다 (flake.nix 의 mkDarwinHost).
#
# 가볍게 쓰는 기계라 개발 묶음과 대부분의 GUI 앱을 뺐다. 필요해지면 묶음 이름이나
# cask 를 이 파일에 더하고 build-switch 한다.

{
  imports = [ ../common.nix ];

  # core 는 항상 깔린다.
  local.packages.bundles = [ "media" "mobile" "toys" ];

  # 목록을 통째로 바꾼다. 여기서 빠진 cask 에
  # 매인 Dock 항목·핸들러·LaunchAgent 도 같이 빠진다.
  homebrew.casks = [
    "google-chrome"
    "brave-browser"
    "firefox@developer-edition"
    "onlyoffice"
    "dbeaver-community"
  ];

  # 선언에 없는 brew cask·formula 를 activation 때 지운다. 이 기계의 brew 는 전부
  # 이 레포가 깐 것이라, 목록에서 빼는 것이 곧 지우는 것이 되게 한다. 앱이 남긴
  # ~/Library 의 데이터는 지우지 않는다("zap" 이 그 일을 한다).
  homebrew.onActivation.cleanup = "uninstall";
}
