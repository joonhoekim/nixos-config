// 셰이더 탭 — 화면 셰이더를 고르고, 겹치고, 값을 맞춘다.
//
// 창이 두 축을 들고 있어도 이 파일은 셰이더만 안다. 장식 값은 DecorTab.qml 이
// 따로 알고, 둘은 서로를 안 부른다 — 유일한 접점은 shell.qml 의 탭 인덱스다.
//
// 왼쪽은 "무엇을 볼까"(목록), 오른쪽은 "지금 것을 어떻게"(체인 · 값)다. 체인이
// 값 쪽에 붙어 있는 것은 손잡이 대상 칩이 곧 체인의 칸이기 때문이다 — 몇째 칸을
// 만지는 중인지가 두 자리에서 같이 보여야 한다.

import QtQuick
import qs.Rice
import qs.Ui

Item {
    id: root

    // 토스트는 창이 소유한다. 탭이 여럿이어도 뜨는 자리는 하나여야 해서다.
    signal note(string msg)

    // 목록 쪽은 이름 길이가 정해져 있어서 넓힐 이유가 없다. 창을 키우면 남는
    // 폭은 값 쪽으로 간다.
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
                width: parent.width - actions.width - Theme.spacingM
                spacing: 3

                Txt {
                    width: parent.width
                    text: Shaders.current === "off" ? "off" : Shaders.current
                    font.pixelSize: Theme.fontXL
                    font.weight: Font.Medium
                    color: Shaders.current === "off" ? Theme.surfaceVariantText : Theme.surfaceText
                }

                // 체인 이름은 아래 ChainPanel 이 칸마다 보여 준다. 여기서는 비용과
                // 흐름만 — 같은 것을 두 자리에 적으면 어느 쪽이 최신인지 매번
                // 확인하게 된다.
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: Shaders.error === "" && Shaders.chain.length > 0

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Shaders.chainTaps + "탭 / " + Shaders.maxTaps
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontS
                        color: Theme.surfaceVariantText
                    }

                    // 남은 예산. 얹을 수 있느냐 없느냐가 곱셈이라 눈으로는 안
                    // 보이는데, 이 막대가 차 있으면 목록의 "얹으면 한도 넘음"이
                    // 왜 나오는지가 설명 없이 읽힌다.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        height: 4
                        radius: 2
                        color: Theme.fade(Theme.surfaceText, 0.16)

                        Rectangle {
                            readonly property real used: Math.min(1, Shaders.chainTaps / Math.max(1, Shaders.maxTaps))

                            width: parent.width * used
                            height: parent.height
                            radius: parent.radius
                            color: used > 0.75 ? Theme.error : Theme.primary

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.durBase
                                }
                            }
                        }
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Shaders.motion ? "흐름 · VFR 끔 (놀 때도 계속 그린다)" : "정지 · 놀 때는 안 그린다"
                        font.pixelSize: Theme.fontS
                        color: Theme.surfaceVariantText
                    }
                }

                Txt {
                    width: parent.width
                    visible: Shaders.error !== "" || Shaders.chain.length === 0
                    font.pixelSize: Theme.fontS
                    color: Shaders.error !== "" ? Theme.error : Theme.surfaceVariantText
                    text: Shaders.error !== "" ? Shaders.error : "셰이더 없음 — 아래에서 하나 고르면 걸린다"
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                Btn {
                    text: "다시 읽기"
                    enabled: Shaders.chain.length > 0 && !Shaders.busy
                    onClicked: Shaders.reload()
                }

                Btn {
                    text: "이름 붙여 저장"
                    enabled: Shaders.chain.length > 0 && !Shaders.busy
                    onClicked: {
                        saveRow.open = !saveRow.open;
                        if (saveRow.open)
                            saveName.forceActiveFocus();
                    }
                }

                Btn {
                    text: "off"
                    danger: true
                    enabled: Shaders.current !== "off" && !Shaders.busy
                    onClicked: Shaders.off()
                }
            }
        }

        // ── 이름 붙여 저장 ────────────────────────────────────────────────
        // 저장은 이름이 있어야 하는 유일한 동작이다. 늘 띄워 두면 자리를
        // 차지하므로 누를 때만 펼친다.
        Panel {
            id: saveRow

            property bool open: false

            function commit() {
                if (saveName.text.length === 0)
                    return;
                Shaders.save(saveName.text);
                root.note("chain/" + saveName.text + " 으로 저장했다 — 레포에 넣으려면 apps/rice-save");
                saveName.text = "";
                open = false;
            }

            width: parent.width
            height: open ? 52 : 0
            visible: height > 0
            clip: true
            radius: Theme.radiusS
            border.width: open ? 1 : 0

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durBase
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                Rectangle {
                    width: parent.width - 100 - Theme.spacingS
                    height: parent.height
                    radius: Theme.radiusS
                    color: Theme.surfaceRaised
                    border.width: saveName.activeFocus ? 2 : 1
                    border.color: saveName.activeFocus ? Theme.primary : Theme.line

                    TextInput {
                        id: saveName
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM
                        selectByMouse: true
                        selectionColor: Theme.fade(Theme.primary, 0.35)
                        selectedTextColor: Theme.surfaceText
                        // `/` 와 앞점은 rice-crt 가 거절한다. 눌러 보고
                        // 거절당하는 것보다 못 치게 하는 편이 낫다.
                        validator: RegularExpressionValidator {
                            regularExpression: /[A-Za-z0-9][A-Za-z0-9._-]*/
                        }
                        onAccepted: saveRow.commit()
                        Keys.onEscapePressed: {
                            saveName.text = "";
                            saveRow.open = false;
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: saveName.text.length === 0
                            text: "체인 이름 (예: bad-signal)"
                            color: Theme.fade(Theme.surfaceVariantText, 0.7)
                            font.pixelSize: Theme.fontM
                        }
                    }
                }

                Btn {
                    width: 100
                    height: parent.height
                    text: "저장"
                    kind: "filled"
                    enabled: saveName.text.length > 0 && !Shaders.busy
                    onClicked: saveRow.commit()
                }
            }
        }

        // ── 본문 ──────────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: parent.height - y
            spacing: Theme.spacingM

            ShaderList {
                width: root.railW
                height: parent.height
                onNote: msg => root.note(msg)
            }

            Column {
                width: parent.width - root.railW - Theme.spacingM
                height: parent.height
                spacing: Theme.spacingM

                ChainPanel {
                    width: parent.width
                }

                KnobPanel {
                    width: parent.width
                    height: parent.height - y
                }
            }
        }
    }
}
