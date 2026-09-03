// 손잡이 설명이 뜨는 띠. 목록 아래에 붙박이로 있고, 마우스가 올라간 줄의 설명을
// 받아서 띄운다.
//
// 높이가 두 줄로 고정이다. 내용에 맞춰 늘었다 줄었다 하면 그 위의 목록 높이가
// 같이 바뀌어서, 설명을 읽으려고 줄 위로 마우스를 올린 순간 목록이 밀리고 손잡이가
// 커서 밑에서 빠져나간다.
//
// 아무것도 안 가리켰을 때는 비워 두지 않고 안내를 띄운다. 빈 띠는 고장 난 것처럼
// 보이고, 설명이 있다는 사실 자체도 안 알려진다.

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
