// 손잡이 설명 띠. 높이가 두 줄로 고정이다 — 늘면 위 목록이 밀려 손잡이가 커서 밑에서 빠져나간다.
// 아무것도 안 가리키면 안내를 띄운다(빈 띠는 고장처럼 보인다).

import QtQuick
import qs.Rice

Item {
    id: root

    property string text: ""
    property string hint: ""

    implicitHeight: Theme.fontS * 2 * 1.4 + Theme.spacingS * 2 + 1

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.divider
    }

    Txt {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingS + 1
        anchors.bottomMargin: Theme.spacingS
        text: root.text !== "" ? root.text : root.hint
        font.pixelSize: Theme.fontS
        color: root.text !== "" ? Theme.fade(Theme.surfaceVariantText, 0.9) : Theme.fade(Theme.surfaceVariantText, 0.5)
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        verticalAlignment: Text.AlignTop
    }
}
