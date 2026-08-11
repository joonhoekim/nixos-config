pragma Singleton

// 셰이더 값(손잡이)을 읽고 쓴다. 뒤판은 apps/rice-knobs 이고, 그건 다시 셰이더
// 파일 안의 `// @0..1` 표시를 읽는다 — 무엇이 손잡이인지 여기 목록은 없다.
// 셰이더에 값을 하나 더 만들고 표시만 붙이면 이 파일을 안 고쳐도 슬라이더가 는다.
//
// ── 쓰는 곳은 언제나 $HOME ────────────────────────────────────────────────
// 레포는 비교 대상으로만 읽힌다("레포와 다름" 표시와 되돌리기). 레포에 넣는 것은
// 값이 자리 잡은 뒤 apps/rice-save 로 한 번에, 사람이 판단해서.
//
// ── 디바운스 ──────────────────────────────────────────────────────────────
// 값을 하나 쓰면 파일을 고치고 셰이더를 다시 건다(90ms 쯤). 슬라이더가 움직일
// 때마다 그대로 부르면 끄는 손보다 뒤처지므로, 마지막 값 하나만 남기고 모아서
// 보낸다. 손을 떼면 타이머를 안 기다리고 바로 한 번 더 보낸다.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS") || ((Quickshell.env("HOME") || "") + "/nixos-config/apps")
    readonly property string bin: apps + "/rice-knobs"

    property var targets: []
    property string target: ""
    property var groups: []
    property string error: ""

    signal failed(string label, string message)

    Component.onCompleted: loadTargets()

    function loadTargets() {
        if (targetProc.running)
            return;
        targetProc.running = true;
    }

    function selectTarget(id) {
        if (id === target)
            return;
        target = id;
        groups = [];
        loadKnobs();
    }

    function loadKnobs() {
        if (!target || knobProc.running)
            return;
        knobProc.command = [root.bin, "get", target];
        knobProc.running = true;
    }

    Process {
        id: targetProc
        command: [root.bin]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    // 걸려 있는 칸을 앞으로 당긴다. 대상이 열 몇 개인데 지금 만질
                    // 것은 거의 언제나 화면에 보이는 것이라, 그 줄에서 눈이 제일
                    // 오래 걸리는 곳이 여기다. pass 는 체인에서 몇째 칸인지고
                    // (apps/rice-knobs), 안 걸린 것은 없으므로 뒤로 간다.
                    root.targets = (d.targets || []).slice().sort(function (a, b) {
                        return (a.pass || 99) - (b.pass || 99);
                    });
                    root.error = "";

                    // 고르고 있던 것이 아직 목록에 있으면 그대로 둔다. 셰이더를
                    // 갈아 끼울 때마다 선택이 튀면 값을 맞춰 가는 중에 손을 놓친다.
                    const keep = root.targets.some(t => t.id === root.target);
                    if (!keep) {
                        const pick = root.targets.find(t => t.applied) || root.targets[0];
                        root.target = (pick || {}).id || "";
                    }
                    root.loadKnobs();
                } catch (e) {
                    root.targets = [];
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
        applyProc.key = pendingKey;
        applyProc.command = [root.bin, "set", root.target, pendingKey, String(pendingValue)];
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

        property string key: ""
        property string err: ""

        stderr: StdioCollector {
            onStreamFinished: applyProc.err = text
        }

        // 값이 밀려 있으면 이어서 보낸다. 적용이 도는 동안 슬라이더가 계속 움직였을
        // 때 마지막 값이 빠지는 것을 막는다.
        onExited: code => {
            if (code !== 0) {
                const lines = applyProc.err.split("\n").filter(l => l.trim().length > 0);
                root.failed(applyProc.key, lines.length > 0 ? lines[lines.length - 1] : ("종료 코드 " + code));
            }
            if (root.pendingKey)
                root.flush();
            else
                root.loadKnobs(); // 레포와 다름 표시를 갱신한다
        }
    }

    function reset(name) {
        if (resetProc.running)
            return;
        resetProc.command = [root.bin, "reset", root.target, name];
        resetProc.running = true;
    }

    Process {
        id: resetProc
        running: false
        onExited: root.loadKnobs()
    }
}
