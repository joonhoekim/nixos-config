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

    // ── 항목 만들기 ───────────────────────────────────────────────────────
    // 값 목록은 접어 둔다. off / crt / crt-motion 을 한 줄씩 늘어놓으면 목록의
    // 대부분이 "지금 안 고를 것"으로 채워지고, 정작 자주 누르는 것(값 조절, 다시
    // 읽기)이 그 사이에 묻힌다. 그래서 축 하나 = "고르기" 한 줄이고, 지금 걸린
    // 것과 후보는 그 줄의 부제로 보인다.
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
                out.push({
                    name: axis.label + " 고르기",
                    icon: icon,
                    comment: (axis.current ? "지금 " + axis.current + " · " : "") + values.join(" / "),
                    action: "drill:" + axis.id,
                    keywords: [axis.id],
                    categories: ["Rice"]
                });
            }
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
    function leafItems(axis) {
        const out = [];
        const icon = "material:" + (axis.icon || "tune");
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
                keywords: [axis.id],
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
        // 미리 쳐 준 채로 다시 열린다(executeItem 의 drill:).
        for (var i = 0; i < axes.length; i++) {
            if (q === axes[i].id || q.indexOf(axes[i].id + " ") === 0)
                return leafItems(axes[i]);
        }

        if (q === "")
            return topItems();

        // 검색은 접힌 것을 뚫는다. `:crt` 로 셰이더와 터미널의 crt 에 바로 닿는
        // 것이 접기의 대가가 되어서는 안 된다.
        var all = topItems();
        for (var j = 0; j < axes.length; j++)
            all = all.concat(leafItems(axes[j]));

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
