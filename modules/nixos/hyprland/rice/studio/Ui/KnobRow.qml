// 값 하나를 맞추는 줄. 셰이더 손잡이(KnobPanel)와 하이프랜드 장식(DecorTab)이
// 같은 것을 쓴다. 두 축은 뒤판도 되돌리기 기준도 다르지만 화면에서 하는 일은
// 같다 — 이름을 보고, 지금 값을 보고, 끌고, 기본값으로 되돌린다.
//
// ── 칸 너비를 고정한다 ────────────────────────────────────────────────────
// 이름·값·흐름·되돌리기 칸은 내용이 없어도 자리를 지킨다. 내용에 맞춰 줄이면
// 한 구역 안에서도 줄마다 슬라이더 시작점이 달라져서, 여러 값을 잇달아 맞출 때
// 손이 매번 다른 자리로 가야 한다. 특히 장식 쪽은 한 구역에 불리언과 실수가
// 섞여 있어서(흐리게 그룹) 값 칸을 비워 두지 않으면 눈에 띄게 어긋난다.
//
// ── 슬라이더에 최대 폭이 있다 ─────────────────────────────────────────────
// 0..1 값을 창 폭만큼 늘여 놓으면 한 픽셀이 눈금 하나보다 훨씬 잘아져서 오히려
// 맞추기 어렵고, 값 숫자가 손잡이에서 멀어진다. 남는 폭은 그냥 비워 둔다.
//
// ── 설명은 기본으로 접는다 ────────────────────────────────────────────────
// 이 줄은 설명을 자기가 펴고 접지 않는다. 접힌 상태에서 마우스를 올리면 패널이
// 자기 아래쪽 띠에 `docLine` 을 띄우고, 스위치를 켜면 줄 안에 그대로 편다.
// 호버 때 줄 안에서 폈다 접었다 하면 마우스 밑에서 목록이 튀어서, 옆 줄을 보려고
// 움직이는 동안 손잡이가 따라 도망간다.

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
    // 되돌리면 갈 값. 셰이더는 레포 사본, 장식은 하이프랜드 기본값이다.
    property string resetTo: ""
    property string resetLabel: ""
    property string doc: ""

    property bool showDoc: false

    signal moved(real v)
    signal committed(real v)
    signal reverted

    readonly property bool isBool: kind === "bool"
    readonly property bool hovered: hover.hovered

    // 되돌릴 곳은 설명에 붙는다 — 줄 안에는 되돌리기 단추만 두고 그 값은 안 적기
    // 때문에, 무엇으로 돌아가는지는 설명에서만 보인다.
    readonly property string docTail: dirty && resetTo !== "" ? "   · " + resetLabel + " " + resetTo : ""

    // 띠에 띄울 것에는 이름이 붙는다. 띠는 목록에서 떨어져 있어서 어느 손잡이
    // 이야기인지가 글에 없으면 안 된다.
    readonly property string docLine: name + (doc !== "" ? " — " + doc : "") + docTail

    // 줄 안에 펴는 것에는 안 붙인다. 왼쪽 칸에 이미 있는 이름을 한 줄 아래에서
    // 또 읽게 된다.
    readonly property string docInline: doc + docTail

    // 눈금 크기가 소수 몇째 자리까지 뜻이 있는지 정한다. 눈금은 셰이더가 스스로
    // 정하거나 범위의 1/100 이라 0.0038 같은 값이 온다(apps/rice-knobs). 자리를
    // 고정해 두면 그런 눈금에서 화면에 안 보이는 자리가 생긴다.
    //
    // 최소 한 자리는 남긴다. 0 자리로 깎으면 뒤의 0 을 떼는 규칙이 "40" 을 "4" 로
    // 만든다.
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

        // 불리언은 값 글자가 없다 — 스위치가 곧 값이다. 그래도 칸은 남긴다.
        Txt {
            width: 48
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            visible: !root.isBool
            text: root.fmt(slider.live)
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontS
            // 기본값과 다르다는 것을 색으로 먼저 알린다. 되돌리기 단추는 그
            // 확인이지 첫 신호가 아니다.
            color: root.dirty ? Theme.primary : Theme.surfaceText
        }

        Item {
            width: 48
            height: 1
            visible: root.isBool
        }

        // 이 값을 0 으로 내리면 흐르는 것이 멈춘다는 표시. 배터리 값이 통째로
        // 여기 붙어 있어서(debug:vfr), 어느 손잡이가 그런 손잡이인지 보이는 편이
        // 낫다.
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
                // 남는 폭은 비워 둔다. 끝까지 늘이면 한 픽셀이 눈금보다 잘아진다.
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

        // 되돌리기. 어디로 되돌아가는지는 설명 줄에 적힌다 — 줄마다 그 값을 달면
        // 거의 안 쓰는 것에 슬라이더 폭을 계속 내주게 된다.
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
