// 구역 이름. 카드 머리("체인" · "값")와 목록 안의 갈래 머리가 같은 것을 쓴다.
//
// 이 창은 글자가 거의 다 12px 이라 크기로는 위계가 안 선다. 그래서 구역 이름만
// 색(primary)과 자간으로 갈라 둔다 — 굵기만으로는 셰이더를 통과하면서 본문과
// 안 갈린다.

import QtQuick
import qs.Rice

Txt {
    font.pixelSize: Theme.fontS
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
    color: Theme.primary
}
