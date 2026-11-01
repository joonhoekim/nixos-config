pragma Singleton

// 배치 축의 상태. 뒤판 apps/rice/layout --json 한 번으로 목록·지금 것·손잡이를 받는다.
// 손잡이는 지금 걸린 배치의 것만 준다. dirty 기준은 레포 사본(rice/layouts).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string bin: apps + "/layout"

    property var values: []
    property string current: ""
    property string file: ""
    property bool session: false
    property var groups: []

    property bool busy: false
    property string error: ""

    // 탭 이름 옆은 배치 이름 자리라 머리의 한 줄이 쓴다.
    property int dirtyCount: 0

    signal failed(string label, string message)

    Component.onCompleted: refresh()

    function refresh() {
        if (reader.running)
            return;
        reader.running = true;
    }

    function valueOf(name) {
        for (var i = 0; i < values.length; i++)
            if (values[i].name === name)
                return values[i];
        return null;
    }

    Process {
        id: reader
        command: [root.bin, "--json"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.values = d.values || [];
                    root.current = d.current || "";
                    root.file = d.file || "";
                    root.session = d.session === true;
                    root.groups = d.groups || [];

                    let n = 0;
                    for (const g of root.groups)
                        for (const k of (g.knobs || []))
                            if (k.dirty)
                                n++;
                    root.dirtyCount = n;
                    root.error = "";
                } catch (e) {
                    // 시드 전이거나 jq 가 없다. 빈 목록만 보이면 "배치가 없다"로 읽힌다.
                    root.values = [];
                    root.groups = [];
                    root.dirtyCount = 0;
                    root.error = "rice-layout --json 을 읽지 못했다. ~/.config/hypr/layouts 가 있는지 확인할 것.";
                }
            }
        }
    }

    // ── 밖에서 바뀐 것을 따라간다 ─────────────────────────────────────────
    // 런처와 `apps/rice/layout --next` 도 같은 파일을 쓴다. 모르면 안 걸린 배치의 값을 끌게 된다.
    FileView {
        property string seen: ""
        property bool primed: false

        path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/rice/layout"
        watchChanges: true
        blockLoading: false
        onLoaded: {
            const t = text();
            if (primed && t !== seen)
                root.refresh();
            seen = t;
            primed = true;
        }
        onFileChanged: reload()
    }

    // ── 거는 것 ───────────────────────────────────────────────────────────
    function apply(name) {
        run([name], name);
    }

    function reload() {
        run(["--reload"], "다시 읽기");
    }

    function run(args, label) {
        if (busy)
            return;
        busy = true;
        applier.label = label;
        applier.out = "";
        applier.command = [root.bin].concat(args);
        applier.running = true;
    }

    Process {
        id: applier
        running: false

        property string label: ""
        property string out: ""

        stdout: StdioCollector {
            onStreamFinished: applier.out = text
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text)
                    applier.out = text;
            }
        }

        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                const lines = applier.out.split("\n").filter(l => l.trim().length > 0);
                const last = (lines.length > 0 ? lines[lines.length - 1] : "").replace(/\x1b\[[0-9;]*m/g, "");
                root.failed(applier.label, last || ("종료 코드 " + code));
            }
            root.refresh();
        }
    }

    // ── 값 쓰기 ───────────────────────────────────────────────────────────
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
        if (!pendingKey || setter.running)
            return;
        setter.key = pendingKey;
        setter.err = "";
        setter.command = [root.bin, "set", root.current, pendingKey, String(pendingValue)];
        pendingKey = "";
        setter.running = true;
    }

    Timer {
        id: debounce
        interval: 110
        onTriggered: root.flush()
    }

    Process {
        id: setter
        running: false

        property string key: ""
        property string err: ""

        stderr: StdioCollector {
            onStreamFinished: setter.err = text
        }

        // 다 보낸 뒤에야 다시 읽는다(Decor 와 같은 이유).
        onExited: code => {
            if (code !== 0) {
                const lines = setter.err.split("\n").filter(l => l.trim().length > 0);
                root.failed(setter.key, (lines.length > 0 ? lines[lines.length - 1] : ("종료 코드 " + code)).replace(/\x1b\[[0-9;]*m/g, ""));
            }
            if (root.pendingKey)
                root.flush();
            else
                root.refresh();
        }
    }

    function reset(key) {
        if (resetter.running)
            return;
        resetter.command = key ? [root.bin, "reset", root.current, key] : [root.bin, "reset", root.current];
        resetter.running = true;
    }

    Process {
        id: resetter
        running: false
        onExited: root.refresh()
    }
}
