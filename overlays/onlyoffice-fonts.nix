# OnlyOffice 는 NixOS 가 설치한 폰트를 하나도 못 본다. 증상은 둘로 보이지만
# 원인은 하나다 — CJK 가 □ 로 깨지는 것과, 폰트 목록에 내가 설치한 폰트가 안
# 뜨는 것.
#
# 편집기 코어는 fontconfig 을 쓰지 않는다. /usr/share/fonts, ~/.fonts,
# ~/.local/share/fonts 라는 하드코딩된 디렉터리만 훑는데, NixOS 가 그 자리에
# 놓는 것은 전부 /nix/store 로 가는 심볼릭 링크이고 이 스캐너는 심링크 엔트리를
# 건너뛴다. 그래서 스캔 결과가 자기가 번들한 폰트뿐이다. 실제로 확인하려면
#
#   ~/.local/share/onlyoffice/desktopeditors/data/fonts/fonts.log
#
# 를 보면 된다. 파일 22 개, 전부 패키지 자신의 share/desktopeditors/fonts 아래
# 것이고 Noto CJK 는 없다.
#
# nixpkgs 가 이미 FHS 환경의 targetPkgs 에 noto-fonts-cjk-sans 를 넣어둔 것이
# 소용없는 이유도 같다 — buildEnv 는 그것을 파일 단위 심링크로 걸어준다.
# 이 머신에서 갈라 본 결과가 근거다: ~/.local/share/fonts 에 실제 .ttf 를
# 복사해 넣으면 목록에 뜨고, /nix/store 를 가리키는 심링크로 넣으면 안 뜬다.
#
# 그래서 **실제 파일**로 된 폰트 디렉터리를 만들어 샌드박스 안의
# /usr/share/fonts 위에 덮어 씌운다. 링크가 아니라 복사인 것이 이 오버레이의
# 전부이므로, cp -L 을 "최적화" 해서 링크로 바꾸면 그 순간 원래 버그로 돌아간다.
# 중복된 용량은 hosts/nixos/common.nix 의 nix.optimise.automatic 이 동일 파일을
# 하드링크로 묶으면서 대부분 회수한다.
#
# 이건 상류의 알려진 버그이고, 의도적인 심링크 배제가 아니다. 원인 코드는
# core 의 DesktopEditor/common/Directory.cpp, GetFiles2() 다 — d_type 을
# DT_REG / DT_DIR / DT_UNKNOWN 으로만 분기해서 DT_LNK 가 어디에도 걸리지 않고
# 조용히 버려진다. 바로 위 DT_UNKNOWN 분기가 XFS 때문에 "모르겠으면 stat() 으로
# 실체를 보자"는 예외인 걸 보면, 방침은 실체를 따라가는 쪽인데 DT_LNK 만
# 열거에서 빠진 것이다.
#
#   https://github.com/ONLYOFFICE/DocumentServer/issues/1859
#
# 2022 년 8 월에 NixOS 쪽에서 올렸고 confirmed-bug 로 확인됐지만(내부 티켓
# 58490) 4 년째 열려 있다. 보고는 7.1 기준, 이 파일을 쓰는 9.1.0 에서도 그대로다.
#
# 지우는 조건은 둘 중 하나다.
#
#   1. 상류가 고친다. 확인은 이 오버레이 없이 위 fonts.log 에 /usr/share/fonts
#      아래 경로가 잡히는지 보면 된다.
#   2. nixpkgs PR #526315 가 머지된다. programs.onlyoffice NixOS 모듈이 같은
#      일(폰트 역참조 + bwrap 노출)을 하므로, 그러면 이 파일을 지우고 그 모듈로
#      갈아탄다.
#
#      https://github.com/NixOS/nixpkgs/pull/526315
final: prev:

let
  # 문서 편집기에 실제로 쓸 얼굴만, 손으로 고른다. "시스템 폰트에서 자동으로
  # 가져오면 되지 않나" 는 재어봤고, 답은 아니다.
  #
  #   - config.fonts.packages 전체를 복사하면 1914MB / 378 패밀리가 된다.
  #     용량보다 폰트 드롭다운이 Nerd Font 와 아이콘 폰트로 덮이는 쪽이 더 크게
  #     불편하다.
  #   - 오버레이는 config.fonts.packages 를 읽을 수 없다. 오버레이가 pkgs 를
  #     만들고 fonts.packages 의 값이 그 pkgs 에서 나오니 무한 재귀다. 자동화
  #     하려면 이 파일을 버리고 모듈에서 사용처 오버라이드로 가야 한다.
  #   - modules/shared/fonts.nix 만 가져오는 절충도 안 된다. 아래 다섯 개는 세
  #     군데에서 온다 — cjk-sans/pretendard 는 shared/fonts.nix,
  #     cjk-serif/nanum 은 nixos/korean.nix, liberation 은 NixOS 의
  #     fonts.enableDefaultPackages. 유도하면 5개 중 2개만 잡히고 정작 한글
  #     문서에 제일 중요한 나눔·명조를 놓친다.
  #
  # 그리고 방향이 틀렸다. 자동 유도로 바꾸면 거부 목록이 필요해지는데, 거부
  # 목록은 **열린 채로 실패한다** — 나중에 fonts.packages 에 큰 폰트가 하나
  # 붙으면 이 클로저에 조용히 수백 MB 가 딸려 들어온다. 아래의 허용 목록은
  # 닫힌 채로 실패하고, 목록 자체가 "문서용 얼굴"이라는 판단이다.
  fontPackages = with prev; [
    noto-fonts-cjk-sans # CJK 커버리지 — 무엇도 □ 로 렌더되지 않게
    noto-fonts-cjk-serif
    nanum # 나눔고딕 / 나눔명조 — 한국에서 온 .docx 가 이름으로 부르는 폰트
    pretendard # UI/문서용 산세리프
    liberation_ttf # Arial / Times New Roman / Courier New 메트릭 호환.
    # OnlyOffice 는 Calibri/Cambria 대응(Carlito, Caladea)은
    # 번들하지만 이쪽은 없다. 없으면 기본 템플릿과 글머리
    # 기호가 어긋난다 — nixpkgs 패키지 주석이 경고하는 그것.
  ];

  realFonts = prev.runCommand "onlyoffice-fonts" { } ''
    mkdir -p $out
    for pkg in ${prev.lib.escapeShellArgs fontPackages}; do
      [ -d "$pkg/share/fonts" ] || continue
      dir=$out/$(basename "$pkg" | cut -d- -f2-)
      mkdir -p "$dir"
      # -L 로 역참조한다: $dir 에 떨어지는 것은 링크가 아니라 진짜 파일이다.
      find -L "$pkg/share/fonts" -type f \
        \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) \
        -exec cp -L --no-preserve=mode -t "$dir" {} +
    done
  '';
in
{
  onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.overrideAttrs (old: {
    # buildFHSEnv 는 extraBwrapArgs 를 bwrap argv 배열 안에 그대로 문자열
    # 보간한다. 따옴표를 거치지 않으므로 공백 있는 문자열 하나가 인자 셋이 된다.
    extraBwrapArgs = (old.extraBwrapArgs or [ ]) ++ [
      "--ro-bind ${realFonts} /usr/share/fonts"
    ];
  });
}
