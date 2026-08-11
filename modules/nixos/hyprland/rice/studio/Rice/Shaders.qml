pragma Singleton

// 화면 셰이더 축의 상태. 창은 이 싱글턴만 보고 그린다.
//
// ── 아는 것이 하나도 없다 ─────────────────────────────────────────────────
// 목록도, 지금 걸린 것도, 탭 수도, 무엇을 더할 수 있는지도 여기서 계산하지
// 않는다. `apps/rice-crt --json` 한 번이 그걸 전부 준다. 특히 **곱 한도**는
// 여기서 세면 안 된다 — 규칙은 apps/rice-chain 에 있고, 예전 런처 플러그인이
// 그걸 QML 에서 한 번 더 세다가 값이 갈렸다(`now * taps > (maxTaps || 64)`).
//
// ── 왜 한 번인가 ──────────────────────────────────────────────────────────
// 예전에는 값마다 apps/rice-chain --info 를 불렀다. 열 몇 장이면 프로세스가
// 예순 개고, 런처는 창을 닫았다 여는 물건이라 2 초 캐시로 가릴 수 있었다. 창을
// 열어 두고 만지는 여기서는 못 가린다. --json 은 프로세스 하나이고, 그 안의
// 탭·흐름은 mtime 으로 캐시된다(apps/rice-chain --info-all).
//
// ── 스크립트 경로 ─────────────────────────────────────────────────────────
// RICE_APPS 를 apps/rice-studio 가 넣어 준다. 그게 없으면 관례 경로다 — 라이싱
// 중에는 스크립트를 자주 고치므로 스토어가 아니라 체크아웃을 부르는 것이 기본이고,
// `nix run` 으로 띄웠을 때만 스토어 쪽이 env 로 들어온다.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apps: Quickshell.env("RICE_APPS") || ((Quickshell.env("HOME") || "") + "/nixos-config/apps")
    readonly property string crt: apps + "/rice-crt"

    property var values: []
    property string current: "off"
    property var chain: []
    property int maxTaps: 64

    property bool busy: false
    property string error: ""

    // 창이 토스트를 띄우는 자리. 실패한 명령과 그 마지막 줄.
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

    // 지금 체인의 탭 곱. 표시용이다 — 무엇을 더할 수 있는지의 판단은 여기서 안 한다.
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
                    root.error = "";
                } catch (e) {
                    // 하이프랜드 세션이 아니면 rice-crt 가 거절하고 stdout 이 비어
                    // 온다. 목록을 비우고 이유를 창에 띄운다 — 빈 목록만 보여 주면
                    // "셰이더가 하나도 없다"로 읽힌다.
                    root.values = [];
                    root.error = "rice-crt --json 을 읽지 못했다. 하이프랜드 세션인지 확인할 것.";
                }
                root.changed();
            }
        }
    }

    // ── 거는 것들 ─────────────────────────────────────────────────────────
    // 전부 rice-crt 한 곳으로 간다. "지금 것에 한 장 더" 같은 것도 여기서 칸
    // 목록을 만들어 넘기는 것이라 rice-crt 는 여전히 "이 칸들을 걸어라"만 안다.
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

        // 거절 이유는 stdout 에 오기도 하고(rice_reject) stderr 에 오기도 한다
        // (rice-chain 의 한도 초과). 둘 다 모아 두고 마지막 줄을 쓴다.
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
                // 색 코드가 섞여 온다 — 스크립트들이 터미널에도 같은 말을 쓴다.
                const last = (lines.length > 0 ? lines[lines.length - 1] : "").replace(/\x1b\[[0-9;]*m/g, "");
                root.failed(applier.label, last || ("종료 코드 " + code));
            }
            // 실패해도 다시 읽는다. 앞의 칸만 걸렸다든가 하는 중간 상태가 있을 수
            // 있고, 그때 화면과 목록이 어긋난 채로 남는 것이 제일 나쁘다.
            root.refresh();
        }
    }
}
