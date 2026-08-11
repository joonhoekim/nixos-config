// 켜고 끄는 것. Slide 와 같은 이유로 Qt Quick Controls 를 안 쓴다 — 이 창은
// DMS 와 별도 프로세스라 Material 스타일 환경이 없다.
//
// `checked` 는 밖에서 들어오기만 하고 여기서 안 고친다. 눌리면 뜻만 알리고,
// 값을 바꾸는 것은 뒤판이 성공한 뒤 목록이 다시 들어오면서 일어난다 — 스크립트가
// 거절한 값이 화면에만 켜져 있는 상태를 안 만든다.

import QtQuick
import qs.Rice

Item {
    id: root

    property bool checked: false
    signal toggled(bool v)

    implicitWidth: 38
    implicitHeight: 22

    // 꺼진 쪽에도 테두리와 채운 손잡이를 준다. 트랙 색만으로 구분하면 카드
    // 배경(surfaceContainer)과 거의 안 갈리고, 화면 셰이더까지 걸린 상태에서는
    // 아예 안 보인다 — 스위치가 있다는 것 자체를 놓친다.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 1
        border.color: Theme.fade(Theme.outline, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.onPrimary : Theme.fade(Theme.onSurface, 0.55)

            Behavior on x {
                NumberAnimation {
                    duration: 90
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
