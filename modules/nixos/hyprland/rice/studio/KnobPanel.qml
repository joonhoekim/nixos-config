// 값 맞추기. 무엇이 손잡이인지, 범위가 얼마인지, 지금 값이 뭔지 전부
// apps/rice-knobs 가 준다 — 그건 다시 셰이더 파일의 `// @0..1` 표시를 읽는다.
// 셰이더에 값을 하나 더 만들고 표시만 붙이면 이 파일을 안 고쳐도 슬라이더가 는다.
//
// 그룹 순서는 파일에 나온 순서를 지킨다. 값들이 형태 → 광학 → 줄무늬 → 색으로
// 배열돼 있는 데에 이유가 있어서, 이름순으로 섞으면 읽기 나빠진다.
//
// 쓰는 곳은 언제나 $HOME 이다. 레포와 다른 값에는 되돌리기가 뜨고, 레포에 넣는
// 것은 값이 자리 잡은 뒤 apps/rice-save 로 한 번에.
//
// 줄 자체는 Ui/KnobRow.qml 이 그린다 — 장식 탭과 같은 것을 쓴다.

import QtQuick
import qs.Rice
import qs.Ui

Panel {
    id: root

    // 마우스가 지나간 마지막 손잡이의 설명. 줄에서 마우스가 빠져도 안 지운다 —
    // 줄 사이를 옮겨 다닐 때마다 띠가 깜빡이면 읽는 것보다 눈에 더 걸린다.
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
        // 걸린 칸이 앞에 오고 번호가 붙는다(apps/rice-knobs 의 pass) — 체인에서는
        // 같은 두 셰이더도 순서가 바뀌면 다른 그림이라, 어느 칸을 만지고 있는지가
        // 이름만으로는 부족하다.
        //
        // 가로로 흘리지 않고 접는다. 흘리면 열 몇 개 중 뒤쪽 서넛이 잘려 나가는데,
        // 가로 스크롤에는 잡을 것도 표시도 없어서 그게 전부인 줄 안다.
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
                    // 걸려 있는 것은 안 골랐어도 밝게 둔다 — 지금 화면에 보이는
                    // 것이 어느 것인지가 목록에서 먼저 읽혀야 한다.
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

                        // 구역 이름은 셰이더가 `// ── 형태 ────` 로 스스로 나눠
                        // 둔 것이다(apps/rice-knobs). 안 나눠 둔 셰이더도 있고,
                        // 그때 "값"이라고 적어 두면 패널 머리와 같은 말이 두 번
                        // 나온다 — 없으면 그냥 안 그린다.
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
