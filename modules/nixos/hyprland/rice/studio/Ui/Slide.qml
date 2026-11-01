// Qt Quick Controls 를 안 쓴다 — 별도 프로세스라 DMS 의 QT_QUICK_CONTROLS_STYLE=Material 환경이 없다.
// 값은 눈금 인덱스로 굴린다(실수면 0.013999… 가 뜬다). 손잡이를 잡으면 값이 안 튀고,
// 휠은 포커스가 있을 때만 받는다 — 값이 누르는 즉시 화면 전체에 걸리기 때문이다.

import QtQuick
import qs.Rice

Item {
    id: root

    property real minimum: 0
    property real maximum: 1
    property real step: 0.01
    property real value: 0

    // 끄는 중에는 그 값을, 손을 떼면 마지막 값을 한 번 더.
    signal moved(real v)
    signal released(real v)

    readonly property int steps: Math.max(1, Math.round((maximum - minimum) / step))
    property int index: Math.round((value - minimum) / step)

    // 끄는 동안 밖의 value 를 무시한다. 적용이 늦게 돌아와 손잡이가 뒤로 튄다.
    property bool dragging: false
    onValueChanged: if (!dragging)
        index = Math.round((value - minimum) / step)

    readonly property real live: minimum + index * step

    readonly property int knob: 14
    // 트랙 폭 그대로면 양 끝에서 손잡이가 반씩 삐져나간다.
    readonly property real span: Math.max(1, width - knob)
    readonly property real ratio: index / steps

    implicitHeight: 20
    activeFocusOnTab: true

    function setIndex(i, notify) {
        const c = Math.min(steps, Math.max(0, i));
        if (c === index)
            return;
        index = c;
        if (notify)
            root.moved(root.live);
    }

    function setFromX(x) {
        setIndex(Math.round(((x - knob / 2) / span) * steps), true);
    }

    // 키보드·휠은 뗄 손이 없어 잠깐 뒤에 확정을 한 번 보낸다.
    function nudge(d) {
        const before = index;
        setIndex(index + d, true);
        if (index !== before)
            settle.restart();
    }

    Timer {
        id: settle
        interval: 260
        onTriggered: root.released(root.live)
    }

    Keys.onPressed: e => {
        const big = (e.modifiers & Qt.ShiftModifier) ? 10 : 1;
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Down) {
            root.nudge(-big);
            e.accepted = true;
        } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Up) {
            root.nudge(big);
            e.accepted = true;
        } else if (e.key === Qt.Key_Home) {
            root.setIndex(0, true);
            settle.restart();
            e.accepted = true;
        } else if (e.key === Qt.Key_End) {
            root.setIndex(root.steps, true);
            settle.restart();
            e.accepted = true;
        }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.fade(Theme.surfaceText, 0.16)

        Rectangle {
            width: root.knob / 2 + root.span * root.ratio
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }

    Rectangle {
        id: handle
        width: root.knob
        height: root.knob
        radius: root.knob / 2
        color: Theme.primary
        // 창 배경이 아니라 카드 색을 두른다 — 창 배경이면 손잡이 주위에 구멍이 뚫려 보인다.
        border.width: 2
        border.color: Theme.surfaceCard
        x: root.span * root.ratio
        anchors.verticalCenter: parent.verticalCenter
        scale: area.containsMouse || root.dragging ? 1.25 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFast
            }
        }
    }

    Rectangle {
        anchors.fill: handle
        anchors.margins: -4
        radius: width / 2
        visible: root.activeFocus
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // 4px 트랙을 정확히 누르게 하지 않는다.
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.forceActiveFocus();
            root.dragging = true;
            if (mouse.x < handle.x || mouse.x > handle.x + handle.width)
                root.setFromX(mouse.x);
        }
        onPositionChanged: mouse => {
            if (root.dragging)
                root.setFromX(mouse.x);
        }
        onReleased: {
            root.dragging = false;
            root.released(root.live);
        }
        onWheel: wheel => {
            if (!root.activeFocus) {
                wheel.accepted = false;
                return;
            }
            root.nudge(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
