// Flickable + 손잡이 막대. 목록이 clip 이라 막대가 없으면 넘친 줄이 소리 없이 사라진다.
// Flickable 을 Item 으로 싸고 막대를 형제로 둔다 — 안에 넣으면 막대가 내용과 같이 스크롤된다.

import QtQuick
import qs.Rice

Item {
    id: root

    // 막대가 내용을 가리지 않게 비워 두는 폭.
    readonly property int barSpace: 10

    property alias contentHeight: flick.contentHeight
    property alias contentWidth: flick.contentWidth
    property alias contentY: flick.contentY
    property alias flickableDirection: flick.flickableDirection
    default property alias content: flick.flickableData

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
    }

    Rectangle {
        readonly property real trackH: root.height - Theme.spacingXS * 2
        readonly property real over: Math.max(1, flick.contentHeight - flick.height)

        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 4
        radius: 2
        visible: flick.contentHeight > flick.height + 1
        height: Math.max(24, trackH * Math.min(1, flick.height / Math.max(1, flick.contentHeight)))
        y: Theme.spacingXS + Math.max(0, Math.min(1, flick.contentY / over)) * (trackH - height)
        color: flick.moving || hover.hovered ? Theme.fade(Theme.surfaceText, 0.45) : Theme.fade(Theme.surfaceText, 0.18)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durBase
            }
        }
    }

    HoverHandler {
        id: hover
    }
}
