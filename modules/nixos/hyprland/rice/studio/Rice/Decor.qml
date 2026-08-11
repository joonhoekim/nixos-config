pragma Singleton

// 하이프랜드 장식 값(투명도·흐리게·어둡게·그림자)을 읽고 쓴다. 뒤판은
// apps/rice-decor 이고, 그건 ~/.config/hypr/decor.lua 를 통째로 다시 쓴 뒤
// `hyprctl eval` 로 지금 화면에 건다.
//
// ── 여기 목록이 없는 것은 Knobs 와 같다 ───────────────────────────────────
// 무엇을 만질 수 있는지, 범위가 얼마인지, 기본값이 뭔지는 전부 스크립트가 준다.
// 다만 출처는 다르다 — 셰이더는 파일 안에 `// @0..1` 로 스스로 선언하지만
// 하이프랜드 옵션은 자기 범위를 안 알려 줘서, 그 표가 rice-decor 안에 있다.
// 어느 쪽이든 이 파일은 안 고치고 값을 늘릴 수 있다.
//
// ── 되돌리기의 기준이 다르다 ──────────────────────────────────────────────
// Knobs 의 dirty 는 "레포 사본과 다름"이지만 여기서는 "하이프랜드 기본값과
// 다름"이다. decor.lua 는 생성물이라 레포에 시드가 없어서다(rice-decor 머리말).
//
// ── 디바운스 ──────────────────────────────────────────────────────────────
// Knobs 와 같은 이유·같은 모양이다. 다만 여기는 파일을 다시 읽는 비용이 없고
// eval 한 번이 전부라 훨씬 싸다.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS") || ((Quickshell.env("HOME") || "") + "/nixos-config/apps")
    readonly property string bin: apps + "/rice-decor"

    property var groups: []
    property string file: ""
    property string error: ""

    // 기본값에서 벗어난 값의 수. 탭 이름 옆에 붙는다 — 다른 탭을 보고 있어도
    // 이 축을 건드려 뒀다는 사실이 보여야 한다.
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

        // 값이 밀려 있으면 이어서 보낸다. 다 보내고 나서야 다시 읽는다 — 끄는
        // 중에 목록을 갈아 끼우면 슬라이더 델리게이트가 새로 만들어지면서 손을
        // 놓친다.
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
