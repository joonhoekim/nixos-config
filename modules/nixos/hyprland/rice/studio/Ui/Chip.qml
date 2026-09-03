// 여럿 중 하나를 고르는 알약. 창 위쪽의 탭과 손잡이 패널의 대상 고르기가 같은
// 것을 쓴다 — 한 창에서 "고르는 것"이 두 가지 모양이면 어느 쪽이 지금 상태인지
// 매번 다시 배워야 한다.
//
// 안 고른 칩에도 배경을 준다. 고른 것만 칠하고 나머지를 투명하게 두면 칩이 몇
// 개인지, 어디까지가 한 칸인지가 셰이더를 통과하면서 사라진다.

import QtQuick
import qs.Rice

Rectangle {
    id: root

    property string text: ""
    property bool picked: false
    // 고르지 않았을 때의 글자색. 목록 쪽에서 "걸려 있는 것"을 더 밝게 쓴다.
    property color idleInk: Theme.surfaceVariantText

    signal clicked

    implicitWidth: label.implicitWidth + Theme.spacingM * 2
    implicitHeight: Theme.hit
    radius: height / 2

    color: picked ? Theme.fade(Theme.primary, 0.22) : Theme.surfaceRaised
    border.width: picked ? 1 : 0
    border.color: Theme.primary

    Behavior on color {
        ColorAnimation {
            duration: Theme.durFast
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: area.containsMouse && !root.picked
        color: Theme.hoverWash
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: parent.radius + 3
        visible: root.activeFocus
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    Txt {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - Theme.spacingS)
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        font.pixelSize: Theme.fontS
        color: root.picked ? Theme.primary : root.idleInk
    }

    activeFocusOnTab: true

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.clicked();
            e.accepted = true;
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
