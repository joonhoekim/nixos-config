// 슬라이더. Qt Quick Controls 를 안 쓰는 것은 스타일 때문이다 — DMS 는 프로세스
// 환경에 QT_QUICK_CONTROLS_STYLE=Material 을 박아 두고 시작하는데, 여기는 별도
// 프로세스라 그 환경이 없다. 기본 스타일을 다시 칠하는 것보다 이게 짧다.
//
// ── 값은 눈금 인덱스로 다룬다 ─────────────────────────────────────────────
// 실수로 다루면 0.013999999999999999 같은 것이 화면에 뜬다. 눈금 개수를 최대값으로
// 두고 인덱스만 정수로 굴린 뒤, 밖으로 낼 때만 실수로 되돌린다. 눈금 크기는
// 셰이더가 `@0..1:0.01` 로 스스로 정하거나 범위의 1/100 이다(apps/rice-knobs).

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

    // 끄는 동안에는 밖에서 온 value 를 무시한다. 안 그러면 적용이 한 박자 늦게
    // 돌아오면서 손잡이가 뒤로 튄다.
    property bool dragging: false
    onValueChanged: if (!dragging)
        index = Math.round((value - minimum) / step)

    readonly property real live: minimum + index * step

    implicitHeight: 20

    function setFromX(x) {
        const w = Math.max(1, track.width);
        const t = Math.min(1, Math.max(0, x / w));
        const i = Math.round(t * steps);
        if (i !== index) {
            index = i;
            root.moved(root.live);
        }
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.fade(Theme.onSurface, 0.16)

        Rectangle {
            width: parent.width * (root.index / root.steps)
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: Theme.primary
        border.width: 2
        border.color: Theme.surface
        x: track.width * (root.index / root.steps) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        scale: area.containsMouse || root.dragging ? 1.2 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 90
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.dragging = true;
            root.setFromX(mouse.x + 6);
        }
        onPositionChanged: mouse => {
            if (root.dragging)
                root.setFromX(mouse.x + 6);
        }
        onReleased: {
            root.dragging = false;
            root.released(root.live);
        }
    }
}
