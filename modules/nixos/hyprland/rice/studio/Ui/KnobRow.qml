// 값 하나를 맞추는 줄(KnobPanel·DecorTab 공용).
// 칸 너비는 내용이 없어도 고정한다 — 줄이면 줄마다 슬라이더 시작점이 달라진다.
// 설명은 호버 때 줄 안에서 펴지 않고 패널 아래 띠에 띄운다(펴면 목록이 마우스 밑에서 튄다).

import QtQuick
import qs.Rice

Column {
    id: root

    property string name: ""
    property string kind: "float"   // float | int | bool
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.01

    property bool motion: false
    property bool dirty: false
    // 셰이더는 레포 사본, 장식은 하이프랜드 기본값.
    property string resetTo: ""
    property string resetLabel: ""
    property string doc: ""

    property bool showDoc: false

    signal moved(real v)
    signal committed(real v)
    signal reverted

    readonly property bool isBool: kind === "bool"
    readonly property bool hovered: hover.hovered

    // 되돌릴 값은 줄에 안 적어서 설명에만 보인다.
    readonly property string docTail: dirty && resetTo !== "" ? "   · " + resetLabel + " " + resetTo : ""

    // 띠는 목록에서 떨어져 있어 어느 손잡이인지 이름을 붙인다.
    readonly property string docLine: name + (doc !== "" ? " — " + doc : "") + docTail

    readonly property string docInline: doc + docTail

    // 눈금은 0.0038 같은 값도 온다(apps/rice/knobs). 최소 한 자리는 남긴다 —
    // 0 자리면 뒤의 0 을 떼는 규칙이 "40" 을 "4" 로 만든다.
    readonly property int decimals: Math.max(1, Math.min(4, Math.ceil(-Math.log(step) / Math.LN10 - 1e-9)))

    function fmt(v) {
        if (kind === "int")
            return String(Math.round(v));
        return v.toFixed(decimals).replace(/0+$/, "").replace(/\.$/, ".0");
    }

    spacing: 2

    HoverHandler {
        id: hover
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        Txt {
            width: 132
            anchors.verticalCenter: parent.verticalCenter
            text: root.name
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontS
        }

        Txt {
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            visible: !root.isBool
            text: root.fmt(slider.live)
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontS
            color: root.dirty ? Theme.primary : Theme.surfaceText
        }

        Item {
            width: 48
            height: 1
            visible: root.isBool
        }

        // `!motion` 표시. 배터리 값(debug:vfr)이 이 손잡이에 붙어 있다.
        Txt {
            width: 32
            anchors.verticalCenter: parent.verticalCenter
            text: root.motion ? "흐름" : ""
            font.pixelSize: Theme.fontS
            color: Theme.fade(Theme.surfaceVariantText, 0.8)
        }

        Item {
            id: control

            width: parent.width - 132 - 48 - 32 - Theme.hit - Theme.spacingS * 4
            height: Math.max(slider.implicitHeight, toggle.implicitHeight)
            anchors.verticalCenter: parent.verticalCenter

            Slide {
                id: slider
                visible: !root.isBool
                // 끝까지 늘이면 한 픽셀이 눈금보다 잘아진다.
                width: Math.min(parent.width, 380)
                anchors.verticalCenter: parent.verticalCenter
                minimum: root.minimum
                maximum: root.maximum
                step: root.step
                value: root.value
                onMoved: v => root.moved(v)
                onReleased: v => root.committed(v)
            }

            Toggle {
                id: toggle
                visible: root.isBool
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                checked: root.value === 1
                onToggled: v => root.committed(v ? 1 : 0)
            }
        }

        Btn {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.hit
            kind: "ghost"
            text: "↺"
            visible: root.dirty
            onClicked: root.reverted()
        }

        Item {
            width: Theme.hit
            height: 1
            visible: !root.dirty
        }
    }

    Txt {
        width: parent.width
        visible: root.showDoc && root.doc !== ""
        height: visible ? implicitHeight : 0
        text: root.docInline
        font.pixelSize: Theme.fontS
        color: Theme.fade(Theme.surfaceVariantText, 0.85)
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        bottomPadding: Theme.spacingXS
    }
}
