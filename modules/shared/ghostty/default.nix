{ lib, ... }:

# ghostty 라이싱을 $HOME 에 심는다. NixOS 와 macOS 가 같은 파일을 쓴다.
#
# shared 에 있는 이유: ghostty 는 두 플랫폼에 다 있고(NixOS 는
# modules/nixos/packages.nix, macOS 는 modules/darwin/casks.nix), custom-shader 는
# 문서상 "GLSL 문법, 모든 플랫폼"이라 소스를 하나로 둘 수 있다. 그래서 조각을
# 니리 모듈 밑에 두지 않았다 — 니리는 리눅스 전용이고 터미널 룩은 그것과 무관하다.
#
# 경로가 양쪽에서 같은 것도 전제다. ghostty 의 기본 설정 경로는 두 플랫폼 모두
# `$XDG_CONFIG_HOME/ghostty` 이고, macOS 에서 그 변수가 비어 있으면 ~/.config 로
# 떨어진다. macOS 전용 경로(~/Library/Application Support/com.mitchellh.ghostty)를
# 쓰는 머신이라면 이 모듈은 아무 효과가 없다 — 그때는 그쪽 config 에서
# `config-file = ~/.config/ghostty/config` 한 줄로 끌어오면 된다.
#
# 룩을 고르는 건 apps/rice-term 이고, 그쪽도 두 플랫폼에서 돈다.
# 자세한 건 ./README.md.

{
  home.activation.seedGhosttyRice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${import ../rice-seed-helpers.nix}

    # 어느 룩에서나 같은 것 — 폰트, 팔레트, 여백 기본값.
    #
    # 색은 여기서 정하지 않는다. NixOS 에서는 DMS/matugen 이 themes/dankcolors 를
    # 써 주므로 `theme = dankcolors` 한 줄이면 프로필을 따라온다.
    seed ${./config}  "$HOME/.config/ghostty/config"

    # 그 생성기가 없을 때를 위한 팔레트. macOS 에는 DMS 가 아예 없고, 리눅스도
    # 첫 로그인에는 matugen 이 아직 안 돌아 있다. 없는 테마는 ghostty 가 설정
    # 에러로 잡으므로 — 색만 기본값이 되는 게 아니라 config 전체가 무효가 되고,
    # apps/rice-term 은 그걸 자기가 넣은 조각 탓으로 읽어 룩 전환을 되돌린다 —
    # 이 파일은 색보다 "설정이 항상 유효하다"를 위해 있다. seed 는 없을 때만
    # 복사하니 matugen 이 이미 쓴 팔레트를 덮지 않고, 복사본은 쓰기 가능해서
    # 리눅스에서 나중에 덮어써지는 것도 그대로다. 자세한 건 그 파일 머리말에.
    seed ${./themes}  "$HOME/.config/ghostty/themes"

    # 룩 조각과 셰이더. apps/rice-term 이 rices/<name>.conf 를 rice.conf 로
    # 복사하고, config 끝의 include 가 그걸 읽는다. rice.conf 자체는 파생물이라
    # 시드하지 않는다 — `?` 덕에 없는 게 정상 상태이고, 첫 로그인은 셰이더 없이 뜬다.
    seed ${./rices}   "$HOME/.config/ghostty/rices"
    seed ${./shaders} "$HOME/.config/ghostty/shaders"
    ensure "$HOME/.config/ghostty/config" "config-file = ?rice.conf" \
      '# apps/rice-term 이 갈아끼우는 룩 조각. 없어도 되도록 ? 를 붙인다.'
  '';
}
