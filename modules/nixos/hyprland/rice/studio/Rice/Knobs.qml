pragma Singleton

// 셰이더 손잡이를 읽고 쓴다. 뒤판 apps/rice/knobs 가 셰이더의 `// @0..1` 표시를 읽는다.
// 쓰는 곳은 $HOME, 레포는 비교용. 한 번 쓰면 다시 걸기까지 90ms 쯤이라 마지막 값만 모아 보낸다.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string bin: apps + "/knobs"

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
                    // 걸린 칸을 번호(pass) 순으로 앞에 당긴다. 이 엔진의 sort 는 안정 정렬이 아니라
                    // 같은 순위는 스크립트 순서(i)로 갈라야 칩 자리가 열 때마다 안 바뀐다.
                    root.targets = (d.targets || []).map(function (t, i) {
                        return { t: t, i: i };
                    }).sort(function (a, b) {
                        return ((a.t.pass || 99) - (b.t.pass || 99)) || (a.i - b.i);
                    }).map(function (e) {
                        return e.t;
                    });
                    root.error = "";

                    // 셰이더를 갈아 끼울 때마다 선택이 튀면 값을 맞추는 중에 손을 놓친다.
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

        // 적용 중에 슬라이더가 움직였으면 마지막 값이 빠지지 않게 이어서 보낸다.
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
