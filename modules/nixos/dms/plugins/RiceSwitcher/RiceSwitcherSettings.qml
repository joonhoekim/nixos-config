// RiceSwitcher 설정 — 라이싱 값을 슬라이더로 만지는 자리.
//
// 여는 법: 런처(Mod+Shift+R)에서 "값 조절…", 또는
//   dms ipc call settings toggleWith plugins
//
// ── 왜 여기인가 ───────────────────────────────────────────────────────────
// DMS 의 플러그인 팝아웃은 DankBar 에 위젯이 올라가 있어야 열린다
// (DMSShellIPC 의 widget 계열이 BarWidgetService 를 거친다). 바에 칸을 하나 내주는
// 대신 설정 모달의 플러그인 탭으로 딥링크했다. 부수 효과가 오히려 좋은데, 이
// 모달 자체가 화면 셰이더를 통과해 그려지므로 **조절하는 화면이 곧 표본**이다 —
// 글씨 대비와 블룸을 바로 그 위에서 본다.
//
// ── 값은 여기 없다 ────────────────────────────────────────────────────────
// 무엇이 손잡이인지, 범위가 얼마인지, 지금 값이 뭔지 전부 apps/rice-knobs 가
// 준다. 그건 다시 셰이더 파일의 `// @0..1` 표시를 읽는다. 그래서 셰이더에 값을
// 하나 더 만들고 표시만 붙이면 이 파일을 안 고쳐도 슬라이더가 하나 늘어난다.
//
// ── 로컬만 고친다 ─────────────────────────────────────────────────────────
// 쓰는 곳은 언제나 ~/.config 쪽이다. 레포와 다른 값에는 되돌리기 단추가 뜨고,
// 레포에 넣는 것은 값이 자리 잡은 뒤 apps/rice-save 로 한 번에 한다.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: column.implicitHeight + Theme.spacingL * 2
    height: implicitHeight

    readonly property string knobs: (Quickshell.env("HOME") || "") + "/nixos-config/apps/rice-knobs"

    property var targets: []
    property string target: ""
    property var groups: []
    property string error: ""

    Component.onCompleted: loadTargets()

    // ── 읽기 ──────────────────────────────────────────────────────────────
    function loadTargets() {
        targetProc.running = true;
    }

    function loadKnobs() {
        if (!target)
            return;
        knobProc.command = [root.knobs, "get", target];
        knobProc.running = true;
    }

    Process {
        id: targetProc
        command: [root.knobs]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.targets = data.targets || [];
                    root.error = "";
                    // 지금 화면에 걸려 있는 것으로 시작한다. 조절하려는 것이
                    // 보이고 있는 것일 확률이 압도적으로 높다.
                    let pick = root.targets.find(t => t.applied);
                    root.target = (pick || root.targets[0] || {}).id || "";
                    root.loadKnobs();
                } catch (e) {
                    root.error = "rice-knobs 를 읽지 못했다: " + e;
                }
            }
        }
    }

    Process {
        id: knobProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.groups = (JSON.parse(text).groups) || [];
                    root.error = "";
                } catch (e) {
                    root.groups = [];
                    root.error = "손잡이를 읽지 못했다: " + e;
                }
            }
        }
    }

    // ── 쓰기 ──────────────────────────────────────────────────────────────
    // 셰이더를 다시 거는 데 90ms 쯤 걸린다(파일 쓰기 + hyprctl eval 세 번). 슬라이더가
    // 움직일 때마다 그대로 부르면 끄는 손보다 뒤처지므로, 마지막 값 하나만 남기고
    // 모아서 보낸다. 손을 떼면 타이머를 기다리지 않고 바로 한 번 더 보낸다.
    property string pendingKey: ""
    property real pendingValue: 0

    function push(name, value, immediate) {
        pendingKey = name;
        pendingValue = value;
        if (immediate) {
            debounce.stop();
            flush();
        } else if (!debounce.running) {
            debounce.restart();
        }
    }

    function flush() {
        if (!pendingKey || applyProc.running)
            return;
        applyProc.command = [root.knobs, "set", root.target, pendingKey, String(pendingValue)];
        pendingKey = "";
        applyProc.running = true;
    }

    Timer {
        id: debounce
        interval: 110
        onTriggered: root.flush()
    }

    Process {
        id: applyProc
        running: false
        // 값이 밀려 있으면 이어서 보낸다. 적용이 도는 동안 슬라이더가 계속
        // 움직였을 때 마지막 값이 빠지는 것을 막는다.
        onExited: {
            if (root.pendingKey)
                root.flush();
            else
                root.loadKnobs();   // dirty 표시를 갱신한다
        }
    }

    Process {
        id: resetProc
        running: false
        onExited: root.loadKnobs()
    }

    function resetKnob(name) {
        resetProc.command = [root.knobs, "reset", root.target, name];
        resetProc.running = true;
    }

    // ── 화면 ──────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingL

        StyledText {
            text: "라이싱 값"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "값은 ~/.config 쪽에만 쓰인다. 화면에 걸려 있는 셰이더면 즉시 반영된다. "
                + "레포에 넣으려면 체크아웃에서 apps/rice-save."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            visible: root.error !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.error
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
        }

        DankButtonGroup {
            id: picker
            model: root.targets.map(t => t.id)
            currentIndex: Math.max(0, root.targets.findIndex(t => t.id === root.target))
            size: "small"
            onSelectionChanged: (index, selected) => {
                if (!selected)
                    return;
                const t = root.targets[index];
                if (t && t.id !== root.target) {
                    root.target = t.id;
                    root.groups = [];
                    root.loadKnobs();
                }
            }
        }

        Repeater {
            model: root.groups

            Column {
                required property var modelData
                width: column.width
                spacing: Theme.spacingS

                StyledText {
                    text: modelData.label || "값"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.primary
                    topPadding: Theme.spacingS
                }

                Repeater {
                    model: modelData.knobs

                    Column {
                        id: knobRow
                        required property var modelData
                        width: parent.width
                        spacing: 2

                        // 슬라이더는 정수만 받는다. 눈금 개수를 최대값으로 두고
                        // 그 인덱스를 실수로 되돌린다.
                        //
                        // 이 산수를 함수로 빼지 않는 건 Qt 사정이다. Repeater 델리게이트
                        // 안에 선언한 함수를 자식의 바인딩에서 부르면 만들고 지우는
                        // 동안 "attempted to evaluate a function in an invalid context"
                        // 경고가 쏟아진다. 선언적 프로퍼티는 그 문제가 없다.
                        readonly property int steps: Math.max(1, Math.round((modelData.max - modelData.min) / modelData.step))
                        readonly property int index0: Math.round((modelData.value - modelData.min) / modelData.step)
                        readonly property real live: modelData.min + slider.value * modelData.step

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: knobRow.modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.monoFontFamily
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: knobRow.live.toFixed(3).replace(/0+$/, "").replace(/\.$/, ".0")
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.monoFontFamily
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 레포와 다를 때만 뜬다. 원래 값이 무엇이었는지가
                            // 되돌리기 단추보다 먼저 알고 싶은 것이라 같이 적는다.
                            StyledText {
                                visible: knobRow.modelData.dirty === true
                                text: "· 레포 " + knobRow.modelData.repo
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankActionButton {
                                visible: knobRow.modelData.dirty === true
                                iconName: "undo"
                                buttonSize: 22
                                iconSize: 14
                                tooltipText: "레포 값으로"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: root.resetKnob(knobRow.modelData.name)
                            }
                        }

                        DankSlider {
                            id: slider
                            width: parent.width
                            minimum: 0
                            maximum: knobRow.steps
                            step: 1
                            showValue: false
                            // 값 표시는 위 Row 가 실수로 한다. 여기 숫자는 눈금
                            // 인덱스라 사람에게 보여줄 것이 아니다.
                            value: knobRow.index0

                            onSliderValueChanged: newValue => {
                                if (newValue !== knobRow.index0)
                                    root.push(knobRow.modelData.name, knobRow.modelData.min + newValue * knobRow.modelData.step, false);
                            }
                            onSliderDragFinished: newValue => {
                                root.push(knobRow.modelData.name, knobRow.modelData.min + newValue * knobRow.modelData.step, true);
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: (knobRow.modelData.doc || "") !== ""
                            text: knobRow.modelData.doc
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
