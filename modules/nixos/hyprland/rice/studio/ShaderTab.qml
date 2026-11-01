// 셰이더 탭 — 화면 셰이더를 고르고, 겹치고, 값을 맞춘다. 장식 탭과는 서로 안 부른다.
// 체인이 값 쪽에 붙은 것은 손잡이 대상 칩이 곧 체인의 칸이기 때문이다.

import QtQuick
import qs.Rice
import qs.Ui

Item {
    id: root

    // 토스트는 창이 소유한다. 탭이 여럿이어도 뜨는 자리는 하나여야 해서다.
    signal note(string msg)

    // 창을 키우면 남는 폭은 값 쪽으로 간다.
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

                // 체인 이름은 ChainPanel 이 보여 준다. 여기는 비용과 흐름만.
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

                    // 얹을 수 있느냐가 곱셈이라 눈에 안 보여서, 남은 예산을 막대로 보인다.
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
                    text: {
                        if (Shaders.error !== "")
                            return Shaders.error;
                        // 세션이 없으면 컴포지터에 물을 데가 없어 체인이 늘 비어 있다.
                        if (!Shaders.session)
                            return "하이프랜드 세션이 아니다 — 값은 고칠 수 있지만 화면에 거는 것은 안 된다";
                        return "셰이더 없음 — 아래에서 하나 고르면 걸린다";
                    }
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
        Panel {
            id: saveRow

            property bool open: false

            // rice-crt 는 같은 이름을 묻지 않고 덮어쓰므로, 치는 동안 단추가 먼저 알려야 한다.
            readonly property bool exists: saveName.text.length > 0 && Shaders.valueOf("chain/" + saveName.text) !== null

            function commit() {
                if (saveName.text.length === 0)
                    return;
                const was = exists;
                Shaders.save(saveName.text);
                root.note("chain/" + saveName.text + (was ? " 를 덮어썼다" : " 으로 저장했다") + " — 레포에 넣으려면 apps/rice/save");
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
                        // `/` 와 앞점은 rice-crt 가 거절하므로 아예 못 치게 한다.
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
                    text: saveRow.exists ? "덮어쓰기" : "저장"
                    kind: "filled"
                    danger: saveRow.exists
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
