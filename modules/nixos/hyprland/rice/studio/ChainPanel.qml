// 지금 걸린 체인. 앞칸의 출력이 뒷칸 입력이라 순서가 곧 뜻이고, 몇째 칸인지 보인다.
// 마지막 한 칸을 빼면 묻지 않고 off 다. 화살표는 키보드로 닿는 유일한 길이라 끌기와 같이 둔다.
// 끄는 동안에는 rice-crt 를 안 부른다(중간 순서마다 화면이 번쩍인다). 손을 떼면 applyStages 한 번.

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

        // Column 은 자식의 y 를 자기가 정해서, 끄는 칸의 y 를 손이 잡을 수 없다.
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

                    // 바인딩을 그대로 두면 끄는 즉시 제자리로 되돌아간다.
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

                    // 단추보다 먼저 선언해야 ↑↓× 가 위에 얹혀 자기 클릭을 먼저 받는다.
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
