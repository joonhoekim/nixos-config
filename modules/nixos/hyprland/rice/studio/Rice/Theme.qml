pragma Singleton

// 스튜디오의 색·간격·글꼴. DMS 안이 아니라 별도 프로세스라 `qs.Common` 의 Theme 을
// 못 가져온다 — 그건 DMS 설정의 루트 모듈에 매인 싱글턴이다.
//
// ── 그래도 색은 갈라지지 않는다 ───────────────────────────────────────────
// DMS 는 matugen 이 낸 팔레트를 파일 하나에 두고 FileView 로 감시한다
// (Common/Theme.qml 의 dynamicColorsFileView — `<캐시>/DankMaterialShell/
// dms-colors.json`). 우리도 같은 파일을 감시하면 벽지를 바꿔서 색이 다시 뽑히는
// 순간 이 창도 같이 따라간다. **팔레트를 베껴 오면 그 순간부터 어긋난다.**
//
// 밝기 모드는 팔레트 파일이 아니라 세션 상태에 있다(Common/SessionData.qml 의
// isLightMode). 그래서 파일이 둘이다.
//
// 둘 다 없으면 아래 기본값으로 돈다. 니리 세션이나 DMS 를 안 띄운 상태에서
// 스튜디오만 열어 보는 경우이고, 그때 창이 안 뜨는 것보다는 색이 좀 다른 편이 낫다.

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

    readonly property color surface: pick("surface", light ? "#faf9fd" : "#101418")
    readonly property color surfaceContainer: pick("surface_container", light ? "#efedf1" : "#191c20")
    readonly property color surfaceContainerHigh: pick("surface_container_high", light ? "#e9e7ec" : "#1d2024")
    readonly property color surfaceContainerHighest: pick("surface_container_highest", light ? "#e3e2e6" : "#282a2f")
    readonly property color onSurface: pick("on_surface", light ? "#1a1c1e" : "#e0e2e8")
    readonly property color onSurfaceVariant: pick("on_surface_variant", light ? "#43474e" : "#c3c6cf")
    readonly property color outline: pick("outline", light ? "#73777f" : "#8d9199")
    readonly property color primary: pick("primary", light ? "#1976d2" : "#42a5f5")
    readonly property color onPrimary: pick("on_primary", light ? "#ffffff" : "#00325a")
    readonly property color error: pick("error", light ? "#ba1a1a" : "#f2b8b5")

    // 흐리게. `opacity` 로 하면 그 안의 글자까지 같이 흐려져서 안 읽힌다.
    function fade(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 12
    readonly property int spacingL: 16

    readonly property int radius: 12
    readonly property int radiusS: 8

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
