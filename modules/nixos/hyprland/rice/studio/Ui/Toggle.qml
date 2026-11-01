// 켜고 끄는 것(Qt Quick Controls 를 안 쓰는 이유는 Slide.qml).
// `checked` 는 밖에서만 바뀐다 — 뒤판이 거절한 값이 화면에만 켜져 있지 않게 한다.

import QtQuick
import qs.Rice

Item {
    id: root

    property bool checked: false
    signal toggled(bool v)

    implicitWidth: 38
    implicitHeight: 22
    activeFocusOnTab: true

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.toggled(!root.checked);
            e.accepted = true;
        }
    }

    // 꺼진 쪽에도 테두리와 손잡이를 준다. 트랙 색만으로는 카드 배경과 안 갈리고 셰이더가 걸리면 안 보인다.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceRaised
        border.width: root.checked ? 0 : 1
        border.color: Theme.fade(Theme.outline, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.primaryText : Theme.fade(Theme.surfaceText, 0.55)

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durFast
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        visible: root.activeFocus
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggled(!root.checked);
        }
    }
}
