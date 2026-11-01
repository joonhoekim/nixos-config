# OnlyOffice 코어는 fontconfig 없이 /usr/share/fonts 등을 훑으면서 심링크를 조용히 버려(Directory.cpp GetFiles2 가
# DT_LNK 를 안 다룬다, ONLYOFFICE/DocumentServer#1859) NixOS 폰트를 하나도 못 본다. 그래서 실제 파일로 복사해 덮는다 —
# cp -L 을 링크로 "최적화"하면 그 순간 원래 버그로 돌아간다. 확인법과 지우는 조건: docs/overlays.md
final: prev:

let
  # 허용 목록이다: fonts.packages 전체는 1914MB / 378 패밀리이고, 오버레이는 config.fonts.packages 를 못 읽는다(무한 재귀).
  # Noto CJK 는 -static 이어야 한다 — 기본 판은 가변 폰트라 OnlyOffice 가 Thin 으로 그린다(상류 DesktopEditors#3285).
  # 전체 그림: docs/overlays.md
  fontPackages = with prev; [
    noto-fonts-cjk-sans-static # CJK 커버리지 — 무엇도 □ 로 렌더되지 않게
    noto-fonts-cjk-serif-static
    nanum # 나눔고딕 / 나눔명조 — 한국에서 온 .docx 가 이름으로 부르는 폰트
    pretendard
    liberation_ttf # Arial / Times New Roman / Courier New 메트릭 호환.
    # OnlyOffice 는 Carlito·Caladea 만 번들한다. 없으면 기본 템플릿과 글머리 기호가 어긋난다.
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
