// 누르는 것. 세 모양이 있다:
//
//   kind: "filled"   주 동작 (지금 것을 걸기)
//   kind: "tonal"    보통
//   kind: "ghost"    목록 안의 작은 것
//
// ── 못 누르는 것도 보여야 한다 ────────────────────────────────────────────
// 못 하는 일을 목록에서 아예 빼는 대신 흐리게 두는 자리가 있다 — 체인에 더할 수
// 없는 칸이 그렇다. 왜 못 하는지를 같이 보여 줘야 하는데, 빼 버리면 그 자리가
// 없어진다.
//
// 그래서 `opacity` 를 통째로 내리지 않고 잉크만 죽인다. 통째로 내리면 배경까지
// 같이 사라지는데, 배경이 원래 없는 ghost 는 그러면 글자만 남아서 어두운 쪽에서
// 단추가 거기 있었다는 것 자체가 안 보인다.
//
// ── enabled 를 다시 선언하지 않는다 ───────────────────────────────────────
// Item 이 이미 갖고 있는 것이라 다시 선언하면 그것을 가린다. 그러면 부모를 통째로
// 꺼도(`enabled: false`) 이 단추만 계속 눌린다.

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

    // 호버와 누름은 배경 위에 겹쳐서 낸다. 배경색을 직접 밝히면 ghost 처럼 배경이
    // 투명한 모양에서는 밝힐 것이 없어서 아무 반응도 안 보인다.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.enabled && (area.containsMouse || area.pressed)
        color: area.pressed ? Theme.pressWash : Theme.hoverWash
    }

    // 키보드로 옮겨 다닐 때 지금 어디인지. 바깥으로 3px 나가므로, 잘라 내는
    // (clip) 목록 안에 놓을 때는 그만큼 여백이 있어야 링이 안 잘린다.
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
