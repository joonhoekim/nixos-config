// 셰이더 탭 — 화면 셰이더를 고르고, 겹치고, 값을 맞춘다. 원래 shell.qml 의
// 본문이었고, "장식" 탭이 생기면서 그대로 옮겨왔다.
//
// 창이 두 축을 들고 있어도 이 파일은 셰이더만 안다. 장식 값은 DecorTab.qml 이
// 따로 알고, 둘은 서로를 안 부른다 — 유일한 접점은 shell.qml 의 탭 인덱스다.

import QtQuick
import qs.Rice
import qs.Ui

Item {
    id: root

    // 토스트는 창이 소유한다. 탭이 여럿이어도 뜨는 자리는 하나여야 해서다.
    signal note(string msg)

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        // ── 머리 ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 52

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - actions.width - Theme.spacingM
                spacing: 2

                Txt {
                    width: parent.width
                    text: Shaders.current === "off" ? "off" : Shaders.current
                    font.pixelSize: Theme.fontXL
                    font.weight: Font.Medium
                    color: Shaders.current === "off" ? Theme.onSurfaceVariant : Theme.onSurface
                }

                Txt {
                    width: parent.width
                    font.pixelSize: Theme.fontS
                    color: Theme.onSurfaceVariant
                    text: {
                        if (Shaders.error !== "")
                            return Shaders.error;
                        if (Shaders.chain.length === 0)
                            return "셰이더 없음 — 아래에서 하나 고르면 걸린다";
                        return Shaders.chain.join(" → ") + "   " + Shaders.chainTaps + "탭 / " + Shaders.maxTaps + "   " + (Shaders.motion ? "흐름 · VFR 끔 (놀 때도 계속 그린다)" : "정지 · 놀 때는 안 그린다");
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
                    onClicked: saveRow.open = !saveRow.open
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
        Rectangle {
            id: saveRow
            property bool open: false

            width: parent.width
            height: open ? 44 : 0
            visible: height > 0
            clip: true
            radius: Theme.radiusS
            color: Theme.surfaceContainer

            Behavior on height {
                NumberAnimation {
                    duration: 120
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
                    color: Theme.surfaceContainerHighest

                    TextInput {
                        id: saveName
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontM
                        selectByMouse: true
                        // `/` 와 앞점은 rice-crt 가 거절한다. 눌러 보고
                        // 거절당하는 것보다 못 치게 하는 편이 낫다.
                        validator: RegularExpressionValidator {
                            regularExpression: /[A-Za-z0-9][A-Za-z0-9._-]*/
                        }
                        onAccepted: if (text.length > 0)
                            saveRow.commit()

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: saveName.text.length === 0
                            text: "체인 이름 (예: bad-signal)"
                            color: Theme.fade(Theme.onSurfaceVariant, 0.7)
                            font.pixelSize: Theme.fontM
                        }
                    }
                }

                Btn {
                    width: 100
                    text: "저장"
                    kind: "filled"
                    enabled: saveName.text.length > 0 && !Shaders.busy
                    onClicked: saveRow.commit()
                }
            }

            function commit() {
                Shaders.save(saveName.text);
                root.note("chain/" + saveName.text + " 으로 저장했다 — 레포에 넣으려면 apps/rice-save");
                saveName.text = "";
                open = false;
            }
        }

        // ── 본문 ──────────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: parent.height - y
            spacing: Theme.spacingM

            ShaderList {
                width: 320
                height: parent.height
                onNote: msg => root.note(msg)
            }

            Column {
                width: parent.width - 320 - Theme.spacingM
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
