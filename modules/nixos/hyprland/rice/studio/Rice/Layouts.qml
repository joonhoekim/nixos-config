pragma Singleton

// 배치(레이아웃) 축의 상태. 창은 이 싱글턴만 보고 그린다. 뒤판은 apps/rice/layout
// 이고, 목록·지금 것·손잡이를 `--json` 한 번으로 받는다.
//
// ── Shaders 와 Decor 의 중간이다 ──────────────────────────────────────────
// 고르는 쪽은 Shaders 처럼 목록에서 하나를 걸고, 값 쪽은 Decor 처럼 손잡이를
// 끌어 쓴다. 다만 손잡이는 **지금 걸린 배치의 것만** 준다 — 이 창은 조절하는
// 화면이 곧 표본인 창이라, 안 걸린 배치의 값을 끌어 봐야 화면에 아무 일도 안
// 일어나고 그건 고장으로 보인다. 다른 배치의 값을 고치려면 먼저 그것을 건다.
//
// ── 되돌리기의 기준은 레포다 ──────────────────────────────────────────────
// 배치 파일은 레포에 시드가 있다(modules/nixos/hyprland/rice/layouts). 그래서
// dirty 는 Knobs 와 같이 "레포 사본과 다름"이고, Decor 의 "하이프랜드 기본값과
// 다름"이 아니다.
//
// ── 디바운스 ──────────────────────────────────────────────────────────────
// 값 하나를 쓰면 뒤판이 파일을 고치고 배치 파일을 통째로 다시 돌린다(키를 풀고
// 다시 건다). 슬라이더를 끄는 동안 초당 몇 번씩 할 일은 아니라 Decor 와 같은
// 간격으로 묶는다.

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

    // 레포와 다른 값의 수. 탭 이름 옆에는 안 붙인다 — 거기는 지금 배치 이름이
    // 가는 자리라서다. 머리의 한 줄이 쓴다.
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
                    // 배치 폴더가 아직 시드되지 않았거나 jq 가 없다. 빈 목록만
                    // 보여 주면 "배치가 하나도 없다"로 읽힌다.
                    root.values = [];
                    root.groups = [];
                    root.dirtyCount = 0;
                    root.error = "rice-layout --json 을 읽지 못했다. ~/.config/hypr/layouts 가 있는지 확인할 것.";
                }
            }
        }
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

        // 밀린 값이 있으면 이어서 보내고, 다 보낸 뒤에야 다시 읽는다 — 끄는 중에
        // 목록을 갈아 끼우면 슬라이더가 새로 만들어지면서 손을 놓친다(Decor 와 같다).
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
