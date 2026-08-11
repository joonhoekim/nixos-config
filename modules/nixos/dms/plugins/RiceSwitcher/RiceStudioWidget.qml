// DankBar 조각 하나. 누르면 라이싱 스튜디오를 띄운다.
//
// ── 이 파일이 하는 일은 그게 전부다 ───────────────────────────────────────
// 셰이더 목록도, 지금 걸린 것도, 탭 수도 모른다. 창이 알아야 할 것은 창이 셸에게
// 직접 묻는다(../../../hyprland/rice/studio). 여기서 상태를 하나라도 들고 있으면
// **DMS 안에 셰이더 지식이 다시 고이기 시작한다** — 갈라 놓은 이유가 정확히
// 그것이었다(apps/rice-studio 머리말).
//
// 그래서 폴링도 안 한다. 바 조각이 지금 걸린 셰이더 이름을 보여 주려면 셸을
// 주기적으로 불러야 하고, 상시로 떠 있는 자리에서 그건 값에 비해 비싸다. 아이콘
// 하나면 "여기를 누르면 그 창이 뜬다"는 말은 다 한 셈이다.
//
// ── popoutContent 를 안 쓴다 ──────────────────────────────────────────────
// PluginComponent 는 조각을 누르면 팝아웃을 여는 길도 준다. 그걸 쓰면 스튜디오가
// 다시 DMS 안으로 들어오는 것이라 안 쓴다. pillClickAction 을 인자 없는 함수로
// 두면 팝아웃 대신 이게 불린다(Modules/Plugins/PluginComponent.qml 의 onClicked —
// `pillClickAction.length === 0` 일 때 좌표 없이 부른다).

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "rice-studio"

    readonly property string studio: (Quickshell.env("HOME") || "") + "/nixos-config/apps/rice-studio"

    // 인자를 안 받는 함수라야 팝아웃 자리 계산을 건너뛰고 그냥 불린다.
    pillClickAction: function () {
        Quickshell.execDetached([root.studio]);
    }

    // 이미 떠 있으면 rice-studio 가 -n 으로 알아서 나간다. 여기서 세어 두면 창을
    // 손으로 닫았을 때 그 숫자가 낡는다.
    horizontalBarPill: Component {
        DankIcon {
            name: "blur_on"
            size: root.iconSize
            color: Theme.surfaceText
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "blur_on"
            size: root.iconSize
            color: Theme.surfaceText
        }
    }
}
