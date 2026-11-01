// RiceSwitcher — 라이싱 축을 DMS 런처(`:` 트리거, Mod+Shift+R)에서 고른다.
// 축·값·지금 것은 모른다 — apps/rice/menu 의 JSON 이 준다. 셰이더는 탈출구(off · 다음 것)만 남는다.
// getItems 는 동기여야 해서(PLUGINS/LauncherExample/README.md) 캐시를 돌려주고 itemsChanged() 로 다시 그린다.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: ":"

    signal itemsChanged

    // RICE_APPS · RICE_REPO · ~/nixos-config 순. 같은 규칙이 hyprland/rice/studio/Rice/*.qml 에도 있다.
    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string menu: apps + "/menu"

    property var axes: []
    property bool refreshing: false
    // 런처를 열 때마다 셸을 부르지 않게 하는 창. applier 가 0 으로 무효화한다.
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
                    // rice-menu 나 jq 가 없을 때. 목록이 비면 런처에 아무것도 안 뜬다.
                    console.warn("RiceSwitcher: rice-menu 를 읽지 못했다 —", e);
                    root.axes = [];
                }
                root.refreshing = false;
                root.itemsChanged();
            }
        }
    }

    // ── 항목 만들기 ───────────────────────────────────────────────────────
    // 값은 축마다 "고르기" 한 줄로 접고, 동작(누르는 것)은 안 접는다.
    // 한글 이름에 `studio` 같은 영어 질의가 걸리도록 rice-menu 가 준 keywords 를 싣는다(Scorer.js).
    function axisKeys(axis) {
        return [axis.id].concat(axis.keywords || []);
    }

    function topItems() {
        const out = [];

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
                    detach: actions[j].detach === true,
                    keywords: axisKeys(axis).concat(actions[j].keywords || []),
                    categories: ["Rice"]
                });
            }

            const values = axis.values || [];
            if (values.length > 0)
                out.push({
                    name: axis.label + " 고르기",
                    icon: icon,
                    comment: (axis.current ? "지금 " + axis.current + " · " : "") + values.join(" / "),
                    action: "drill:" + axis.id,
                    keywords: axisKeys(axis),
                    categories: ["Rice"]
                });
        }
        return out;
    }

    // keywords 에 축 id 를 넣어야 드릴다운이 된다. 런처가 같은 질의로 한 번 더 점수 필터를 걸어
    // (Scorer.js: `if (itemScore > 0 || !query)`), 없으면 "터미널 · crt" 가 `term` 에 0점으로 전부 탈락한다.
    function leafItems(axis) {
        const out = [];
        const icon = "material:" + (axis.icon || "tune");
        const values = axis.values || [];
        for (var k = 0; k < values.length; k++) {
            const v = values[k];
            const isCurrent = v === axis.current;
            out.push({
                // 런처가 배지를 안 그려 주므로 지금 것 표시는 이름에 넣는다.
                name: axis.label + " · " + v + (isCurrent ? "   ✓" : ""),
                icon: icon,
                comment: isCurrent ? "지금 이것" : (axis.current ? "현재 " + axis.current + " → " + v : v + " 로"),
                action: axis.id + ":" + v,
                keywords: axisKeys(axis).concat([v]),
                categories: ["Rice"]
            });
        }
        return out;
    }

    function getItems(query) {
        if (!refreshing && Date.now() - lastRefresh > staleMs)
            refresh();

        const q = (query || "").trim();

        // 축 이름(또는 영어 별칭)으로 시작하면 그 축만 펼친다(executeItem 의 drill:).
        const lq = q.toLowerCase();
        for (var i = 0; i < axes.length; i++) {
            const keys = axisKeys(axes[i]);
            for (var k = 0; k < keys.length; k++) {
                const key = keys[k].toLowerCase();
                if (lq === key || lq.indexOf(key + " ") === 0)
                    return leafItems(axes[i]);
            }
        }

        if (q === "")
            return topItems();

        // 검색은 접힌 것을 뚫는다(`:amoled` 로 바로 닿게).
        var all = topItems();
        for (var j = 0; j < axes.length; j++)
            all = all.concat(leafItems(axes[j]));

        return all.filter(function (it) {
            if (it.name.toLowerCase().indexOf(lq) !== -1 || (it.comment || "").toLowerCase().indexOf(lq) !== -1)
                return true;
            const kw = it.keywords || [];
            for (var m = 0; m < kw.length; m++)
                if (kw[m].toLowerCase().indexOf(lq) !== -1)
                    return true;
            return false;
        });
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;

        const sep = item.action.indexOf(":");
        if (sep < 0)
            return;

        // 플러그인이 질의를 바꿀 훅이 없어 밖에서 다시 연다. 질의는 한글 라벨이 아니라 축 id 다.
        if (item.action.indexOf("drill:") === 0) {
            const axisId = item.action.substring(6);
            Quickshell.execDetached(["dms", "ipc", "call", "spotlight", "openQuery", root.trigger + axisId + " "]);
            return;
        }

        // 스튜디오처럼 창이 닫힐 때까지 사는 동작은 rice-menu 가 actions[].detach 로 알린다.
        if (item.detach) {
            Quickshell.execDetached([root.menu].concat(item.action.split(":")));
            return;
        }

        // sh -c 없이 argv 로 넘긴다 — 값의 공백·따옴표를 인용할 필요가 없다.
        applier.label = item.name;
        applier.command = [root.menu].concat(item.action.split(":"));
        applier.running = true;
    }

    Process {
        id: applier
        running: false

        property string label: ""
        // 스위처는 거절 이유를 stdout 에 쓰고(rice_reject) 목록을 뒤에 붙이므로 전체를 모은다.
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
