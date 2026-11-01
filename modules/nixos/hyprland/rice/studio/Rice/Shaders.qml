pragma Singleton

// 화면 셰이더 축의 상태. 목록·걸린 것·탭 수·더할 수 있는 것은 `apps/rice/crt --json` 한 번이 준다.
// 곱 한도는 여기서 세면 안 된다 — 규칙은 apps/rice/chain 에만 있다.
// RICE_APPS 는 apps/rice/studio 가 넣는다. 없으면 체크아웃 경로(스크립트를 자주 고쳐서).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string crt: apps + "/crt"

    property var values: []
    property string current: "off"
    property var chain: []
    property int maxTaps: 64
    // 거는 것은 하이프랜드에서만 된다(apps/rice/crt 의 need_session).
    property bool session: true

    property bool busy: false
    property string error: ""

    signal failed(string label, string message)
    signal changed

    Component.onCompleted: refresh()

    function refresh() {
        if (reader.running)
            return;
        reader.running = true;
    }

    // 지금 체인의 몇째 칸인지. 0 이면 안 걸린 것이다.
    function passOf(name) {
        return chain.indexOf(name) + 1;
    }

    function valueOf(name) {
        for (var i = 0; i < values.length; i++)
            if (values[i].name === name)
                return values[i];
        return null;
    }

    // 표시용이다 — 더할 수 있는지의 판단은 여기서 안 한다.
    readonly property int chainTaps: {
        let n = 1;
        for (var i = 0; i < chain.length; i++) {
            const v = valueOf(chain[i]);
            n *= (v && v.taps) ? v.taps : 1;
        }
        return chain.length > 0 ? n : 0;
    }

    readonly property bool motion: {
        for (var i = 0; i < chain.length; i++) {
            const v = valueOf(chain[i]);
            if (v && v.motion)
                return true;
        }
        return false;
    }

    Process {
        id: reader
        command: [root.crt, "--json"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.values = d.values || [];
                    root.current = d.current || "off";
                    root.chain = d.chain || [];
                    root.maxTaps = d.maxTaps || 64;
                    root.session = d.session !== false;
                    root.error = "";
                } catch (e) {
                    // 시드 전이거나 jq 가 없으면 stdout 이 비어 온다. 빈 목록만 보이면 "셰이더가 없다"로 읽힌다.
                    root.values = [];
                    root.error = "rice-crt --json 을 읽지 못했다. ~/.config/hypr/shaders 가 있는지 확인할 것.";
                }
                root.changed();
            }
        }
    }

    // ── 밖에서 바뀐 것을 따라간다 ─────────────────────────────────────────
    // Mod+Shift+C·런처 off 로도 바뀌므로 rice-crt 가 적는 이 파일을 본다. 내용이 같으면 안 읽는다 —
    // 손잡이를 끌 때마다 rice-knobs 가 이 파일을 다시 써서, 읽으면 끌던 슬라이더가 새로 만들어진다.
    FileView {
        property string seen: ""
        property bool primed: false

        path: Quickshell.env("RICE_STATE")
            || ((Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/rice/shader")
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

    // ── 거는 것들 ─────────────────────────────────────────────────────────
    // 전부 rice-crt 로 간다. "한 장 더"도 여기서 칸 목록을 만들어 넘긴다.
    function apply(name) {
        run([name], name);
    }

    function applyStages(list) {
        run(list, list.join(" → "));
    }

    function add(name) {
        run(chain.concat([name]), "칸 더하기 · " + name);
    }

    function drop(index) {
        const next = chain.slice();
        next.splice(index, 1);
        if (next.length === 0) {
            run(["off"], "off");
            return;
        }
        run(next, "칸 빼기 · " + chain[index]);
    }

    function move(index, delta) {
        const to = index + delta;
        if (to < 0 || to >= chain.length)
            return;
        const next = chain.slice();
        const t = next[index];
        next[index] = next[to];
        next[to] = t;
        run(next, next.join(" → "));
    }

    function off() {
        run(["off"], "off");
    }

    function reload() {
        run(["--reload"], "다시 읽기");
    }

    function save(label) {
        run(["--save", label], "chain/" + label + " 으로 저장");
    }

    function run(args, label) {
        if (busy)
            return;
        busy = true;
        applier.label = label;
        applier.out = "";
        applier.command = [root.crt].concat(args);
        applier.running = true;
    }

    Process {
        id: applier
        running: false

        property string label: ""
        property string out: ""

        // 거절 이유는 stdout(rice_reject)에도 stderr(rice-chain 한도 초과)에도 온다.
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
                // 스크립트들이 터미널과 같은 말을 써서 색 코드가 섞여 온다.
                const last = (lines.length > 0 ? lines[lines.length - 1] : "").replace(/\x1b\[[0-9;]*m/g, "");
                root.failed(applier.label, last || ("종료 코드 " + code));
            }
            // 실패해도 다시 읽는다 — 앞 칸만 걸린 중간 상태에서 화면과 목록이 어긋난 채 남지 않게.
            root.refresh();
        }
    }
}
