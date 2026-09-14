// DankBar 조각 하나와 그 팝아웃. 터치 자세를 손가락만으로 켜고 끈다.
//
// ── 왜 있는가 ─────────────────────────────────────────────────────────────
// 화면 키보드를 여는 길이 Mod+B 하나뿐이었다. 키보드 없이 쓰려고 만든 물건을
// 키보드로만 열 수 있다는 뜻이라, 정작 필요한 자세(화면을 접은 상태)에서는
// 못 연다. 여기가 그 손잡이다.
//
// ── 상태는 이 파일이 모른다 ───────────────────────────────────────────────
// `touch-state` 가 JSON 한 덩어리로 준다. sysfs 를 어디서 읽는지, 자판이 보이는
// 판정을 뭘로 하는지(하이프랜드 레이어다), 회전 데몬의 상태 파일이 어디 있는지 —
// 전부 셸 쪽에 있고 여기는 키 세 개만 안다. RiceSwitcherLauncher 가 apps/rice-menu
// 에게 목록을 통째로 받는 것과 같은 방향이고, 이유도 같다: 판정이 늘거나 바뀌어도
// 이 파일은 안 고친다.
//
// ── 폴링하지 않는다 ───────────────────────────────────────────────────────
// 상태는 **팝아웃이 열릴 때** 한 번 읽는다. 바에 상시로 떠 있는 조각이 1 초마다
// hyprctl 과 sysfs 를 훑으면 값에 비해 비싸고, 이 셋은 사람이 누를 때 말고는 잘
// 안 바뀐다. 누른 직후에도 다시 읽는데, 그건 토글이 실제로 먹었는지를 화면에
// 반영하기 위해서다 — 낙관적으로 뒤집어 두면 실패했을 때 UI 만 거짓말한다.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "touch-controls"

    // touch-state 가 주는 세 값. 못 읽으면 전부 "off" 로 둔다.
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
                    // touch-state 가 없는 머신(이 플러그인이 다른 호스트에 깔린
                    // 경우)에 온다. 셋 다 off 로 두면 조각은 뜨지만 누른 것이
                    // 아무 일도 안 하는 상태가 되고, 그게 조용히 깨지는 것보다는
                    // 낫다.
                    console.warn("TouchControls: touch-state 를 읽지 못했다 —", e);
                }
            }
        }
    }

    // 토글 하나를 누르면 명령을 던지고 상태를 다시 읽는다. execDetached 라
    // 끝나는 때를 모르므로 조금 기다렸다 읽는다 — osk 는 신호를 받고 다음
    // 프레임에야 레이어가 생겨서, 바로 읽으면 직전 값이 그대로 나온다.
    Timer {
        id: settle
        interval: 250
        onTriggered: root.refresh()
    }

    function run(args) {
        Quickshell.execDetached(args);
        settle.restart();
    }

    // 바에서는 아이콘 하나다. 태블릿 자세일 때만 모양을 바꿔서, 지금 어느
    // 자세인지가 팝아웃을 안 열어도 보이게 한다.
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

            // 열릴 때마다 읽는다. 자판은 Mod+B 로도, 자판 안의 hide 키로도,
            // 태블릿 모드 훅으로도 움직여서 지난번 값은 믿을 수 없다.
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
                    // 토글 신호가 없는 쪽이라 지금 상태를 보고 방향을 정한다.
                    onClicked: root.run(["tablet-mode",
                        root.tabletState === "on" ? "leave" : "enter"])
                }
            }
        }
    }
}
