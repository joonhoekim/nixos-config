# macOS 의 OnlyOffice 에서 한글이 한자로 깨진다 — "테스트" 가 "埕瞻珚" 로.
# Arial·Calibri 처럼 한글이 없는 폰트(새 문서의 기본값)에서 폴백이 일어날 때만
# 그렇고, 깨지는 글자는 유니코드 코드포인트가 Big5 코드로도 유효한 음절
# (둘째 바이트 0x40–0x7E, 0xA1–0xFE)뿐이다. 2026-08-29, 9.4.0 에서 x2t 로 재현.
#
# 원인은 둘이 겹친 것이다 (core/DesktopEditor/fontengine):
#
#   1. ApplicationFonts.cpp CheckSymbols 가 폰트의 **모든** cmap 서브테이블을
#      돌며 코드를 유니코드로 간주해 커버리지에 기록한다. macOS 시스템 폰트
#      STHeiti(Heiti SC/TC)는 한글이 전혀 없지만 Mac Big5 cmap(1,2)이 있어,
#      Big5 바이트 0xA140–0xF9FE 가 한글 음절 블록(AC00–D7A3)을 덮는 것으로
#      잘못 잡힌다. FontFile.cpp SetCMapForCharCode 도 같은 cmap 에 유니코드
#      값을 넣어 글리프를 꺼내니 결과가 엉뚱한 한자다.
#   2. ApplicationFontsWorker.cpp 가 폴백 테이블(__fonts_ranges /
#      font_selection.bin)을 만들 때 하드코딩된 이름 목록으로 우선순위를 준다.
#      mac 빌드에선 PingFang·Heiti·Songti 가 그 목록에 있고, 목록에 없는 폰트는
#      파일 크기 순으로 **전부 그 뒤**다. 그래서 Nix 로 어떤 한글 폰트를 깔아도
#      Heiti 를 이기지 못하고, 한글 블록이 Big5 패턴대로 NanumGothic / Heiti
#      체스판이 된다(실측 4481 / 3755 / 3022 자).
#
# 1 은 시스템 폰트라 손댈 수 없고 2 는 바이너리 안이다. 남은 지렛대는 목록의
# **순서**다 — Heiti 보다 앞에 있는 이름 가운데 한글 폰트가 하나 있다: "Batang".
# 그 이름을 가진 진짜 한글 폰트가 있으면 한글 음절 11172 자를 통째로 가져가
# Heiti 를 밀어낸다(실측: 전부 Batang 으로 배정, 렌더 정상).
#
# 그래서 Noto Serif CJK KR(정적)의 KR face 를 "Batang" 으로 개명해 설치한다.
# 이름을 정직하게 고른 것이다 — Batang(바탕)은 명조체이고, 한국에서 온 .docx 가
# 그 이름으로 부르는 폰트라 이 별칭이 그 문서에도 맞는 얼굴을 준다(Liberation
# 이 Arial 에 하는 일과 같다). OnlyOffice 는 "바탕" 도 Batang 으로 푼다.
# 산세리프에 이 이름을 붙이면 폴백 모양은 좋아져도 바탕을 부르는 문서가 틀린다.
#
# 부작용을 알고 쓴다: macOS 전체에 "Batang" 이 생기니 Pages/Word 도 본다. 그리고
# 이 별칭이 한자(4E00–9FFF)도 전부 덮으므로 폴백 한자가 PingFang 대신 한국식
# 자형의 명조로 나온다 — 한국어 문서엔 맞는 쪽이다.
#
# NixOS 쪽엔 넣지 않는다. Heiti 가 없어 1 이 성립하지 않는다. 지우는 조건은
# 상류가 CheckSymbols / SetCMapForCharCode 를 유니코드 cmap 으로 제한하는 것.
# 확인은 AllFonts.js 의 __fonts_ranges 에서 AC00–D7A3 이 Heiti 없이 한 폰트로
# 잡히는지 보면 된다 (이 세션 메모: onlyoffice-macos-fonts).
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
