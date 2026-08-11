// 누르는 것. 세 모양이 있다:
//
//   kind: "filled"   주 동작 (지금 것을 걸기)
//   kind: "tonal"    보통
//   kind: "ghost"    목록 안의 작은 것
//
// `enabled` 가 false 면 흐려지고 안 눌린다. 못 하는 일을 목록에서 아예 빼는 대신
// 흐리게 두는 자리가 있어서다 — 체인에 더할 수 없는 칸이 그렇다. 왜 못 하는지를
// 같이 보여 줘야 하는데, 빼 버리면 그 자리가 없어진다.

import QtQuick
import qs.Rice

Rectangle {
    id: root

    property string text: ""
    property string kind: "tonal"
    property bool enabled: true
    property bool danger: false

    signal clicked

    readonly property color base: {
        if (danger)
            return Theme.fade(Theme.error, 0.16);
        if (kind === "filled")
            return Theme.primary;
        if (kind === "ghost")
            return Theme.fade(Theme.onSurface, 0);
        return Theme.surfaceContainerHighest;
    }

    readonly property color ink: {
        if (danger)
            return Theme.error;
        if (kind === "filled")
            return Theme.onPrimary;
        return Theme.onSurface;
    }

    implicitWidth: label.implicitWidth + Theme.spacingM * 2
    implicitHeight: kind === "ghost" ? 26 : 32
    radius: Theme.radiusS
    opacity: enabled ? 1 : 0.38

    color: !enabled ? base : (area.pressed ? Qt.darker(base, 1.15) : (area.containsMouse ? Qt.lighter(base, kind === "ghost" ? 1.0 : 1.12) : base))

    // ghost 는 배경이 없으므로 호버를 따로 그린다.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.kind === "ghost" && root.enabled && area.containsMouse
        color: Theme.fade(Theme.onSurface, 0.08)
    }

    Txt {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.ink
        font.pixelSize: root.kind === "ghost" ? Theme.fontS : Theme.fontM
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
