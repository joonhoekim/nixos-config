// RiceSwitcher — 라이싱 축 전부를 DMS 런처(Mod+space) 안에서 고른다.
//
// Mod+Shift+R 이 `dms ipc call spotlight toggleQuery ":"` 로 이 플러그인의
// 트리거를 미리 쳐 둔 채 런처를 연다. 그냥 Mod+space 로 열고 `:` 를 쳐도 같다.
//
// ── 이 파일이 하지 않는 일 ────────────────────────────────────────────────
// 축이 몇 개인지, 값이 무엇인지, 지금 무엇이 걸려 있는지 전부 모른다. 그건
// ~/nixos-config/apps/rice-menu 가 JSON 으로 알려 준다. 새 축이 생기거나 스위처의
// 인터페이스가 바뀌어도 이 파일은 그대로다 — 셸 쪽만 고치면 된다.
//
// 그렇게 가른 이유는 반영 속도다. QML 은 ~/.config/DankMaterialShell/plugins/ 에
// 시드되어 DMS 가 폴더를 감시하다 다시 읽고, rice-menu 는 레포에서 바로 실행된다.
// 둘 다 rebuild 없이 고쳐진다.
//
// ── 런처 플러그인 계약 ────────────────────────────────────────────────────
// DMS 가 요구하는 것(PLUGINS/LauncherExample/README.md):
//   property var pluginService, property string trigger
//   signal itemsChanged(), function getItems(query), function executeItem(item)
// getItems 는 **동기**여야 한다. 셸을 부르는 건 비동기라, 목록은 미리 받아 두고
// 캐시를 돌려준 뒤 새 값이 오면 itemsChanged() 로 다시 그리게 한다.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: ":"

    signal itemsChanged

    readonly property string menu: (Quickshell.env("HOME") || "") + "/nixos-config/apps/rice-menu"

    property var axes: []
    property bool refreshing: false
    // 마지막으로 목록을 받은 시각. 런처를 열 때마다 셸을 네 번 부르지 않도록
    // 이 값으로 창을 둔다. 값을 하나 걸면 아래 applier 가 0 으로 만들어 무효화한다.
    property double lastRefresh: 0
    readonly property int staleMs: 2000

    Component.onCompleted: {
        if (pluginService)
            trigger = pluginService.loadPluginData("riceSwitcher", "trigger", ":");
        refresh();
    }

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        loader.running = true;
    }

    Process {
        id: loader
        command: [root.menu]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.axes = (JSON.parse(text).axes) || [];
                    root.lastRefresh = Date.now();
                } catch (e) {
                    // rice-menu 가 없거나(레포를 다른 곳에 뒀거나) jq 가 없을 때 여기로
                    // 온다. 목록을 비워 두면 런처에 아무것도 안 뜨는 것으로 보인다.
                    console.warn("RiceSwitcher: rice-menu 를 읽지 못했다 —", e);
                    root.axes = [];
                }
                root.refreshing = false;
                root.itemsChanged();
            }
        }
    }

    // ── 갈래 ──────────────────────────────────────────────────────────────
    // 값 이름이 곧 갈래다 — `crt/crt` · `water/still` · `chain/newsprint` ·
    // `term/glow`. 셰이더 폴더 구조가 그대로 이름에 들어 있어서(apps/rice-chain),
    // UI 는 `/` 앞을 떼는 것만으로 접을 수 있고 갈래 목록을 따로 안 들고 있어도
    // 된다. 셰이더를 새 폴더에 넣으면 여기 손 안 대고 새 갈래가 생긴다.
    function groupOf(value) {
        const i = value.indexOf("/");
        return i < 0 ? "" : value.substring(0, i);
    }

    function groupsOf(axis) {
        const seen = {};
        const out = [];
        const values = axis.values || [];
        for (var i = 0; i < values.length; i++) {
            const g = groupOf(values[i]);
            if (g === "" || seen[g])
                continue;
            seen[g] = true;
            out.push(g);
        }
        return out;
    }

    // 점수기가 요구하는 모양의 키워드. Scorer.js 는 키워드 하나를 **질의 전체**와
    // 견주지, 낱말로 쪼개서 보지 않는다(score(): calculateTextScore(keyword, q)).
    // 그래서 `shader` 하나만 넣어 두면 질의가 `shader crt` 가 되는 순간 전부
    // 0점으로 탈락해 목록이 빈다. 사용자가 실제로 치게 되는 문자열을 그대로
    // 넣어 두는 것이 이 점수기에서 드릴다운을 성립시키는 유일한 방법이다.
    function drillKeywords(axisId, sub) {
        return sub ? [axisId, axisId + " " + sub] : [axisId];
    }

    // 값 하나의 부제. 탭 수와 흐름은 셰이더 축에만 있다(apps/rice-menu 의 meta).
    function valueNote(axis, v) {
        const m = (axis.meta || {})[v];
        if (!m)
            return "";
        return m.taps + "탭" + (m.motion ? " · 흐름 (VFR 끔)" : " · 정지 화면 공짜");
    }

    // ── 항목 만들기 ───────────────────────────────────────────────────────
    // 값 목록은 접어 둔다. 값을 한 줄씩 늘어놓으면 목록의 대부분이 "지금 안 고를
    // 것"으로 채워지고, 정작 자주 누르는 것(값 조절, 다시 읽기)이 그 사이에 묻힌다.
    // 그래서 축 하나 = "고르기" 한 줄이고, 지금 걸린 것과 후보는 그 줄의 부제로
    // 보인다.
    //
    // **동작은 안 접는다.** 다시 읽기나 월페이퍼 무작위처럼 "고르는" 게 아니라
    // "누르는" 것들은 한 번에 닿아야 값을 한다. 접느냐 마느냐의 기준이 개수가
    // 아니라 성격인 이유다.
    function topItems() {
        const out = [{
            name: "값 조절…",
            icon: "material:tune",
            comment: "셰이더 값을 슬라이더로. 로컬에만 쓰고, 레포에는 apps/rice-save 로",
            action: "panel:open",
            categories: ["Rice"]
        }];

        for (var i = 0; i < axes.length; i++) {
            const axis = axes[i];
            const icon = "material:" + (axis.icon || "tune");

            const actions = axis.actions || [];
            for (var j = 0; j < actions.length; j++) {
                out.push({
                    name: axis.label + " · " + actions[j].label,
                    icon: icon,
                    comment: actions[j].comment || "",
                    action: axis.id + ":" + actions[j].value,
                    keywords: [axis.id],
                    categories: ["Rice"]
                });
            }

            const values = axis.values || [];
            if (values.length > 0) {
                // 부제에 값을 다 늘어놓던 것이 열 몇 개가 되면서 안 읽히게 됐다.
                // 갈래가 있으면 갈래 이름만 보여 준다 — 그게 다음에 누를 것과
                // 같은 낱말이라 부제가 곧 안내가 된다.
                const groups = groupsOf(axis);
                const summary = groups.length > 1 ? groups.join(" · ") : values.join(" / ");
                out.push({
                    name: axis.label + " 고르기",
                    icon: icon,
                    comment: (axis.current ? "지금 " + axis.current + " · " : "") + summary,
                    action: "drill:" + axis.id,
                    keywords: [axis.id],
                    categories: ["Rice"]
                });
            }
        }
        return out;
    }

    // ── 한 축 안 ──────────────────────────────────────────────────────────
    // 갈래가 없는 축(프로필·터미널)은 예전 그대로 값이 바로 나온다. 갈래가 있으면
    // 한 단이 더 생긴다: 갈래 줄 → 그 갈래의 값들.
    //
    // 체인을 손보는 줄들이 여기 같이 있는 것은, 그것이 "무엇을 걸까"와 같은 질문
    // 이기 때문이다. 지금 걸린 것에 한 장 더 얹는 것과 다른 것으로 바꾸는 것은
    // 사용자에게 같은 자리의 선택이다.
    function axisItems(axis, sub) {
        const groups = groupsOf(axis);
        if (groups.length < 2)
            return leafItems(axis, axis.values || [], sub);

        const icon = "material:" + (axis.icon || "tune");
        const chain = axis.chain || [];

        // 이름을 받아야 하는 것은 질의로 받는다. 런처에는 플러그인이 글자를 물어볼
        // 훅이 없고, 모달을 따로 띄우면 런처가 닫히면서 맥락이 끊긴다. 어차피
        // 검색창에 커서가 있으니 거기서 이어 치는 편이 손이 덜 간다.
        if (sub.indexOf("save") === 0) {
            const label = sub.substring(4).trim();
            if (label === "")
                return [{
                    name: "체인을 이름 붙여 저장 — 이어서 이름을 치세요",
                    icon: icon,
                    comment: chain.length > 0 ? chain.join(" → ") : "지금은 off 다",
                    action: "noop:",
                    keywords: drillKeywords(axis.id, "save"),
                    categories: ["Rice"]
                }];
            return [{
                name: "체인을 " + label + " 으로 저장",
                icon: icon,
                comment: chain.join(" → ") + "  →  chain/" + label,
                action: axis.id + ":save:" + label,
                keywords: drillKeywords(axis.id, sub),
                categories: ["Rice"]
            }];
        }

        // 더할 수 있는 것만 보여 준다. 체인 비용은 곱이라(apps/rice-chain) 무엇을
        // 더하느냐에 따라 될 수도 안 될 수도 있고, 그 계산은 이미 meta 로 와 있다.
        // 못 걸 것을 늘어놓고 누른 뒤에 거절하는 것은 목록이 거짓말을 하는 것이다.
        if (sub === "add") {
            let now = 1;
            for (var c = 0; c < chain.length; c++)
                now *= ((axis.meta || {})[chain[c]] || {}).taps || 1;

            const out = [];
            const values = axis.values || [];
            for (var i = 0; i < values.length; i++) {
                const v = values[i];
                const m = (axis.meta || {})[v];
                if (!m || v === "off")
                    continue;   // off 과 저장된 체인은 "한 장"이 아니다
                if (now * m.taps > (axis.maxTaps || 64))
                    continue;
                out.push({
                    name: "칸 더하기 · " + v,
                    icon: icon,
                    comment: chain.concat([v]).join(" → ") + "   " + (now * m.taps) + "탭",
                    action: axis.id + ":add:" + v,
                    keywords: drillKeywords(axis.id, "add"),
                    categories: ["Rice"]
                });
            }
            if (out.length === 0)
                out.push({
                    name: "더할 수 있는 칸이 없다",
                    icon: icon,
                    comment: "지금 체인이 이미 " + now + "탭이다 (한도 " + (axis.maxTaps || 64) + "). 비용은 곱이라 한 장 더 얹을 자리가 없다",
                    action: "noop:",
                    keywords: drillKeywords(axis.id, "add"),
                    categories: ["Rice"]
                });
            return out;
        }

        // 갈래 하나를 골랐으면 그 갈래의 값들.
        for (var g = 0; g < groups.length; g++) {
            if (sub !== groups[g])
                continue;
            const only = (axis.values || []).filter(function (v) {
                return groupOf(v) === groups[g];
            });
            return leafItems(axis, only, sub);
        }

        // 아무것도 안 쳤을 때 — 갈래 줄과 체인 손보기.
        const out = [];
        if (chain.length > 0) {
            out.push({
                name: "칸 더하기…",
                icon: icon,
                comment: chain.join(" → ") + " 뒤에 한 장 더",
                action: "drill:" + axis.id + " add",
                keywords: [axis.id],
                categories: ["Rice"]
            });
            out.push({
                name: "체인으로 저장…",
                icon: icon,
                comment: chain.join(" → ") + " 에 이름을 붙여 둔다",
                action: "drill:" + axis.id + " save",
                keywords: [axis.id],
                categories: ["Rice"]
            });
        }
        // off 은 갈래가 없다. 탈출구라 늘 한 번에 닿아야 한다.
        if ((axis.values || []).indexOf("off") >= 0)
            out.push({
                name: axis.label + " · off",
                icon: icon,
                comment: axis.current === "off" ? "지금 이것" : "셰이더 없는 상태로",
                action: axis.id + ":off",
                keywords: [axis.id],
                categories: ["Rice"]
            });
        for (var k = 0; k < groups.length; k++) {
            const n = (axis.values || []).filter(function (v) {
                return groupOf(v) === groups[k];
            });
            out.push({
                name: axis.label + " · " + groups[k],
                icon: icon,
                comment: n.map(function (v) {
                    return v.substring(groups[k].length + 1);
                }).join(" / "),
                action: "drill:" + axis.id + " " + groups[k],
                keywords: [axis.id],
                categories: ["Rice"]
            });
        }
        return out;
    }

    // 한 축의 값들. 접힌 줄을 눌렀을 때와, 검색이 값 이름에 걸렸을 때 쓰인다.
    //
    // keywords 에 축 id 를 넣는 것이 드릴다운을 성립시킨다. 플러그인이 항목을
    // 돌려줘도 런처가 **같은 질의로 한 번 더 점수 필터**를 걸기 때문이다
    // (Scorer.js: `if (itemScore > 0 || !query)`). 질의가 `shader` 인데 항목
    // 이름은 "화면 셰이더 · off" 라 한 글자도 안 겹치므로, 키워드가 없으면 전부
    // 0점으로 탈락해 목록이 빈다 — 실제로 그렇게 나왔다. 점수기는 이름과 부제가
    // 0점일 때 keywords 를 보므로(Scorer.js:133), 화면에 안 보이는 채로 통과한다.
    function leafItems(axis, values, sub) {
        const out = [];
        const icon = "material:" + (axis.icon || "tune");
        for (var k = 0; k < values.length; k++) {
            const v = values[k];
            const isCurrent = v === axis.current;
            const note = valueNote(axis, v);
            out.push({
                // 체크 표시는 이름에 넣는다. 런처가 항목마다 배지를 그려 주지
                // 않으므로, 지금 걸린 것을 한눈에 보려면 이 자리뿐이다.
                name: axis.label + " · " + v + (isCurrent ? "   ✓" : ""),
                icon: icon,
                comment: (isCurrent ? "지금 이것" : (axis.current ? "현재 " + axis.current + " → " + v : v + " 로")) + (note ? "   " + note : ""),
                action: axis.id + ":" + v,
                keywords: drillKeywords(axis.id, sub || ""),
                categories: ["Rice"]
            });
        }
        return out;
    }

    function getItems(query) {
        // 창을 열 때 값이 낡았으면 새로 받는다. 이 호출은 캐시를 그대로 돌려주고,
        // 값이 도착하면 itemsChanged() 로 다시 그려진다.
        if (!refreshing && Date.now() - lastRefresh > staleMs)
            refresh();

        const q = (query || "").trim();

        // 축 이름으로 시작하면 그 축만 펼친다. "고르기"를 누르면 런처가 이 질의를
        // 미리 쳐 준 채로 다시 열린다(executeItem 의 drill:). 뒤에 더 친 글자는
        // 갈래 이름이거나 `add`/`save` 다.
        for (var i = 0; i < axes.length; i++) {
            if (q === axes[i].id)
                return axisItems(axes[i], "");
            if (q.indexOf(axes[i].id + " ") === 0)
                return axisItems(axes[i], q.substring(axes[i].id.length).trim());
        }

        if (q === "")
            return topItems();

        // 검색은 접힌 것을 뚫는다. `:crt` 로 셰이더와 터미널의 crt 에 바로 닿는
        // 것이 접기의 대가가 되어서는 안 된다. 여기서는 갈래도 안 거친다 —
        // 이름을 아는 사람은 갈래를 안 거치고 싶은 것이다.
        var all = topItems();
        for (var j = 0; j < axes.length; j++)
            all = all.concat(leafItems(axes[j], axes[j].values || [], ""));

        const lq = q.toLowerCase();
        return all.filter(function (it) {
            return it.name.toLowerCase().indexOf(lq) !== -1 || (it.comment || "").toLowerCase().indexOf(lq) !== -1;
        });
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;

        const sep = item.action.indexOf(":");
        if (sep < 0)
            return;

        // 안내만 하는 줄. 누르면 런처만 닫힌다.
        if (item.action.indexOf("noop:") === 0)
            return;

        // 값 조절 패널은 축을 거는 것이 아니라 DMS 안을 여는 것이라 rice-menu 를
        // 안 탄다. 런처가 닫히면서 설정 모달이 열린다.
        if (item.action === "panel:open") {
            Quickshell.execDetached(["dms", "ipc", "call", "settings", "toggleWith", "plugins"]);
            return;
        }

        // 접힌 축을 펼친다. 런처에는 플러그인이 질의를 바꿀 훅이 없어서, 밖에서
        // 다시 여는 것으로 대신한다 — 항목을 실행하면 런처가 닫히므로 순서도 맞는다.
        // 질의에 쓰는 것은 한글 라벨이 아니라 축 id 다. 검색창에 남는 글자라서,
        // 짧고 오타가 안 나는 쪽이 낫다.
        if (item.action.indexOf("drill:") === 0) {
            const axisId = item.action.substring(6);
            Quickshell.execDetached(["dms", "ipc", "call", "spotlight", "openQuery", root.trigger + axisId + " "]);
            return;
        }

        // sh -c 를 안 끼운다. 값에 공백이나 따옴표가 없다는 보장이 없고, argv 로
        // 바로 넘기면 인용을 생각할 필요가 없다.
        //
        // 칸을 셋으로 쪼개는 것은 체인 손보기 때문이다 — `shader:add:crt/crt` 는
        // rice-menu 에게 인자 셋으로 가야 한다. 값에는 `:` 이 안 들어가므로
        // (셰이더 이름은 `갈래/이름`) 쪼개는 규칙이 값과 안 부딪힌다.
        applier.label = item.name;
        applier.command = [root.menu].concat(item.action.split(":"));
        applier.running = true;
    }

    Process {
        id: applier
        running: false

        property string label: ""
        // 실패했을 때 보여줄 마지막 줄. 스위처들은 거절 이유를 stdout 에 쓰고
        // (rice_reject) 목록을 뒤에 붙이므로, 첫 줄이 아니라 전체를 모아 둔다.
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
            // 어느 쪽이든 현재값이 바뀌었을 수 있다. 다음에 열 때 새로 받게 한다.
            root.lastRefresh = 0;

            if (typeof ToastService === "undefined")
                return;

            if (code === 0)
                ToastService.showInfo(applier.label);
            else
                ToastService.showError(applier.label, applier.out.split("\n").filter(function (l) {
                    return l.trim().length > 0;
                }).pop() || ("종료 코드 " + code));
        }
    }
}
