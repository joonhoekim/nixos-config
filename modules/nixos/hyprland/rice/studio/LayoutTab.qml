// 배치 탭 — 하이프랜드 레이아웃을 고르고 그 값을 맞춘다. 뒤판은 apps/rice/layout.
// 손잡이는 지금 걸린 배치의 것만 띄운다(안 걸린 값을 끌면 아무 일도 없어 고장으로 보인다).
// 왜 이 창에 있는가: docs/rice-studio.md

import QtQuick
import qs.Rice
import qs.Ui

Item {
    id: root

    signal note(string msg)

    property string docHint: ""
    property bool showDocs: false

    // 마우스가 올라가 있는 배치. 비어 있으면 아래 띠가 지금 걸린 것을 설명한다.
    property string hoverName: ""
    readonly property var described: Layouts.valueOf(hoverName !== "" ? hoverName : Layouts.current)

    readonly property int railW: Math.round(Math.max(280, Math.min(340, width * 0.3)))

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
                    text: Layouts.current !== "" ? Layouts.current : "배치 없음"
                    font.pixelSize: Theme.fontXL
                    font.weight: Font.Medium
                    color: Layouts.current !== "" ? Theme.surfaceText : Theme.surfaceVariantText
                }

                Txt {
                    width: parent.width
                    font.pixelSize: Theme.fontS
                    color: Layouts.error !== "" ? Theme.error : Theme.surfaceVariantText
                    text: {
                        if (Layouts.error !== "")
                            return Layouts.error;
                        // 키바인드를 어디서 고치는지 알려 준다.
                        let s = Layouts.file;
                        if (Layouts.dirtyCount > 0)
                            s += " · 레포와 다른 값 " + Layouts.dirtyCount;
                        if (!Layouts.session)
                            s += " · 하이프랜드 세션이 아니다 — 고른 것은 다음 로그인부터";
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

                // dofile 로 읽는 파일이라 하이프랜드가 감시하지 않는다 — 손으로 고쳐도 저절로 안 반영된다.
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "다시 읽기"
                    enabled: Layouts.session && !Layouts.busy
                    onClicked: Layouts.reload()
                }

                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "값 전부 레포로"
                    danger: true
                    enabled: Layouts.dirtyCount > 0
                    onClicked: Layouts.reset("")
                }
            }
        }

        // ── 본문 ──────────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: parent.height - y
            spacing: Theme.spacingM

            // 왼쪽: 배치 목록. 줄을 누르면 그 자리에서 걸린다.
            Panel {
                width: root.railW
                height: parent.height

                Scroller {
                    id: list
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: about.top
                    anchors.margins: Theme.spacingS
                    contentHeight: listCol.implicitHeight

                    Column {
                        id: listCol
                        width: list.width - Theme.spacingS * 2 - list.barSpace
                        spacing: 1

                        Item {
                            width: listCol.width
                            height: 30

                            Head {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                text: "배치"
                            }
                        }

                        Repeater {
                            model: Layouts.values

                            Rectangle {
                                id: row

                                required property var modelData
                                readonly property bool isCurrent: modelData.current === true

                                width: listCol.width
                                height: 46
                                radius: Theme.radiusS
                                color: isCurrent ? Theme.fade(Theme.primary, 0.16) : (hover.containsMouse ? Theme.hoverWash : "transparent")

                                // 걸린 것은 왼쪽에 띠를 세운다 — 셰이더 목록과 같다.
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    width: 3
                                    radius: 1.5
                                    visible: row.isCurrent
                                    color: Theme.primary
                                }

                                Column {
                                    id: body
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: Theme.spacingM + 4
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        Txt {
                                            id: nameText
                                            text: row.modelData.name
                                            font.family: Theme.monoFamily
                                            font.pixelSize: Theme.fontM
                                            color: row.isCurrent ? Theme.primary : Theme.surfaceText
                                        }

                                        // 제목은 파일 첫 줄의 ` — ` 앞이다. 이름과 같으면 두 번 안 적는다.
                                        Txt {
                                            width: parent.width - nameText.width - Theme.spacingS
                                            anchors.baseline: nameText.baseline
                                            text: row.modelData.title !== row.modelData.name ? row.modelData.title : ""
                                            font.pixelSize: Theme.fontS
                                            color: Theme.surfaceVariantText
                                        }
                                    }

                                    Txt {
                                        visible: row.modelData.inRepo !== true
                                        text: "레포에 없음 — 이 머신에만"
                                        font.pixelSize: Theme.fontS
                                        color: Theme.fade(Theme.surfaceVariantText, 0.6)
                                    }
                                }

                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: row.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    enabled: !Layouts.busy
                                    // 손잡이 띠와 달리 마지막 것을 안 남긴다 — 이 띠는 지금 걸린 것의 자리이기도 하다.
                                    onEntered: root.hoverName = row.modelData.name
                                    onExited: if (root.hoverName === row.modelData.name)
                                        root.hoverName = ""
                                    onClicked: {
                                        if (row.isCurrent)
                                            return;
                                        Layouts.apply(row.modelData.name);
                                        if (!Layouts.session)
                                            root.note(row.modelData.name + " 으로 적어 뒀다 — 하이프랜드에 들어가면 그걸로 뜬다");
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 설명 띠 ───────────────────────────────────────────────
                // 높이 고정: 늘면 위 목록이 밀려 마우스 밑에서 줄이 도망간다. 머리말이 서너 줄이라 여섯 줄.
                Item {
                    id: about
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingS
                    height: Theme.fontS * 6 * 1.4 + Theme.spacingS * 2 + 1

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.divider
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: Theme.spacingS + 1
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: 3

                        Txt {
                            width: parent.width
                            visible: root.described !== null
                            text: {
                                const d = root.described;
                                if (!d)
                                    return "";
                                const t = d.title !== d.name ? d.name + " — " + d.title : d.name;
                                return t + (d.current ? "  · 지금" : "");
                            }
                            font.pixelSize: Theme.fontS
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        Txt {
                            width: parent.width
                            text: root.described ? (root.described.doc || "") : (Layouts.values.length > 0 ? "배치에 마우스를 올리면 여기 설명이 뜬다." : "")
                            font.pixelSize: Theme.fontS
                            color: root.described ? Theme.fade(Theme.surfaceVariantText, 0.9) : Theme.fade(Theme.surfaceVariantText, 0.5)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // 오른쪽: 지금 배치의 값
            Panel {
                width: parent.width - root.railW - Theme.spacingM
                height: parent.height

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    Head {
                        id: knobHead
                        anchors.top: parent.top
                        anchors.left: parent.left
                        text: "값" + (Layouts.current !== "" ? " · " + Layouts.current : "")
                    }

                    Scroller {
                        id: scroll
                        anchors.top: knobHead.bottom
                        anchors.topMargin: Theme.spacingS
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: strip.top
                        anchors.bottomMargin: Theme.spacingXS
                        contentHeight: knobCol.implicitHeight

                        Column {
                            id: knobCol
                            width: scroll.width - scroll.barSpace
                            spacing: Theme.spacingXS

                            // 빈 자리만 두면 뒤판이 죽은 것과 구별이 안 된다.
                            Txt {
                                width: knobCol.width
                                visible: Layouts.groups.length === 0 && Layouts.error === ""
                                text: "이 배치에는 손잡이가 없다. 값 옆에 `-- @0..1` 을 붙이면 여기 뜬다 (apps/rice/layout 머리말)."
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontS
                                color: Theme.surfaceVariantText
                            }

                            Repeater {
                                model: Layouts.groups

                                Column {
                                    required property var modelData

                                    width: knobCol.width
                                    spacing: Theme.spacingXS

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
                                            kind: modelData.type
                                            value: modelData.value
                                            minimum: modelData.min
                                            maximum: modelData.max
                                            step: modelData.step
                                            dirty: modelData.dirty === true
                                            resetTo: modelData.repo === null || modelData.repo === undefined ? ""
                                                : (modelData.type === "bool" ? (modelData.repo === 1 ? "켬" : "끔") : String(modelData.repo))
                                            resetLabel: "레포"
                                            doc: modelData.doc || ""
                                            showDoc: root.showDocs

                                            onHoveredChanged: if (hovered)
                                                root.docHint = docLine
                                            onMoved: v => Layouts.push(modelData.name, v, false)
                                            onCommitted: v => Layouts.push(modelData.name, v, true)
                                            onReverted: Layouts.reset(modelData.name)
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
                        hint: Layouts.groups.length > 0 ? "값에 마우스를 올리면 여기 설명이 뜬다. 키바인드는 위에 적힌 파일에서 고치고 「다시 읽기」." : ""
                    }
                }
            }
        }
    }
}
