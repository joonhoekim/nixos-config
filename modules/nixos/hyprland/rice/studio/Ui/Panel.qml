// 카드 한 장. 배경·테두리·둥글기만 준다.
//
// 테두리가 장식이 아니다 — matugen 팔레트가 surface 와 surface_container 를 같은
// 값으로 주기 때문에(Rice/Theme.qml) 카드는 밝기만으로 배경과 안 갈린다. 게다가
// 이 창은 화면 셰이더를 통과해 그려지므로, 블룸이 걸리면 그 좁은 밝기 차마저
// 뭉개진다. 윤곽선이 카드를 카드로 만드는 유일한 것이다.

import QtQuick
import qs.Rice

Rectangle {
    radius: Theme.radius
    color: Theme.surfaceCard
    border.width: 1
    border.color: Theme.line
}
