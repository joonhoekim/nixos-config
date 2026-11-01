// kind: filled(주 동작) · tonal(보통) · ghost(목록 안의 작은 것).
// 못 누를 때 opacity 대신 잉크만 죽인다 — 배경 없는 ghost 는 통째로 내리면 단추가 사라져 보인다.
// enabled 를 다시 선언하지 않는다. Item 의 것을 가려 부모를 꺼도 이 단추만 눌린다.

import QtQuick
import qs.Rice

Rectangle {
    id: root

    property string text: ""
    property string kind: "tonal"
    property bool danger: false

    signal clicked

    readonly property color base: {
        if (danger)
            return Theme.fade(Theme.error, 0.16);
        if (kind === "filled")
            return Theme.primary;
        if (kind === "ghost")
            return "transparent";
        return Theme.surfaceRaised;
    }

    readonly property color ink: {
        if (!enabled)
            return Theme.disabledText;
        if (danger)
            return Theme.error;
        if (kind === "filled")
            return Theme.primaryText;
        return Theme.surfaceText;
    }

    implicitWidth: label.implicitWidth + Theme.spacingM * 2
    implicitHeight: kind === "ghost" ? Theme.hit : 34
    radius: Theme.radiusS

    color: enabled ? base : Theme.fade(base, kind === "ghost" ? 0 : 0.4)

    Behavior on color {
        ColorAnimation {
            duration: Theme.durFast
        }
    }

    // 배경색을 직접 밝히면 배경이 투명한 ghost 에서는 반응이 안 보여서 겹쳐 낸다.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.enabled && (area.containsMouse || area.pressed)
        color: area.pressed ? Theme.pressWash : Theme.hoverWash
    }

    // 포커스 링. 바깥으로 3px 나가므로 clip 목록 안에서는 그만큼 여백이 있어야 한다.
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
        color: root.ink
        font.pixelSize: root.kind === "ghost" ? Theme.fontS : Theme.fontM
    }

    activeFocusOnTab: enabled

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
