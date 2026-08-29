"""Noto Serif CJK 정적 OTC 에서 KR face 하나를 꺼내 "Batang" 이라는 이름의 단일
OTF 로 저장한다. overlays/onlyoffice-batang-alias.nix 가 빌드 시 부른다 — 왜
이 이름이어야 하는지는 그 파일 머리 주석에 있다.

usage: onlyoffice-batang-alias.py <in.ttc> <out.otf> <Regular|Bold>
"""
import sys
from fontTools.ttLib import TTCollection

src, dst, style = sys.argv[1], sys.argv[2], sys.argv[3]
FAMILY = "Batang"

faces = [f for f in TTCollection(src).fonts if f["name"].getDebugName(1) == "Noto Serif CJK KR"]
assert len(faces) == 1, "KR face not found in %s" % src
font = faces[0]

full = FAMILY if style == "Regular" else "%s %s" % (FAMILY, style)
ps = "%s-%s" % (FAMILY, style)
table = {
    1: FAMILY,   # family
    2: style,    # subfamily
    3: "%s;nixos-config alias of Noto Serif CJK KR" % full,
    4: full,     # full name
    6: ps,       # postscript name
    16: FAMILY,  # typographic family
    17: style,   # typographic subfamily
}
name = font["name"]
# FreeType 은 family_name 으로 ID 16 을 우선 보고 없으면 ID 1 을 본다. 둘 다
# 바꾸고, WWS(21/22) 는 있으면 지워 이름이 갈리는 길을 닫는다.
name.names = [r for r in name.names if r.nameID not in (21, 22)]
for rec in name.names:
    if rec.nameID in table:
        rec.string = table[rec.nameID]
# CFF 의 자체 이름도 맞춘다 — 일부 스캐너는 이쪽을 읽는다.
cff = font["CFF "].cff
cff.fontNames[0] = ps
top = cff.topDictIndex[0]
top.FamilyName = FAMILY
top.FullName = full
font.save(dst)
print("wrote", dst, "as", full)
