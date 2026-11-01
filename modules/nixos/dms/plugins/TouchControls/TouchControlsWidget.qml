// DankBar 조각과 팝아웃 — 화면을 접은 자세에서도 화면 키보드·회전 잠금·태블릿 모드를 켜고 끈다.
// 상태는 `touch-state` JSON 이 준다. 팝아웃이 열릴 때와 누른 직후에만 읽는다(낙관적으로 뒤집지 않는다).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "touch-controls"

    property string oskState: "off"
    property string rotateState: "off"
    property string tabletState: "off"

    function refresh() {
        reader.running = true;
    }

    Process {
        id: reader
        command: ["touch-state"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.oskState = s.osk || "off";
                    root.rotateState = s.rotate || "off";
                    root.tabletState = s.tablet || "off";
                } catch (e) {
                    // touch-state 가 없는 머신. 셋 다 off 면 눌러도 아무 일 없지만 조용히 깨지는 것보다 낫다.
                    console.warn("TouchControls: touch-state 를 읽지 못했다 —", e);
                }
            }
        }
    }

    // execDetached 라 끝을 모른다. osk 는 다음 프레임에야 레이어가 생겨 바로 읽으면 직전 값이 나온다.
    Timer {
        id: settle
        interval: 250
        onTriggered: root.refresh()
    }

    function run(args) {
        Quickshell.execDetached(args);
        settle.restart();
    }

    // 태블릿 자세일 때만 모양을 바꿔 팝아웃 없이도 자세가 보인다.
    readonly property string pillIcon: tabletState === "on" ? "tablet_android" : "touch_app"

    horizontalBarPill: Component {
        DankIcon {
            name: root.pillIcon
            size: root.iconSize
            color: root.tabletState === "on" ? Theme.primary : Theme.surfaceText
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: root.pillIcon
            size: root.iconSize
            color: root.tabletState === "on" ? Theme.primary : Theme.surfaceText
        }
    }

    popoutWidth: 340
    popoutHeight: 300

    popoutContent: Component {
        PopoutComponent {
            headerText: "터치"
            detailsText: "화면을 접으면 세 가지가 같이 움직인다"
            showCloseButton: true

            // 자판은 Mod+B·hide 키·태블릿 훅으로도 움직여서 지난번 값을 믿을 수 없다.
            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingS

                DankToggle {
                    width: parent.width
                    text: "화면 키보드"
                    description: "Mod+B 와 같은 것. 한/영은 자판의 Ctrl+space"
                    checked: root.oskState === "on"
                    onClicked: root.run(["osk", "toggle"])
                }

                DankToggle {
                    width: parent.width
                    text: "화면 회전"
                    description: "가속도계를 따라 화면과 터치를 같이 돌린다"
                    checked: root.rotateState === "on"
                    onClicked: root.run(["autorotate", "toggle"])
                }

                DankToggle {
                    width: parent.width
                    text: "태블릿 모드"
                    description: "키보드·터치패드를 끄고 회전과 자판을 켠다"
                    checked: root.tabletState === "on"
                    // 토글 신호가 없어서 지금 상태를 보고 방향을 정한다.
                    onClicked: root.run(["tablet-mode",
                        root.tabletState === "on" ? "leave" : "enter"])
                }
            }
        }
    }
}
