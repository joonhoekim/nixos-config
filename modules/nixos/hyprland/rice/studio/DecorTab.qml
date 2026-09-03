// 장식 탭 — 하이프랜드의 투명도·흐리게·어둡게·그림자. 뒤판은 apps/rice-decor 다.
//
// ── 왜 셰이더와 같은 창인가 ───────────────────────────────────────────────
// 축의 성질로만 보면 이건 "값 하나 고르기"라 런처 쪽 일이다(shell.qml 머리말의
// 그 기준). 그래도 여기 있는 이유는 셋이다.
//
//   1. 이 창 자신이 표본이다. 투명도를 내리면 이 창이 같이 반투명해지고, 글자
//      대비가 어디서 무너지는지가 조절하는 그 자리에서 보인다.
//   2. 블러와 화면 셰이더는 같은 GPU 를 나눠 쓴다. 탭 수(셰이더 탭)와 passes
//      (여기)를 한 창에서 보고 정할 수 있어야 한다.
//   3. blur:xray 는 셰이더가 그린 결과와 겹치는 값이라 따로 놓으면 판단이 갈린다.
//
// ── 여기 없는 값들 ────────────────────────────────────────────────────────
// 둥글기·간격·보더 두께는 DMS 설정 GUI 가 소유한다(설정 → 컴포지터 레이아웃).
// 같은 키를 여기서 또 쓰면 그쪽 슬라이더가 말없이 무효가 되므로 뒤판의 표에서
// 아예 뺐다 — 자세한 사정은 apps/rice-decor 머리말.
//
// 줄 자체는 Ui/KnobRow.qml 이 그린다 — 셰이더 손잡이와 같은 것을 쓴다. 다른 것은
// 되돌리기의 기준뿐이다(레포 사본이 아니라 하이프랜드 기본값).

import QtQuick
import qs.Rice
import qs.Ui

Item {
    id: root

    property string docHint: ""
    property bool showDocs: false

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        // ── 머리 ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 56

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - headActions.width - Theme.spacingM
                spacing: 3

                Txt {
                    width: parent.width
                    text: Decor.dirtyCount > 0 ? Decor.dirtyCount + "개 바꿈" : "전부 기본값"
                    font.pixelSize: Theme.fontXL
                    font.weight: Font.Medium
                    color: Decor.dirtyCount > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                }

                Txt {
                    width: parent.width
                    font.pixelSize: Theme.fontS
                    color: Decor.error !== "" ? Theme.error : Theme.surfaceVariantText
                    text: {
                        if (Decor.error !== "")
                            return Decor.error;
                        // 파일에는 기본값에서 벗어난 줄만 남는다. 그 성질이
                        // 여기 한 줄로 보여야 "왜 파일이 비어 있나"를 안 묻는다.
                        return "기본값과 다른 값만 " + Decor.file + " 에 남는다";
                    }
                }
            }

            Row {
                id: headActions
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

                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "전부 되돌리기"
                    danger: true
                    enabled: Decor.dirtyCount > 0
                    onClicked: Decor.reset("")
                }
            }
        }

        // ── 값 ────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height - y

            Scroller {
                id: scroll
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: strip.top
                anchors.bottomMargin: Theme.spacingS
                contentHeight: groupCol.implicitHeight

                Column {
                    id: groupCol
                    width: scroll.width - scroll.barSpace
                    spacing: Theme.spacingM

                    Repeater {
                        model: Decor.groups

                        Panel {
                            required property var modelData

                            width: groupCol.width
                            height: groupBody.implicitHeight + Theme.spacingM * 2

                            // anchors.fill 을 안 쓴다. 그러면 높이가 서로를 가리켜
                            // (카드 높이 ← 내용 높이 ← 카드 높이) 바인딩 루프 경고가
                            // 뜬다. 자리만 직접 잡으면 방향이 한쪽으로만 흐른다.
                            Column {
                                id: groupBody
                                x: Theme.spacingM
                                y: Theme.spacingM
                                width: parent.width - Theme.spacingM * 2
                                spacing: Theme.spacingXS

                                Head {
                                    text: modelData.label
                                    bottomPadding: Theme.spacingXS
                                }

                                Repeater {
                                    model: modelData.knobs

                                    KnobRow {
                                        required property var modelData

                                        width: groupBody.width
                                        name: modelData.name
                                        kind: modelData.type
                                        value: modelData.value
                                        minimum: modelData.min
                                        maximum: modelData.max
                                        step: modelData.step
                                        dirty: modelData.dirty === true
                                        // 되돌릴 곳이 레포가 아니라 하이프랜드
                                        // 기본값이다 — 이 축에는 레포 사본이 없다.
                                        resetTo: modelData.type === "bool" ? (modelData.default === 1 ? "켬" : "끔") : String(modelData.default)
                                        resetLabel: "기본"
                                        doc: modelData.doc || ""
                                        showDoc: root.showDocs

                                        onHoveredChanged: if (hovered)
                                            root.docHint = docLine
                                        onMoved: v => Decor.push(modelData.key, v, false)
                                        onCommitted: v => Decor.push(modelData.key, v, true)
                                        onReverted: Decor.reset(modelData.key)
                                    }
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
                hint: Decor.groups.length > 0 ? "값에 마우스를 올리면 여기 설명이 뜬다. 전부 펴려면 위의 설명 보기." : ""
            }
        }
    }
}
