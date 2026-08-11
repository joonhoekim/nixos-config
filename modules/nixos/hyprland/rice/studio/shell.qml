//@ pragma UseQApplication
//@ pragma AppId rice-studio

// 라이싱 스튜디오 — 화면 셰이더를 고르고, 겹치고, 값을 맞추는 창.
//
// 여는 법:  apps/rice-studio   또는 DankBar 의 팔레트 조각
//
// ── 왜 DMS 밖인가 ─────────────────────────────────────────────────────────
// 원래 이 일은 DMS 플러그인 둘이 나눠 하고 있었다 — 런처에서 고르고, 설정 모달의
// 슬라이더로 값을 맞췄다. 축이 하나 늘어난 게 아니라 **축의 성질이 달라진** 것이
// 갈라선 이유다. 다른 라이싱 축은 "값 하나 고르기"인데 셰이더는 여러 장을 순서대로
// 쌓고, 그 조합마다 비용이 곱으로 늘고, 칸마다 손잡이가 따로 있다. 그걸 런처의
// 한 줄짜리 항목 계약에 우겨넣다 보니 플러그인이 갈래 이름·탭 곱셈·체인 동사를
// 전부 알게 됐고, "이 파일은 축이 뭔지 모른다"고 적어 둔 자기 머리말과 어긋났다.
//
// 그래서 셰이더만 이 창으로 나왔다. DMS 에 남은 것은 여는 단추 하나와, 화면이
// 망가졌을 때 쓰는 탈출구(off · 다음 것)다 — 셰이더가 화면을 못 알아보게 만들면
// **이 창도 같은 유리 뒤에 있어서** 여기서 끄는 길만 두면 안 된다.
//
// ── 값은 여기 없다 ────────────────────────────────────────────────────────
// 목록도, 탭 수도, 무엇을 더할 수 있는지도 Rice/ 아래 싱글턴들이 셸에게 물어서
// 가져온다. 특히 곱 한도는 apps/rice-chain 하나만 안다 — 여기서 다시 세면 규칙이
// 두 벌이 되고, 한쪽만 고친 날 목록이 거짓말을 한다.
//
// ── 조절하는 화면이 곧 표본이다 ───────────────────────────────────────────
// 화면 셰이더는 창을 안 가린다. 이 창도 그 유리 뒤에 그려지므로 글씨 대비와 블룸을
// 바로 그 위에서 본다. DMS 설정 모달에 붙여 뒀을 때의 부수 효과였는데, 별도 창이
// 돼서도 그대로다.

import QtQuick
import Quickshell
import qs.Rice
import qs.Ui

ShellRoot {
    id: rootScope

    FloatingWindow {
        id: win

        title: "라이싱 스튜디오"
        implicitWidth: 940
        implicitHeight: 660
        minimumSize: Qt.size(720, 480)
        color: Theme.surface

        // ── 토스트 ────────────────────────────────────────────────────────
        // 실패는 조용히 지나가면 안 된다. 특히 체인 한도 초과는 "눌렀는데 아무 일도
        // 안 일어났다"로 보이기 딱 좋다 — 이유가 곱셈이라 눈으로는 안 보인다.
        property string toast: ""
        property bool toastBad: false

        function say(msg, bad) {
            toast = msg;
            toastBad = bad === true;
            toastTimer.restart();
        }

        Timer {
            id: toastTimer
            interval: 4200
            onTriggered: win.toast = ""
        }

        Connections {
            target: Shaders
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        Connections {
            target: Knobs
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        // 셰이더를 갈아 끼우면 손잡이 대상의 순서(몇째 칸인지)가 바뀐다.
        Connections {
            target: Shaders
            function onChanged() {
                Knobs.loadTargets();
            }
        }

        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // ── 머리 ──────────────────────────────────────────────────
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

                // ── 이름 붙여 저장 ────────────────────────────────────────
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
                        win.say("chain/" + saveName.text + " 으로 저장했다 — 레포에 넣으려면 apps/rice-save");
                        saveName.text = "";
                        open = false;
                    }
                }

                // ── 본문 ──────────────────────────────────────────────────
                Row {
                    width: parent.width
                    height: parent.height - y
                    spacing: Theme.spacingM

                    ShaderList {
                        width: 320
                        height: parent.height
                        onNote: msg => win.say(msg)
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

            // 토스트는 창 위에 겹친다. 자리를 차지하면 뜰 때마다 아래 내용이 밀린다.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                visible: win.toast !== ""
                width: Math.min(parent.width - Theme.spacingL * 2, toastText.implicitWidth + Theme.spacingL * 2)
                height: toastText.implicitHeight + Theme.spacingM * 2
                radius: Theme.radiusS
                color: win.toastBad ? Theme.fade(Theme.error, 0.92) : Theme.surfaceContainerHighest
                border.width: 1
                border.color: Theme.fade(Theme.outline, 0.2)

                Txt {
                    id: toastText
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    text: win.toast
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    font.pixelSize: Theme.fontS
                    color: win.toastBad ? Theme.surface : Theme.onSurface
                }
            }
        }
    }
}
