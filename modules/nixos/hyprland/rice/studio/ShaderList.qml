// 고를 수 있는 것 전부. 갈래는 폴더 이름 그대로다. 줄을 누르면 그것 하나만, `+` 는 체인 뒤에 얹는다.
// 못 얹는 칸은 빼지 않고 흐리게 두고 이유를 적는다 — 이유가 곱셈이라 빼면 짐작할 길이 없다.
// 설명은 파일 머리말 첫 줄(rice-crt --json 의 blurb)을 아래 띠에 띄운다.

import QtQuick
import qs.Rice
import qs.Ui

Panel {
    id: root

    signal note(string message)

    // 마우스가 올라가 있는 줄. 비어 있으면 띠가 지금 걸린 것을 설명한다.
    property string hoverName: ""
    readonly property var described: Shaders.valueOf(hoverName !== "" ? hoverName : Shaders.current)

    function headerFor(v) {
        if (v.kind === "off")
            return "끄기";
        if (v.kind === "chain")
            return "저장해 둔 체인";
        if (v.group === "term")
            return "term — 터미널 셰이더를 화면 전체에";
        return v.group;
    }

    // 갈래가 바뀌는 자리에 머리글을 끼운 납작한 목록. rice-crt 가 준 순서를 그대로 쓴다.
    readonly property var rows: {
        const out = [];
        let seen = null;
        const vs = Shaders.values;
        for (var i = 0; i < vs.length; i++) {
            const v = vs[i];
            const key = v.kind === "stage" ? v.group : v.kind;
            if (key !== seen) {
                out.push({
                    header: true,
                    label: headerFor(v)
                });
                seen = key;
            }
            out.push({
                header: false,
                v: v
            });
        }
        return out;
    }

    Scroller {
        id: scroll
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: about.top
        // 포커스 링이 3px 나가서, 여백이 없으면 첫 줄과 마지막 줄의 링이 잘린다.
        anchors.margins: Theme.spacingS
        contentHeight: col.implicitHeight

        Column {
            id: col
            width: scroll.width - Theme.spacingS * 2 - scroll.barSpace
            spacing: 1

            Repeater {
                model: root.rows

                Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: modelData.header ? headerRow : valueRow

                    Component {
                        id: headerRow

                        Item {
                            width: col.width
                            height: 30

                            Head {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                text: modelData.label
                            }
                        }
                    }

                    Component {
                        id: valueRow

                        Rectangle {
                            id: row

                            readonly property var v: modelData.v
                            readonly property bool isCurrent: v.name === Shaders.current
                            readonly property bool inChain: Shaders.chain.indexOf(v.name) >= 0
                            // 체인이 비어 있으면 `+` 는 줄을 누르는 것과 같다.
                            readonly property bool canAdd: v.kind === "stage" && Shaders.chain.length > 0

                            width: col.width
                            height: 46
                            radius: Theme.radiusS
                            color: isCurrent ? Theme.fade(Theme.primary, 0.16) : (hover.containsMouse ? Theme.hoverWash : "transparent")

                            // 아래 MouseArea 가 ＋ 자리를 비켜 두므로 호버는 줄 전체에서 따로 잡는다.
                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoverName = row.v.name;
                                    else if (root.hoverName === row.v.name)
                                        root.hoverName = "";
                                }
                            }

                            // 셰이더를 통과하면 16% 배경 색조만으로는 걸린 줄이 뭉개진다.
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
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: plus.left
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Txt {
                                    width: parent.width
                                    text: (row.v.kind === "stage" ? row.v.leaf : row.v.name) + (row.isCurrent ? "   ✓" : (row.inChain ? "   ·" + Shaders.passOf(row.v.name) : ""))
                                    font.pixelSize: Theme.fontM
                                    color: row.isCurrent ? Theme.primary : Theme.surfaceText
                                }

                                Txt {
                                    width: parent.width
                                    font.pixelSize: Theme.fontS
                                    color: Theme.surfaceVariantText
                                    visible: text !== ""
                                    text: {
                                        if (row.v.kind !== "stage")
                                            return "";
                                        var s = row.v.taps + "탭 · " + (row.v.motion ? "흐름" : "정지");
                                        if (row.canAdd && !row.v.addable)
                                            s += "   —  얹으면 한도 넘음";
                                        else if (row.canAdd)
                                            s += "   —  얹으면 " + row.v.thenTaps + "탭";
                                        return s;
                                    }
                                }
                            }

                            Btn {
                                id: plus
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.canAdd
                                width: Theme.hit
                                kind: "ghost"
                                text: "＋"
                                enabled: row.v.addable === true && !Shaders.busy
                                onClicked: Shaders.add(row.v.name)
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                anchors.rightMargin: row.canAdd ? Theme.hit + Theme.spacingS : 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Shaders.busy)
                                        return;
                                    if (row.isCurrent) {
                                        root.note("이미 이것이 걸려 있다");
                                        return;
                                    }
                                    Shaders.apply(row.v.name);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 설명 띠 ───────────────────────────────────────────────────────────
    // 높이 고정(Ui/DocStrip.qml 과 같은 이유). 이름 한 줄 + 글 두 줄.
    Item {
        id: about
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingS
        height: Theme.fontS * 3 * 1.4 + Theme.spacingS * 2 + 4

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
                // off 는 설명할 것이 없다. 그때는 아래 안내만 띄운다.
                visible: root.described !== null && root.described.kind !== "off"
                text: {
                    const d = root.described;
                    if (!d)
                        return "";
                    let s = d.name;
                    if (d.kind === "stage")
                        s += "  · " + d.taps + "탭" + (d.motion ? " · 흐름" : "");
                    return s + (d.current ? "  · 지금" : "");
                }
                font.pixelSize: Theme.fontS
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            Txt {
                width: parent.width
                text: {
                    const d = root.described;
                    if (d && d.kind !== "off")
                        return d.blurb || "";
                    return Shaders.values.length > 0 ? "줄에 마우스를 올리면 여기 설명이 뜬다." : "";
                }
                font.pixelSize: Theme.fontS
                color: root.described && root.described.kind !== "off" ? Theme.fade(Theme.surfaceVariantText, 0.9) : Theme.fade(Theme.surfaceVariantText, 0.5)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
