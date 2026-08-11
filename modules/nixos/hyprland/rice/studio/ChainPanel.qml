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

import QtQuick
import qs.Rice
import qs.Ui

Rectangle {
    id: root

    implicitHeight: body.implicitHeight + Theme.spacingM * 2
    radius: Theme.radius
    color: Theme.surfaceContainer

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Txt {
            text: "체인"
            font.pixelSize: Theme.fontS
            font.weight: Font.Medium
            color: Theme.primary
        }

        Txt {
            width: parent.width
            visible: Shaders.chain.length === 0
            text: "지금은 off 다. 왼쪽에서 하나 고르면 걸리고, 그 뒤로 ＋ 로 얹는다."
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            font.pixelSize: Theme.fontS
            color: Theme.onSurfaceVariant
        }

        Repeater {
            model: Shaders.chain

            Rectangle {
                id: stage

                required property string modelData
                required property int index

                readonly property var v: Shaders.valueOf(modelData)

                width: body.width
                height: 38
                radius: Theme.radiusS
                color: Theme.surfaceContainerHighest

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
                            text: stage.index + 1
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
                        color: Theme.onSurfaceVariant
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    Btn {
                        width: 28
                        kind: "ghost"
                        text: "↑"
                        enabled: stage.index > 0 && !Shaders.busy
                        onClicked: Shaders.move(stage.index, -1)
                    }

                    Btn {
                        width: 28
                        kind: "ghost"
                        text: "↓"
                        enabled: stage.index < Shaders.chain.length - 1 && !Shaders.busy
                        onClicked: Shaders.move(stage.index, 1)
                    }

                    Btn {
                        width: 28
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
