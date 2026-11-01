// 구역 이름. 글자가 거의 다 12px 라 색(primary)과 자간으로 가른다 — 굵기만으로는 셰이더를 통과하며 안 갈린다.

import QtQuick
import qs.Rice

Txt {
    font.pixelSize: Theme.fontS
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
    color: Theme.primary
}
