// 값 맞추기. 무엇이 손잡이인지, 범위가 얼마인지, 지금 값이 뭔지 전부
// apps/rice-knobs 가 준다 — 그건 다시 셰이더 파일의 `// @0..1` 표시를 읽는다.
// 셰이더에 값을 하나 더 만들고 표시만 붙이면 이 파일을 안 고쳐도 슬라이더가 는다.
//
// 그룹 순서는 파일에 나온 순서를 지킨다. 값들이 형태 → 광학 → 줄무늬 → 색으로
// 배열돼 있는 데에 이유가 있어서, 이름순으로 섞으면 읽기 나빠진다.
//
// 쓰는 곳은 언제나 $HOME 이다. 레포와 다른 값에는 되돌리기가 뜨고, 레포에 넣는
// 것은 값이 자리 잡은 뒤 apps/rice-save 로 한 번에.

import QtQuick
import qs.Rice
import qs.Ui

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surfaceContainer

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Txt {
            text: "값"
            font.pixelSize: Theme.fontS
            font.weight: Font.Medium
            color: Theme.primary
        }

        // 대상 고르기. 걸린 칸이 앞에 오고 번호가 붙는다(apps/rice-knobs 의 pass) —
        // 체인에서는 같은 두 셰이더도 순서가 바뀌면 다른 그림이라, 어느 칸을
        // 만지고 있는지가 이름만으로는 부족하다.
        Flickable {
            width: parent.width
            height: 32
            contentWidth: chips.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: chips
                spacing: Theme.spacingXS

                Repeater {
                    model: Knobs.targets

                    Rectangle {
                        required property var modelData

                        readonly property bool picked: modelData.id === Knobs.target

                        width: chipText.implicitWidth + Theme.spacingM * 2
                        height: 28
                        radius: 14
                        color: picked ? Theme.fade(Theme.primary, 0.22) : Theme.surfaceContainerHighest
                        border.width: picked ? 1 : 0
                        border.color: Theme.primary

                        Txt {
                            id: chipText
                            anchors.centerIn: parent
                            text: (modelData.pass ? modelData.pass + "·" : "") + modelData.id
                            font.pixelSize: Theme.fontS
                            color: picked ? Theme.primary : (modelData.applied ? Theme.onSurface : Theme.onSurfaceVariant)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Knobs.selectTarget(modelData.id)
                        }
                    }
                }
            }
        }

        Txt {
            width: parent.width
            visible: Knobs.error !== ""
            text: Knobs.error
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            font.pixelSize: Theme.fontS
            color: Theme.error
        }

        Flickable {
            width: parent.width
            height: parent.height - y
            contentHeight: knobCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: knobCol
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: Knobs.groups

                    Column {
                        required property var modelData

                        width: knobCol.width
                        spacing: Theme.spacingXS

                        // 구역 이름은 셰이더가 `// ── 형태 ────` 로 스스로 나눠
                        // 둔 것이다(apps/rice-knobs). 안 나눠 둔 셰이더도 있고,
                        // 그때 "값"이라고 적어 두면 패널 머리와 같은 말이 두 번
                        // 나온다 — 없으면 그냥 안 그린다.
                        Txt {
                            visible: (modelData.label || "") !== ""
                            height: visible ? implicitHeight : 0
                            text: modelData.label
                            font.pixelSize: Theme.fontS
                            color: Theme.onSurfaceVariant
                            topPadding: Theme.spacingS
                        }

                        Repeater {
                            model: modelData.knobs

                            Column {
                                id: knob

                                required property var modelData

                                width: knobCol.width
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: knob.modelData.name
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.fontS
                                    }

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: slider.live.toFixed(3).replace(/0+$/, "").replace(/\.$/, ".0")
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.fontS
                                        color: Theme.primary
                                    }

                                    // 이 값을 0 으로 내리면 흐르는 것이 멈춘다는
                                    // 표시. 배터리 값이 통째로 여기 붙어 있어서
                                    // (debug:vfr), 어느 손잡이가 그런 손잡이인지
                                    // 보이는 편이 낫다.
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: knob.modelData.motion === true
                                        text: "흐름"
                                        font.pixelSize: Theme.fontS
                                        color: Theme.fade(Theme.onSurfaceVariant, 0.8)
                                    }

                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: knob.modelData.dirty === true
                                        text: "· 레포 " + knob.modelData.repo
                                        font.pixelSize: Theme.fontS
                                        color: Theme.onSurfaceVariant
                                    }

                                    Btn {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: knob.modelData.dirty === true
                                        width: 52
                                        kind: "ghost"
                                        text: "되돌리기"
                                        onClicked: Knobs.reset(knob.modelData.name)
                                    }
                                }

                                Slide {
                                    id: slider
                                    width: parent.width
                                    minimum: knob.modelData.min
                                    maximum: knob.modelData.max
                                    step: knob.modelData.step
                                    value: knob.modelData.value
                                    onMoved: v => Knobs.push(knob.modelData.name, v, false)
                                    onReleased: v => Knobs.push(knob.modelData.name, v, true)
                                }

                                Txt {
                                    width: parent.width
                                    visible: (knob.modelData.doc || "") !== ""
                                    text: knob.modelData.doc
                                    font.pixelSize: Theme.fontS
                                    color: Theme.fade(Theme.onSurfaceVariant, 0.85)
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
