// 슬라이더. Qt Quick Controls 를 안 쓰는 것은 스타일 때문이다 — DMS 는 프로세스
// 환경에 QT_QUICK_CONTROLS_STYLE=Material 을 박아 두고 시작하는데, 여기는 별도
// 프로세스라 그 환경이 없다. 기본 스타일을 다시 칠하는 것보다 이게 짧다.
//
// ── 값은 눈금 인덱스로 다룬다 ─────────────────────────────────────────────
// 실수로 다루면 0.013999999999999999 같은 것이 화면에 뜬다. 눈금 개수를 최대값으로
// 두고 인덱스만 정수로 굴린 뒤, 밖으로 낼 때만 실수로 되돌린다. 눈금 크기는
// 셰이더가 `@0..1:0.01` 로 스스로 정하거나 범위의 1/100 이다(apps/rice-knobs).
//
// ── 손잡이를 잡으면 안 튄다 ───────────────────────────────────────────────
// 트랙을 누르면 그 자리로 뛰지만, 손잡이 위를 누르면 값을 안 건드리고 끌기만
// 시작한다. 둘을 안 가르면 미세하게 고치려고 손잡이를 잡는 순간 값이 한 번 튀고,
// 이 값들은 누르는 즉시 화면 전체에 걸리므로 그 튐이 그대로 보인다.
//
// ── 휠은 포커스가 있을 때만 ───────────────────────────────────────────────
// 같은 이유로, 손잡이 목록을 스크롤하다 지나가는 것만으로 값이 바뀌면 안 된다.
// 한 번 누르거나 탭으로 들어와서 이 슬라이더를 고르고 있을 때만 휠을 받는다.

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

    readonly property int knob: 14
    // 손잡이 중심이 다니는 거리. 트랙 폭 그대로 쓰면 양 끝에서 손잡이가 반씩
    // 삐져나간다.
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

    // 손잡이 중심 기준의 x 를 인덱스로.
    function setFromX(x) {
        setIndex(Math.round(((x - knob / 2) / span) * steps), true);
    }

    // 키보드·휠 한 칸. 뗄 손이 없으므로 잠깐 뒤에 확정을 한 번 보낸다 — 눌러
    // 두고 있는 동안은 moved 로만 흘리고, 멈추면 released 가 마지막 값을 쓴다.
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
        // 손잡이를 트랙에서 떼어 놓는 테두리. 슬라이더는 언제나 카드 위에 있으므로
        // 창 배경이 아니라 카드 색을 두른다 — 창 배경을 두르면 카드 위에 배경색
        // 고리가 얹혀서 손잡이 주위만 구멍이 뚫린 것처럼 보인다.
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
        // 4px 트랙을 정확히 맞춰 누르게 하면 안 된다. 위아래로 넓혀 둔다.
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.forceActiveFocus();
            root.dragging = true;
            // 손잡이 위를 눌렀으면 값을 안 건드린다.
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
