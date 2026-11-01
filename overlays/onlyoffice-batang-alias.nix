# macOS OnlyOffice 가 한글 폴백을 Heiti 의 Big5 cmap 으로 잘못 잡아 "테스트" 를 "埕瞻珚" 로 그린다(9.4.0, core/DesktopEditor/fontengine).
# 폴백 우선순위 목록에서 Heiti 보다 앞인 한글 이름 "Batang" 으로 Noto Serif CJK KR 을 개명해 깐다. NixOS 엔 Heiti 가 없어 넣지 않는다.
# 지우는 조건: 상류가 CheckSymbols / SetCMapForCharCode 를 유니코드 cmap 으로 제한할 때. 전체 그림: docs/overlays.md
final: prev:

let
  python = prev.python3.withPackages (p: [ p.fonttools ]);
  serif = prev.noto-fonts-cjk-serif-static;
  otc = "${serif}/share/fonts/opentype/noto-cjk";
in
{
  onlyoffice-batang-alias = prev.runCommand "onlyoffice-batang-alias-${serif.version}"
    {
      nativeBuildInputs = [ python ];
      meta = {
        description = "Noto Serif CJK KR renamed to \"Batang\" so OnlyOffice's macOS fallback picker prefers it over Heiti";
        license = prev.lib.licenses.ofl;
        platforms = prev.lib.platforms.darwin;
      };
    } ''
    mkdir -p $out/share/fonts/opentype/batang-alias
    python3 ${./onlyoffice-batang-alias.py} ${otc}/NotoSerifCJK-Regular.ttc \
      $out/share/fonts/opentype/batang-alias/Batang-Regular.otf Regular
    python3 ${./onlyoffice-batang-alias.py} ${otc}/NotoSerifCJK-Bold.ttc \
      $out/share/fonts/opentype/batang-alias/Batang-Bold.otf Bold
  '';
}
