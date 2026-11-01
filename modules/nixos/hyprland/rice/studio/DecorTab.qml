// 장식 탭 — 하이프랜드의 투명도·흐리게·어둡게·그림자. 뒤판은 apps/rice/decor.
// 둥글기·간격·보더는 DMS 설정 GUI 가 소유해서 뒤판 표에서 뺐다(같이 쓰면 그쪽 슬라이더가 말없이 무효).
// 왜 셰이더와 같은 창인가: docs/rice-studio.md. 되돌리기 기준은 레포가 아니라 하이프랜드 기본값.

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
                        // 파일에는 기본값에서 벗어난 줄만 남는다.
                        let s = "기본값과 다른 값만 " + Decor.file + " 에 남는다";
                        // 세션이 없으면 파일에만 적혀 끌어도 화면이 안 바뀐다.
                        if (!Decor.session)
                            s += " · 하이프랜드 세션이 아니다 — 고친 값은 다음 로그인부터";
                        return s;
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

                            // anchors.fill 이면 카드 높이 ← 내용 높이 ← 카드 높이 바인딩 루프 경고가 뜬다.
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
                                        // 이 축에는 레포 사본이 없다.
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
