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

    property var cached: []
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
                    root.cached = root.buildItems(JSON.parse(text));
                    root.lastRefresh = Date.now();
                } catch (e) {
                    // rice-menu 가 없거나(레포를 다른 곳에 뒀거나) jq 가 없을 때 여기로
                    // 온다. 목록을 비워 두면 런처에 아무것도 안 뜨는 것으로 보인다.
                    console.warn("RiceSwitcher: rice-menu 를 읽지 못했다 —", e);
                    root.cached = [];
                }
                root.refreshing = false;
                root.itemsChanged();
            }
        }
    }

    // JSON → 런처 항목. 축 하나가 "동작 먼저, 값 나중" 순서로 펼쳐진다.
    // 이름에 축을 앞세우는 건 검색 때문이다: `:셰` 로 축을, `:crt` 로 값을 좁힌다.
    function buildItems(data) {
        const out = [];
        const axes = (data && data.axes) || [];

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
                    categories: ["Rice"]
                });
            }

            const values = axis.values || [];
            for (var k = 0; k < values.length; k++) {
                const v = values[k];
                const isCurrent = v === axis.current;
                out.push({
                    // 체크 표시는 이름에 넣는다. 런처가 항목마다 배지를 그려 주지
                    // 않으므로, 지금 걸린 것을 한눈에 보려면 이 자리뿐이다.
                    name: axis.label + " · " + v + (isCurrent ? "   ✓" : ""),
                    icon: icon,
                    comment: isCurrent ? "지금 이것" : (axis.current ? "현재 " + axis.current + " → " + v : v + " 로"),
                    action: axis.id + ":" + v,
                    categories: ["Rice"]
                });
            }
        }
        return out;
    }

    function getItems(query) {
        // 창을 열 때 값이 낡았으면 새로 받는다. 이 호출은 캐시를 그대로 돌려주고,
        // 값이 도착하면 itemsChanged() 로 다시 그려진다.
        if (!refreshing && Date.now() - lastRefresh > staleMs)
            refresh();

        if (!query || query.length === 0)
            return cached;

        const q = query.toLowerCase();
        return cached.filter(function (it) {
            return it.name.toLowerCase().indexOf(q) !== -1 || (it.comment || "").toLowerCase().indexOf(q) !== -1;
        });
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;

        const sep = item.action.indexOf(":");
        if (sep < 0)
            return;

        // sh -c 를 안 끼운다. 값에 공백이나 따옴표가 없다는 보장이 없고, argv 로
        // 바로 넘기면 인용을 생각할 필요가 없다.
        applier.label = item.name;
        applier.command = [root.menu, item.action.substring(0, sep), item.action.substring(sep + 1)];
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
