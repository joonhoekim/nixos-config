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
# 자세한 건 ./ghostty/README.md.

{
  home.activation.seedGhosttyRice = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${import ./rice-seed-helpers.nix}

    # 어느 룩에서나 같은 것 — 폰트, 팔레트, 여백 기본값.
    #
    # 색은 여기서 정하지 않는다. NixOS 에서는 DMS/matugen 이 themes/dankcolors 를
    # 써 주므로 `theme = dankcolors` 한 줄이면 프로필을 따라온다. macOS 에는 그
    # 생성기가 없어서 같은 이름의 테마 파일도 없는데, ghostty 는 없는 테마를
    # 조용히 넘기지 않고 설정 에러로 잡는다. macOS 에서 처음 켤 때 그 에러를 보면
    # themes/dankcolors 를 하나 만들어 두거나 그 줄을 스톡 테마 이름으로 바꾸면
    # 된다 — 셰이더 쪽은 그것과 무관하게 돈다.
    seed ${./ghostty/config}  "$HOME/.config/ghostty/config"

    # 룩 조각과 셰이더. apps/rice-term 이 rices/<name>.conf 를 rice.conf 로
    # 복사하고, config 끝의 include 가 그걸 읽는다. rice.conf 자체는 파생물이라
    # 시드하지 않는다 — `?` 덕에 없는 게 정상 상태이고, 첫 로그인은 셰이더 없이 뜬다.
    seed ${./ghostty/rices}   "$HOME/.config/ghostty/rices"
    seed ${./ghostty/shaders} "$HOME/.config/ghostty/shaders"
    ensure "$HOME/.config/ghostty/config" "config-file = ?rice.conf" \
      '# apps/rice-term 이 갈아끼우는 룩 조각. 없어도 되도록 ? 를 붙인다.'
  '';
}
