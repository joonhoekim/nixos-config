//@ pragma UseQApplication
//@ pragma AppId rice-studio

// 라이싱 스튜디오 — 셰이더·배치·장식 탭. 여는 법: apps/rice/studio 또는 DankBar 조각.
// 왜 DMS 밖인가, 탭을 나눈 기준: docs/rice-studio.md
// 목록·탭 수·곱 한도는 Rice/ 싱글턴이 셸에 물어 온다 — 여기서 다시 세면 규칙이 두 벌이 된다.

import QtQuick
import Quickshell
import qs.Rice
import qs.Ui

ShellRoot {
    id: rootScope

    // 닫아도 ShellRoot 는 계속 돌아, 다음 apps/rice/studio 의 `-n` 이 "이미 돈다"며 조용히 나간다.
    // quickshell 0.3.0 에는 Quickshell.quit() 이 없어 Qt.quit() 을 쓴다.
    Connections {
        target: Quickshell
        function onLastWindowClosed() {
            Qt.quit();
        }
    }

    FloatingWindow {
        id: win

        title: "라이싱 스튜디오"
        implicitWidth: 1080
        implicitHeight: 740
        // 이보다 좁으면 KnobRow 의 슬라이더가 백 픽셀 아래로 눌려 맞출 수 없다.
        minimumSize: Qt.size(880, 560)
        color: Theme.surface

        // 0 = 셰이더, 1 = 배치, 2 = 장식
        property int tab: 0

        // ── 토스트 ────────────────────────────────────────────────────────
        // 체인 한도 초과 같은 실패는 "눌렀는데 아무 일도 없음"으로 보이므로 반드시 띄운다.
        property string toast: ""
        property bool toastBad: false

        function say(msg, bad) {
            toast = msg;
            toastBad = bad === true;
            // 긴 거절 이유가 다 읽히기 전에 사라지지 않게 길이에 비례한다.
            toastTimer.interval = Math.max(3200, Math.min(9000, 1600 + msg.length * 90));
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

        Connections {
            target: Layouts
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        // 장식 거절은 다른 탭에서도 일어나서 토스트가 창 것이다.
        Connections {
            target: Decor
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

        // Esc 나 맨 숫자를 안 쓴다 — 저장 이름 입력 중에 삼켜지거나 탭 전환으로 샌다.
        Shortcut {
            sequences: ["Ctrl+1"]
            onActivated: win.tab = 0
        }

        Shortcut {
            sequences: ["Ctrl+2"]
            onActivated: win.tab = 1
        }

        Shortcut {
            sequences: ["Ctrl+3"]
            onActivated: win.tab = 2
        }

        Shortcut {
            sequences: ["Ctrl+W"]
            onActivated: Qt.quit()
        }

        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // ── 탭 ────────────────────────────────────────────────────
                // 칩 모양은 KnobPanel 의 대상 고르기와 같게 둔다.
                Panel {
                    width: parent.width
                    height: 44
                    radius: Theme.radiusS

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Repeater {
                            model: 3

                            Chip {
                                required property int index

                                // 다른 탭을 보고 있어도 저쪽 상태가 보이게 한다.
                                text: {
                                    if (index === 0)
                                        return "셰이더";
                                    if (index === 1)
                                        return "배치" + (Layouts.current !== "" ? " · " + Layouts.current : "");
                                    return "장식" + (Decor.dirtyCount > 0 ? " · " + Decor.dirtyCount : "");
                                }
                                picked: win.tab === index
                                onClicked: win.tab = index
                            }
                        }
                    }

                    // 단축키는 Shortcut 선언에만 있어 메뉴 없는 창에서는 여기가 유일한 안내다.
                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ctrl+1·2·3 탭  ·  Ctrl+W 닫기"
                        font.pixelSize: Theme.fontS
                        color: Theme.fade(Theme.surfaceVariantText, 0.7)
                    }
                }

                // ── 본문 ──────────────────────────────────────────────────
                // 탭을 Column 에 나란히 두면 둘 다 남은 높이를 요구해 y 가 엉킨다. 겹쳐 두고 보이기만 정한다.
                Item {
                    width: parent.width
                    height: parent.height - y

                    ShaderTab {
                        anchors.fill: parent
                        visible: win.tab === 0
                        onNote: msg => win.say(msg)
                    }

                    LayoutTab {
                        anchors.fill: parent
                        visible: win.tab === 1
                        onNote: msg => win.say(msg)
                    }

                    DecorTab {
                        anchors.fill: parent
                        visible: win.tab === 2
                    }
                }
            }

            // 토스트는 창 위에 겹친다. 자리를 차지하면 뜰 때마다 아래 내용이 밀린다.
            Rectangle {
                id: toast

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                visible: win.toast !== ""
                width: Math.min(parent.width - Theme.spacingL * 2, toastText.implicitWidth + Theme.spacingL * 2)
                height: toastText.implicitHeight + Theme.spacingM * 2
                radius: Theme.radiusS
                color: win.toastBad ? Theme.fade(Theme.error, 0.92) : Theme.surfaceRaised
                border.width: 1
                border.color: Theme.line

                Txt {
                    id: toastText
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    text: win.toast
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    font.pixelSize: Theme.fontS
                    color: win.toastBad ? Theme.surface : Theme.surfaceText
                }

                // 손잡이 목록의 아래쪽을 가리므로, 다 읽었으면 눌러서 치울 수 있다.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        toastTimer.stop();
                        win.toast = "";
                    }
                }
            }
        }
    }
}
