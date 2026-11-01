{ lib, ... }:

# ghostty 라이싱 시드. NixOS·macOS 가 같은 파일을 쓴다 — 전체 그림: ./README.md

{
  home.activation.seedGhosttyRice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${import ../rice-seed-helpers.nix}

    rice_sync ${./config}  "$HOME/.config/ghostty/config"

    # matugen 이 없을 때(macOS, 리눅스 첫 로그인)의 팔레트. 없는 테마는 config 전체를 무효로 만들고
    # apps/rice/term 이 룩 전환을 되돌린다. matugen 이 쓴 뒤로는 기준선에서 벗어나 rice_sync 가 안 덮는다.
    rice_sync ${./themes}  "$HOME/.config/ghostty/themes"

    # rice.conf 는 파생물이라 시드하지 않는다 — `?` 덕에 없는 게 정상이다.
    rice_sync ${./rices}   "$HOME/.config/ghostty/rices"
    rice_sync ${./shaders} "$HOME/.config/ghostty/shaders"
    rice_ensure "$HOME/.config/ghostty/config" "config-file = ?rice.conf" \
      '# apps/rice/term 이 갈아끼우는 룩 조각. 없어도 되도록 ? 를 붙인다.'
  '';
}
