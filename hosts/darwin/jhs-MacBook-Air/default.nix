{ ... }:

# jhs-MacBook-Air — 이 Mac 전용 설정.
#
# 공유부는 ../common.nix 에 있다. 여기에는 이 기계에서만 다른 것만 적는다.
# localHostName 은 이 디렉토리 이름에서 온다 (flake.nix 의 mkDarwinHost).

{
  imports = [ ../common.nix ];
}
