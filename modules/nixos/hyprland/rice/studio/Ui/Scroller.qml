// 스크롤되는 자리. Flickable 에 손잡이 막대를 붙인 것뿐이다.
//
// ── 막대가 없으면 잘린 줄을 모른다 ────────────────────────────────────────
// 이 창의 목록 셋(셰이더 목록·손잡이·장식)은 전부 잘라 내며 그리기 때문에 넘치는
// 줄이 소리 없이 사라진다. 마지막 손잡이가 반쯤 잘려 있어도 그게 "여기가 끝"인지
// "더 있는데 잘린 것"인지 구별할 방법이 화면에 없었다.
//
// 막대는 넘칠 때만 나오고, 끄는 중이거나 마우스가 올라와 있을 때만 진해진다.
// 늘 진하면 값 맞추는 화면에서 눈이 자꾸 그쪽으로 간다.
//
// ── Flickable 을 감싸는 이유 ──────────────────────────────────────────────
// Flickable 안에 그냥 넣은 자식은 내용물 쪽으로 들어가서 **막대가 내용과 같이
// 스크롤된다**. 그래서 Flickable 을 Item 으로 한 겹 싸고 막대를 그 형제로 둔다.
// 내용은 `content` 로 들어가 Flickable 안에 그대로 놓이므로, 부르는 쪽에서는
// 예전처럼 `width: parent.width` 를 쓰면 된다.

import QtQuick
import qs.Rice

Item {
    id: root

    // 막대가 내용을 가리지 않게 오른쪽에 비워 두는 폭. 안에 놓는 것이 자기 폭을
    // 정할 때 이만큼 뺀다.
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
