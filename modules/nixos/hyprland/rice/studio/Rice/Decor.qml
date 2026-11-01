pragma Singleton

// 장식 값을 읽고 쓴다. 뒤판 apps/rice/decor 가 decor.lua 를 다시 쓰고 `hyprctl eval` 로 건다.
// 범위 표는 rice-decor 안에 있다(하이프랜드 옵션은 범위를 안 알려 준다). dirty 기준은 하이프랜드 기본값.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string bin: apps + "/decor"

    property var groups: []
    property string file: ""
    property string error: ""
    // 하이프랜드 세션인가. 아니면 rice-decor 는 파일에만 적고 화면에는 안 건다.
    property bool session: true

    // 탭 이름 옆에 붙어, 다른 탭을 보고 있어도 이 축을 건드린 게 보인다.
    property int dirtyCount: 0

    signal failed(string label, string message)

    Component.onCompleted: load()

    function load() {
        if (loadProc.running)
            return;
        loadProc.running = true;
    }

    Process {
        id: loadProc
        command: [root.bin]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.groups = d.groups || [];
                    root.file = d.file || "";
                    root.session = d.session !== false;

                    let n = 0;
                    for (const g of root.groups)
                        for (const k of (g.knobs || []))
                            if (k.dirty)
                                n++;
                    root.dirtyCount = n;
                    root.error = "";
                } catch (e) {
                    root.groups = [];
                    root.dirtyCount = 0;
                    root.error = "rice-decor 를 읽지 못했다: " + e;
                }
            }
        }
    }

    // ── 쓰기 ──────────────────────────────────────────────────────────────
    property string pendingKey: ""
    property real pendingValue: 0

    function push(key, value, immediate) {
        pendingKey = key;
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
        applyProc.command = [root.bin, "set", pendingKey, String(pendingValue)];
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

        // 다 보낸 뒤에야 다시 읽는다 — 끄는 중에 목록을 갈아 끼우면 슬라이더 델리게이트가 새로 만들어져 손을 놓친다.
        onExited: code => {
            if (code !== 0) {
                const lines = applyProc.err.split("\n").filter(l => l.trim().length > 0);
                root.failed(applyProc.key, lines.length > 0 ? lines[lines.length - 1] : ("종료 코드 " + code));
            }
            if (root.pendingKey)
                root.flush();
            else
                root.load();
        }
    }

    function reset(key) {
        if (resetProc.running)
            return;
        resetProc.command = key ? [root.bin, "reset", key] : [root.bin, "reset"];
        resetProc.running = true;
    }

    Process {
        id: resetProc
        running: false
        onExited: root.load()
    }
}
