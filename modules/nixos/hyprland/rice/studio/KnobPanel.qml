// 값 맞추기. 손잡이·범위·값은 apps/rice/knobs 가 셰이더의 `// @0..1` 표시를 읽어 준다.
// 그룹은 파일 순서(형태 → 광학 → 줄무늬 → 색)를 지킨다. 쓰는 곳은 $HOME, 레포로는 apps/rice/save.

import QtQuick
import qs.Rice
import qs.Ui

Panel {
    id: root

    // 줄에서 빠져도 안 지운다 — 줄 사이를 옮길 때마다 띠가 깜빡이면 눈에 걸린다.
    property string docHint: ""
    property bool showDocs: false

    // 대상이 바뀌면 앞의 설명은 남의 것이 된다.
    Connections {
        target: Knobs
        function onTargetChanged() {
            root.docHint = "";
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingM

        // ── 머리 ──────────────────────────────────────────────────────────
        Item {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.hit

            Head {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "값"
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "설명 보기"
                    font.pixelSize: Theme.fontS
                    color: Theme.surfaceVariantText
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.showDocs
                    onToggled: v => root.showDocs = v
                }
            }
        }

        // ── 대상 고르기 ───────────────────────────────────────────────────
        // 걸린 칸이 앞에 번호와 함께 온다(apps/rice/knobs 의 pass). 가로 스크롤 대신 접는다 —
        // 가로 스크롤은 표시가 없어 뒤쪽이 잘린 줄 모른다.
        Flow {
            id: chips
            anchors.top: head.bottom
            anchors.topMargin: Theme.spacingS
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spacingXS

            Repeater {
                model: Knobs.targets

                Chip {
                    required property var modelData

                    text: (modelData.pass ? modelData.pass + "·" : "") + modelData.id
                    picked: modelData.id === Knobs.target
                    // 지금 화면에 보이는 것이 먼저 읽히게 걸린 것은 밝게 둔다.
                    idleInk: modelData.applied ? Theme.surfaceText : Theme.surfaceVariantText
                    onClicked: Knobs.selectTarget(modelData.id)
                }
            }
        }

        Txt {
            id: err
            anchors.top: chips.bottom
            anchors.topMargin: visible ? Theme.spacingS : 0
            anchors.left: parent.left
            anchors.right: parent.right
            visible: Knobs.error !== ""
            height: visible ? implicitHeight : 0
            text: Knobs.error
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            font.pixelSize: Theme.fontS
            color: Theme.error
        }

        // ── 손잡이 ────────────────────────────────────────────────────────
        Scroller {
            id: list
            anchors.top: err.bottom
            anchors.topMargin: Theme.spacingS
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: strip.top
            anchors.bottomMargin: Theme.spacingXS
            contentHeight: knobCol.implicitHeight

            Column {
                id: knobCol
                width: list.width - list.barSpace
                spacing: Theme.spacingXS

                Repeater {
                    model: Knobs.groups

                    Column {
                        required property var modelData

                        width: knobCol.width
                        spacing: Theme.spacingXS

                        // 구역은 셰이더의 `// ── 형태 ────` 줄(apps/rice/knobs). 없으면 안 그린다
                        // ("값"이라 적으면 패널 머리와 겹친다).
                        Head {
                            visible: (modelData.label || "") !== ""
                            height: visible ? implicitHeight + Theme.spacingS : 0
                            verticalAlignment: Text.AlignBottom
                            text: modelData.label || ""
                        }

                        Repeater {
                            model: modelData.knobs

                            KnobRow {
                                required property var modelData

                                width: knobCol.width
                                name: modelData.name
                                value: modelData.value
                                minimum: modelData.min
                                maximum: modelData.max
                                step: modelData.step
                                motion: modelData.motion === true
                                dirty: modelData.dirty === true
                                resetTo: String(modelData.repo)
                                resetLabel: "레포"
                                doc: modelData.doc || ""
                                showDoc: root.showDocs

                                onHoveredChanged: if (hovered)
                                    root.docHint = docLine
                                onMoved: v => Knobs.push(modelData.name, v, false)
                                onCommitted: v => Knobs.push(modelData.name, v, true)
                                onReverted: Knobs.reset(modelData.name)
                            }
                        }
                    }
                }
            }
        }

        DocStrip {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: !root.showDocs
            height: visible ? implicitHeight : 0
            text: root.docHint
            hint: Knobs.groups.length > 0 ? "손잡이에 마우스를 올리면 여기 설명이 뜬다. 전부 펴려면 위의 설명 보기." : ""
        }
    }
}
