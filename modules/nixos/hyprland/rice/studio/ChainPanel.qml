// 지금 걸린 체인. 칸이 위에서 아래로 겹치는 순서 그대로 놓인다.
//
// ── 순서가 뜻을 가진다 ────────────────────────────────────────────────────
// 앞칸의 출력이 뒷칸의 입력이라, 같은 두 셰이더도 순서가 바뀌면 다른 그림이다.
// 그래서 이름만 늘어놓으면 안 되고 몇째 칸인지가 보여야 한다. 비용은 곱이라
// 순서를 바꿔도 안 줄지만(apps/rice-chain), 룩은 바뀐다.
//
// 마지막 한 칸을 빼면 off 다. 그건 빼기가 아니라 끄기라서 머리의 off 단추와 같은
// 일이 되는데, 여기서 조용히 그렇게 해 준다 — "빼면 off 가 된다"고 막아 세우는
// 것은 사용자가 이미 아는 것을 한 번 더 묻는 것이다.
//
// ── 끌어서 옮기는 것과 화살표를 둘 다 둔다 ────────────────────────────────
// 순서가 곧 뜻인 목록에서 자연스러운 손짓은 끌어 옮기기다. 화살표도 같이 남기는
// 것은 그게 키보드로 닿는 유일한 길이고, 칸이 둘뿐일 때는 한 번 누르는 편이
// 빠르기 때문이다.
//
// 끄는 동안에는 rice-crt 를 안 부른다. 한 칸 지날 때마다 부르면 옮기는 중간
// 순서마다 셰이더가 새로 걸려서 화면이 몇 번 번쩍이고, 그 사이 것들은 사용자가
// 원한 적 없는 조합이다. 손을 떼면 최종 순서 하나만 applyStages 로 간다.

import QtQuick
import qs.Rice
import qs.Ui

Panel {
    id: root

    readonly property int rowH: 40
    readonly property int gap: Theme.spacingXS + 2
    readonly property int pitch: rowH + gap

    // 끄는 중인 칸의 원래 자리와 지금 놓일 자리. -1 이면 아무도 안 끌고 있다.
    property int dragFrom: -1
    property int dragTo: -1

    function commitDrag() {
        if (dragFrom < 0 || dragTo < 0 || dragFrom === dragTo) {
            dragFrom = -1;
            dragTo = -1;
            return;
        }
        const next = Shaders.chain.slice();
        next.splice(dragTo, 0, next.splice(dragFrom, 1)[0]);
        dragFrom = -1;
        dragTo = -1;
        Shaders.applyStages(next);
    }

    implicitHeight: body.implicitHeight + Theme.spacingM * 2

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Head {
            text: "체인"
        }

        Txt {
            width: parent.width
            visible: Shaders.chain.length === 0
            height: visible ? implicitHeight : 0
            text: "지금은 off 다. 왼쪽에서 하나 고르면 걸리고, 그 뒤로 ＋ 로 얹는다."
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            font.pixelSize: Theme.fontS
            color: Theme.surfaceVariantText
        }

        // 칸을 Column 에 쌓지 않는다. 끄는 동안 한 칸의 y 를 손이 잡고 나머지는
        // 제 자리로 미끄러져야 하는데, Column 은 자식의 y 를 자기가 정한다.
        Item {
            id: stack
            width: parent.width
            height: Shaders.chain.length > 0 ? Shaders.chain.length * root.pitch - root.gap : 0

            Repeater {
                model: Shaders.chain

                Rectangle {
                    id: stage

                    required property string modelData
                    required property int index

                    readonly property var v: Shaders.valueOf(modelData)
                    readonly property bool held: root.dragFrom === index

                    // 끄는 칸이 지나가면 나머지가 한 칸씩 비켜선다.
                    readonly property int slot: {
                        if (root.dragFrom < 0)
                            return index;
                        if (held)
                            return root.dragTo;
                        if (root.dragFrom < index && index <= root.dragTo)
                            return index - 1;
                        if (root.dragTo <= index && index < root.dragFrom)
                            return index + 1;
                        return index;
                    }

                    width: stack.width
                    height: root.rowH
                    radius: Theme.radiusS
                    color: Theme.surfaceRaised
                    border.width: held ? 1 : 0
                    border.color: Theme.primary
                    z: held ? 2 : 1
                    scale: held ? 1.02 : 1

                    // 끄는 동안에는 y 를 손이 잡는다. 바인딩을 그대로 두면 끄는
                    // 즉시 제자리로 되돌아간다.
                    Binding {
                        target: stage
                        property: "y"
                        value: stage.slot * root.pitch
                        when: !stage.held
                        restoreMode: Binding.RestoreNone
                    }

                    Behavior on y {
                        enabled: !stage.held
                        NumberAnimation {
                            duration: Theme.durBase
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durFast
                        }
                    }

                    // 단추보다 먼저 선언한다 — 나중에 선언한 것이 위에 얹히므로
                    // ↑↓× 는 이 끌기 판을 가리고 자기 클릭을 먼저 받는다.
                    MouseArea {
                        id: grab

                        property real grabbedAt: 0

                        anchors.fill: parent
                        enabled: Shaders.chain.length > 1 && !Shaders.busy
                        cursorShape: enabled ? (stage.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                        drag.target: stage
                        drag.axis: Drag.YAxis
                        drag.minimumY: 0
                        drag.maximumY: (Shaders.chain.length - 1) * root.pitch

                        onPressed: {
                            root.dragFrom = stage.index;
                            root.dragTo = stage.index;
                        }
                        onPositionChanged: {
                            if (stage.held)
                                root.dragTo = Math.max(0, Math.min(Shaders.chain.length - 1, Math.round(stage.y / root.pitch)));
                        }
                        onReleased: root.commitDrag()
                        onCanceled: root.commitDrag()
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.fade(Theme.primary, 0.22)
                            anchors.verticalCenter: parent.verticalCenter

                            Txt {
                                anchors.centerIn: parent
                                text: stage.slot + 1
                                font.pixelSize: Theme.fontS
                                color: Theme.primary
                            }
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            text: stage.modelData
                            font.pixelSize: Theme.fontM
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: stage.v !== null
                            text: stage.v ? (stage.v.taps + "탭" + (stage.v.motion ? " · 흐름" : "")) : ""
                            font.pixelSize: Theme.fontS
                            color: Theme.surfaceVariantText
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS
                        opacity: root.dragFrom < 0 ? 1 : 0

                        Btn {
                            width: Theme.hit
                            kind: "ghost"
                            text: "↑"
                            enabled: stage.index > 0 && !Shaders.busy
                            onClicked: Shaders.move(stage.index, -1)
                        }

                        Btn {
                            width: Theme.hit
                            kind: "ghost"
                            text: "↓"
                            enabled: stage.index < Shaders.chain.length - 1 && !Shaders.busy
                            onClicked: Shaders.move(stage.index, 1)
                        }

                        Btn {
                            width: Theme.hit
                            kind: "ghost"
                            text: "×"
                            danger: true
                            enabled: !Shaders.busy
                            onClicked: Shaders.drop(stage.index)
                        }
                    }
                }
            }
        }
    }
}
