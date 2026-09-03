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

    // ── 글자색 이름을 on* 으로 지으면 안 된다 ─────────────────────────────
    // `readonly property color onSurface: pick(...)` 는 같은 객체에 `surface` 가
    // 있으면 속성이 아니라 **시그널 핸들러로 먹힌다**. 바인딩이 통째로 사라지고
    // 값은 기본값인 검정(#000000)으로 남는데, 오류도 경고도 안 난다 — 값 대신
    // 함수 호출을 쓰면 파서가 "실행할 스크립트"로 보고 통과시키기 때문이다.
    // (리터럴을 쓰면 그 자리에서 "Cannot assign a value to a signal" 로 터진다.)
    //
    // 형제 속성이 있는 이름만 걸린다 — `onSurfaceVariant` 는 `surfaceVariant` 가
    // 없어서 멀쩡했고 `onSurface`·`onPrimary` 만 검게 나왔다. 밝은 배경에서는
    // 검정 글씨가 그럴듯해 보여서, 다크 모드에서 #101418 위의 검정 글씨로만
    // 드러난다. 그래서 셋 다 DMS 와 같은 `*Text` 꼴로 쓴다
    // (Common/Theme.qml 의 surfaceText · surfaceVariantText · primaryText).
    readonly property color surface: pick("surface", light ? "#faf9fd" : "#101418")
    readonly property color surfaceText: pick("on_surface", light ? "#1a1c1e" : "#e0e2e8")
    readonly property color surfaceVariantText: pick("on_surface_variant", light ? "#43474e" : "#c3c6cf")
    readonly property color outline: pick("outline", light ? "#73777f" : "#8d9199")
    readonly property color primary: pick("primary", light ? "#1976d2" : "#42a5f5")
    readonly property color primaryText: pick("on_primary", light ? "#ffffff" : "#00325a")
    readonly property color error: pick("error", light ? "#ba1a1a" : "#f2b8b5")

    // ── 카드는 배경과 갈려야 한다 ─────────────────────────────────────────
    // matugen 팔레트는 surface 와 surface_container 를 같은 값으로 준다 — 다크는
    // 둘 다 #101418, 라이트는 둘 다 #f7f9ff. 카드 배경을 surface_container 로
    // 잡으면 창 배경과 정확히 같은 색이 되고, 테두리도 그림자도 없는 이 창에서는
    // 카드가 통째로 안 보인다.
    //
    // 그래서 한 단 위인 surface_container_high 부터 쓴다(다크 #1d2024, 배경과
    // HSL 밝기 차 0.049). 그 값마저 붙어 오는 팔레트를 대비해 차가 0.035 아래면
    // 한 번 더 든다 — 이 창은 화면 셰이더를 통과해 그려져서 그보다 좁은 차는
    // 블룸에 먹힌다.
    function lift(c, base) {
        if (Math.abs(c.hslLightness - base.hslLightness) >= 0.035)
            return c;
        return light ? Qt.darker(base, 1.06) : Qt.lighter(base, 1.6);
    }

    readonly property color surfaceCard: lift(pick("surface_container_high", light ? "#e9e7ec" : "#1d2024"), surface)
    readonly property color surfaceRaised: lift(pick("surface_container_highest", light ? "#e3e2e6" : "#282a2f"), surfaceCard)

    // 카드 테두리. 밝기 차만으로는 셰이더를 통과하면서 뭉개져서, 윤곽선을 같이 준다.
    readonly property color line: fade(outline, light ? 0.28 : 0.22)

    // 줄 사이를 가르는 선. 테두리보다 옅다.
    readonly property color divider: fade(outline, light ? 0.16 : 0.12)

    // 못 누르는 것의 글자. `opacity` 를 통째로 내리는 대신 잉크만 죽인다 — 통째로
    // 내리면 배경까지 같이 사라져서 단추가 있었다는 것 자체가 안 보인다.
    readonly property color disabledText: fade(surfaceVariantText, 0.42)

    // 마우스 상태. 어두운 쪽에서는 흰 기운을, 밝은 쪽에서는 검은 기운을 얹는다.
    readonly property color hoverWash: fade(surfaceText, light ? 0.06 : 0.08)
    readonly property color pressWash: fade(surfaceText, light ? 0.12 : 0.14)

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
