pragma Singleton

// 별도 프로세스라 DMS 의 `qs.Common` Theme 을 못 쓴다. 대신 같은 dms-colors.json 과 SessionData 의
// isLightMode 를 감시한다(Common/Theme.qml 의 dynamicColorsFileView) — 팔레트를 베끼면 그 순간 어긋난다.
// 둘 다 없으면(니리, DMS 없음) 아래 기본값으로 돈다.

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string cacheDir: {
        const s = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString();
        return s.replace(/^file:\/\//, "");
    }
    readonly property string stateDir: {
        const s = StandardPaths.writableLocation(StandardPaths.GenericStateLocation).toString();
        return s.replace(/^file:\/\//, "");
    }

    property var palette: ({})
    property bool light: false

    // matugen 이름은 snake_case 다(`surface_container_high`). 여기서 한 번만 접고,
    // 창 쪽에서는 카멜케이스 이름만 본다.
    function pick(name, fallback) {
        const set = palette[light ? "light" : "dark"] || {};
        const v = set[name];
        return v ? v : fallback;
    }

    // 글자색을 on* 으로 지으면 형제 `surface` 가 있을 때 시그널 핸들러로 먹혀 오류 없이 검정이 된다.
    // 그래서 DMS 와 같은 `*Text` 꼴로 쓴다(Common/Theme.qml 의 surfaceText 등).
    readonly property color surface: pick("surface", light ? "#faf9fd" : "#101418")
    readonly property color surfaceText: pick("on_surface", light ? "#1a1c1e" : "#e0e2e8")
    readonly property color surfaceVariantText: pick("on_surface_variant", light ? "#43474e" : "#c3c6cf")
    readonly property color outline: pick("outline", light ? "#73777f" : "#8d9199")
    readonly property color primary: pick("primary", light ? "#1976d2" : "#42a5f5")
    readonly property color primaryText: pick("on_primary", light ? "#ffffff" : "#00325a")
    readonly property color error: pick("error", light ? "#ba1a1a" : "#f2b8b5")

    // matugen 은 surface 와 surface_container 를 같은 값으로 줘서(다크 #101418) 카드가 안 보인다.
    // surface_container_high(다크 #1d2024, HSL 밝기 차 0.049)부터 쓰고, 차가 0.035 아래면 한 단 더 든다
    // — 셰이더를 통과하면 그보다 좁은 차는 블룸에 먹힌다.
    function lift(c, base) {
        if (Math.abs(c.hslLightness - base.hslLightness) >= 0.035)
            return c;
        return light ? Qt.darker(base, 1.06) : Qt.lighter(base, 1.6);
    }

    readonly property color surfaceCard: lift(pick("surface_container_high", light ? "#e9e7ec" : "#1d2024"), surface)
    readonly property color surfaceRaised: lift(pick("surface_container_highest", light ? "#e3e2e6" : "#282a2f"), surfaceCard)

    // 카드 테두리. 밝기 차만으로는 셰이더를 통과하면서 뭉개져서, 윤곽선을 같이 준다.
    readonly property color line: fade(outline, light ? 0.28 : 0.22)

    readonly property color divider: fade(outline, light ? 0.16 : 0.12)

    // opacity 를 통째로 내리면 배경까지 사라져 단추가 있었다는 것도 안 보인다.
    readonly property color disabledText: fade(surfaceVariantText, 0.42)

    readonly property color hoverWash: fade(surfaceText, light ? 0.06 : 0.08)
    readonly property color pressWash: fade(surfaceText, light ? 0.12 : 0.14)

    // opacity 로 하면 안의 글자까지 흐려진다.
    function fade(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 12
    readonly property int spacingL: 16

    readonly property int radius: 12
    readonly property int radiusS: 8

    // 누르는 것의 최소 높이. 체인 재정렬 화살표까지 이 크기로 맞춘다.
    readonly property int hit: 28

    readonly property int durFast: 90
    readonly property int durBase: 140

    readonly property int fontS: 12
    readonly property int fontM: 14
    readonly property int fontL: 16
    readonly property int fontXL: 20

    // DMS 가 번들로 들고 오는 것과 같은 글꼴. 없으면 Qt 가 알아서 대체한다.
    readonly property string fontFamily: "Inter Variable"
    readonly property string monoFamily: "Fira Code"

    FileView {
        path: root.cacheDir + "/DankMaterialShell/dms-colors.json"
        watchChanges: true
        blockLoading: false
        onLoaded: {
            try {
                root.palette = JSON.parse(text()).colors || {};
            } catch (e) {
                root.palette = {};
            }
        }
        onFileChanged: reload()
    }

    FileView {
        path: root.stateDir + "/DankMaterialShell/session.json"
        watchChanges: true
        blockLoading: false
        onLoaded: {
            try {
                root.light = JSON.parse(text()).isLightMode === true;
            } catch (e) {}
        }
        onFileChanged: reload()
    }
}
