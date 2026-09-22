{ ... }:

# 공용 macOS 호스트 — 전용 디렉토리가 없는 Mac 이 전부 이것을 쓴다.
# `darwinConfigurations.<arch>` (예: `.#aarch64-darwin`) 로 키잉된다.
#
# 한 사람이 Mac 을 여러 대 쓰면서 계정 이름이 같으면 이 한 벌로 충분하다.
# 기계마다 갈라야 할 것이 생기거나(도크 구성, stateVersion) 계정 이름이 다른
# 사람이 끼면, 그 Mac 에서 `./apps/setup` 을 돌려 hosts/darwin/<hostname>/ 을
# 만든다 — hostname 으로 키잉되고, 있으면 그쪽이 이긴다.
#
# NixOS 에는 이런 공용 층이 없다. 그쪽은 호스트마다 자기
# hardware-configuration.nix 가 반드시 있어야 해서 "여러 기계가 나눠 쓰는 호스트"
# 자체가 성립하지 않는다.
{
  imports = [ ./common.nix ];
}
