// 카드 한 장. 테두리가 장식이 아니다 — 팔레트상 카드와 배경 밝기가 같고(Rice/Theme.qml)
// 셰이더 블룸이 남은 차마저 뭉개서 윤곽선만이 카드를 가른다.

import QtQuick
import qs.Rice

Rectangle {
    radius: Theme.radius
    color: Theme.surfaceCard
    border.width: 1
    border.color: Theme.line
}
