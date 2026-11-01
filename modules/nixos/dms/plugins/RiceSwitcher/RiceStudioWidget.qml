// DankBar 조각 하나. 누르면 라이싱 스튜디오를 띄운다. 상태도 폴링도 없다 — DMS 안에 셰이더 지식을 두지 않는다.
// popoutContent 대신 인자 없는 pillClickAction 이 불린다(Modules/Plugins/PluginComponent.qml 의 onClicked,
// `pillClickAction.length === 0`).

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "rice-studio"

    // RICE_APPS · RICE_REPO · ~/nixos-config 순. 같은 규칙이 hyprland/rice/studio/Rice/*.qml 에도 있다.
    readonly property string apps: Quickshell.env("RICE_APPS")
        || ((Quickshell.env("RICE_REPO")
             || ((Quickshell.env("HOME") || "") + "/nixos-config")) + "/apps/rice")
    readonly property string studio: apps + "/studio"

    pillClickAction: function () {
        Quickshell.execDetached([root.studio]);
    }

    // 이미 떠 있으면 rice-studio 가 -n 으로 나간다. 여기서 세면 손으로 닫았을 때 낡는다.
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
