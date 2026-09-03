// 고를 수 있는 것 전부. 갈래로 묶이고, 갈래 이름은 셰이더가 든 폴더 이름 그대로다
// (`crt/crt` → 갈래 `crt`). 셰이더를 새 폴더에 넣으면 여기 손 안 대고 갈래가 는다.
//
// 줄을 누르면 **그것 하나만** 걸린다. 지금 체인 뒤에 얹는 것은 오른쪽의 `+` 다.
// 둘을 한 자리에 두는 것은 사용자에게 같은 질문("무엇을 볼까")이기 때문이고,
// 다른 동작이라 단추를 갈라 뒀다.
//
// ── 못 얹는 칸을 빼지 않고 흐리게 둔다 ────────────────────────────────────
// 체인 비용은 곱이라(apps/rice-chain) 지금 걸린 것에 따라 얹을 수 있는 게 달라진다.
// 목록에서 아예 빼면 "왜 아까는 있었는데 지금은 없나"가 되고, 그 이유가 곱셈이라
// 화면만 봐서는 짐작할 길이 없다. 그래서 자리는 두고 이유를 옆에 적는다.

import QtQuick
import qs.Rice
import qs.Ui

Panel {
    id: root

    signal note(string message)

    function headerFor(v) {
        if (v.kind === "off")
            return "끄기";
        if (v.kind === "chain")
            return "저장해 둔 체인";
        if (v.group === "term")
            return "term — 터미널 셰이더를 화면 전체에";
        return v.group;
    }

    // 갈래가 바뀌는 자리에 머리글을 끼운 납작한 목록. 갈래를 따로 들고 있지 않은
    // 것이 요점이다 — rice-crt 가 준 순서를 그대로 쓴다.
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
        anchors.fill: parent
        // 포커스 링이 단추 바깥으로 3px 나간다. 여백이 없으면 첫 줄과 마지막 줄의
        // 링이 잘려서 지금 어디에 있는지가 그 두 줄에서만 안 보인다.
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
                            // 지금 체인이 비어 있으면 `+` 는 줄을 누르는 것과 같은
                            // 일이라 안 낸다.
                            readonly property bool canAdd: v.kind === "stage" && Shaders.chain.length > 0

                            width: col.width
                            height: 46
                            radius: Theme.radiusS
                            color: isCurrent ? Theme.fade(Theme.primary, 0.16) : (hover.containsMouse ? Theme.hoverWash : "transparent")

                            // 걸린 것은 왼쪽에 띠를 세운다. 셰이더를 통과하면
                            // 16% 짜리 배경 색조만으로는 어느 줄이 지금 것인지가
                            // 뭉개진다.
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
}
