//@ pragma UseQApplication
//@ pragma AppId rice-studio

// 라이싱 스튜디오 — 화면을 덮는 것들을 고르고 값을 맞추는 창. 탭이 둘이다:
//
//   셰이더   화면 셰이더를 고르고, 겹치고, 칸마다 손잡이를 맞춘다 (ShaderTab.qml)
//   장식     하이프랜드의 투명도·흐리게·어둡게·그림자          (DecorTab.qml)
//
// 여는 법:  apps/rice-studio   또는 DankBar 의 팔레트 조각
//
// ── 왜 DMS 밖인가 ─────────────────────────────────────────────────────────
// 원래 셰이더는 DMS 플러그인 둘이 나눠 하고 있었다 — 런처에서 고르고, 설정 모달의
// 슬라이더로 값을 맞췄다. 축이 하나 늘어난 게 아니라 **축의 성질이 달라진** 것이
// 갈라선 이유다. 다른 라이싱 축은 "값 하나 고르기"인데 셰이더는 여러 장을 순서대로
// 쌓고, 그 조합마다 비용이 곱으로 늘고, 칸마다 손잡이가 따로 있다. 그걸 런처의
// 한 줄짜리 항목 계약에 우겨넣다 보니 플러그인이 갈래 이름·탭 곱셈·체인 동사를
// 전부 알게 됐고, "이 파일은 축이 뭔지 모른다"고 적어 둔 자기 머리말과 어긋났다.
//
// 그래서 셰이더만 이 창으로 나왔다. DMS 에 남은 것은 여는 단추 하나와, 화면이
// 망가졌을 때 쓰는 탈출구(off · 다음 것)다 — 셰이더가 화면을 못 알아보게 만들면
// **이 창도 같은 유리 뒤에 있어서** 여기서 끄는 길만 두면 안 된다.
//
// ── 장식 탭은 그 기준의 예외다 ────────────────────────────────────────────
// 투명도는 위 기준대로면 "값 하나 고르기"라 런처 쪽 일이다. 그래도 여기 있는 건
// 셰이더와 **같은 픽셀을 두고 다투기** 때문이다 — 블러 passes 와 셰이더 탭 수가
// 같은 GPU 를 나눠 쓰고, blur:xray 는 셰이더가 그린 결과와 겹친다. 두 값을 다른
// 창에서 만지면 그 다툼이 안 보인다. 자세한 것은 DecorTab.qml 머리말.
//
// DMS 설정에도 하이프랜드 탭이 있지만 거기서 다루는 것은 간격·둥글기·보더뿐이고
// (Modules/Settings/CompositorLayoutTab.qml), 그 값들은 여기서 안 다룬다.
//
// ── 값은 여기 없다 ────────────────────────────────────────────────────────
// 목록도, 탭 수도, 무엇을 더할 수 있는지도 Rice/ 아래 싱글턴들이 셸에게 물어서
// 가져온다. 특히 곱 한도는 apps/rice-chain 하나만 안다 — 여기서 다시 세면 규칙이
// 두 벌이 되고, 한쪽만 고친 날 목록이 거짓말을 한다.
//
// ── 조절하는 화면이 곧 표본이다 ───────────────────────────────────────────
// 화면 셰이더는 창을 안 가린다. 이 창도 그 유리 뒤에 그려지므로 글씨 대비와 블룸을
// 바로 그 위에서 본다. 장식 탭은 한 걸음 더 간다 — 투명도를 내리면 이 창 자신이
// 반투명해진다.
//
// 그래서 화면에 쓰는 색은 Rice/Theme.qml 한 곳에서만 나온다. 특히 카드와 창
// 배경을 가르는 일이 팔레트만으로는 안 되는 사정이 거기 적혀 있다.

import QtQuick
import Quickshell
import qs.Rice
import qs.Ui

ShellRoot {
    id: rootScope

    // 창을 닫으면 프로세스도 나간다.
    //
    // FloatingWindow 를 닫아도 visible = false 가 될 뿐 ShellRoot 는 계속 돈다.
    // 그러면 창 없는 quickshell 이 남고, 그 뒤로는 바 조각을 눌러도
    // apps/rice-studio 의 `-n` 이 "이미 같은 설정이 돈다"며 즉시 나간다 — 창은
    // 다시 안 뜨고 로그도 안 남아서 pkill 말고는 여는 길이 없다.
    //
    // quickshell 0.3.0 에는 Quickshell.quit() 이 없고 lastWindowClosed 시그널만
    // 있다. 그래서 Qt.quit() 을 쓴다.
    Connections {
        target: Quickshell
        function onLastWindowClosed() {
            Qt.quit();
        }
    }

    FloatingWindow {
        id: win

        title: "라이싱 스튜디오"
        implicitWidth: 1080
        implicitHeight: 740
        // 손잡이 한 줄이 이름·값·슬라이더·되돌리기를 가로로 늘어놓는다
        // (Ui/KnobRow.qml). 그보다 좁으면 슬라이더가 백 픽셀 아래로 눌려서
        // 끌 수는 있어도 맞출 수는 없는 폭이 된다.
        minimumSize: Qt.size(880, 560)
        color: Theme.surface

        // 0 = 셰이더, 1 = 장식
        property int tab: 0

        // ── 토스트 ────────────────────────────────────────────────────────
        // 실패는 조용히 지나가면 안 된다. 특히 체인 한도 초과는 "눌렀는데 아무 일도
        // 안 일어났다"로 보이기 딱 좋다 — 이유가 곱셈이라 눈으로는 안 보인다.
        property string toast: ""
        property bool toastBad: false

        function say(msg, bad) {
            toast = msg;
            toastBad = bad === true;
            // 스크립트가 낸 거절 이유는 한 줄짜리부터 두 줄짜리까지 길이가 제각각인데,
            // 시간이 고정이면 긴 것은 다 읽기 전에 사라진다.
            toastTimer.interval = Math.max(3200, Math.min(9000, 1600 + msg.length * 90));
            toastTimer.restart();
        }

        Timer {
            id: toastTimer
            interval: 4200
            onTriggered: win.toast = ""
        }

        Connections {
            target: Shaders
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        Connections {
            target: Knobs
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        // 장식 값이 거절당하는 것은 다른 탭을 보고 있을 때도 일어난다(되돌리기가
        // 도는 중에 창을 옮기는 식). 토스트가 창 것이라 탭과 무관하게 뜬다.
        Connections {
            target: Decor
            function onFailed(label, message) {
                win.say(label + " — " + message, true);
            }
        }

        // 셰이더를 갈아 끼우면 손잡이 대상의 순서(몇째 칸인지)가 바뀐다.
        Connections {
            target: Shaders
            function onChanged() {
                Knobs.loadTargets();
            }
        }

        // 탭 전환에 Esc 나 맨 숫자를 안 쓴다 — 저장 이름을 치는 중에 삼켜지거나,
        // 반대로 글자가 탭 전환으로 새는 자리가 생긴다.
        Shortcut {
            sequences: ["Ctrl+1"]
            onActivated: win.tab = 0
        }

        Shortcut {
            sequences: ["Ctrl+2"]
            onActivated: win.tab = 1
        }

        Shortcut {
            sequences: ["Ctrl+W"]
            onActivated: Qt.quit()
        }

        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // ── 탭 ────────────────────────────────────────────────────
                // 둘뿐이라 세그먼트 하나로 충분하다. 칩 모양은 KnobPanel 의 대상
                // 고르기와 같은 것을 쓴다 — 같은 창에서 "고르는 것"이 두 가지
                // 모양이면 어느 쪽이 지금 상태인지 매번 다시 배워야 한다.
                Panel {
                    width: parent.width
                    height: 44
                    radius: Theme.radiusS

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Repeater {
                            model: 2

                            Chip {
                                required property int index

                                // 장식은 기본값에서 벗어난 개수를 달고 다닌다.
                                // 셰이더 탭을 보고 있어도 저쪽을 건드려 뒀다는
                                // 사실이 보여야 한다.
                                text: index === 0 ? "셰이더" : ("장식" + (Decor.dirtyCount > 0 ? " · " + Decor.dirtyCount : ""))
                                picked: win.tab === index
                                onClicked: win.tab = index
                            }
                        }
                    }
                }

                // ── 본문 ──────────────────────────────────────────────────
                // 탭을 Column 에 나란히 두지 않는다. 둘 다 "남은 높이"를 요구해서
                // 안 보이는 쪽의 y 가 엉키기 때문이다. 자리는 이 Item 하나가 잡고,
                // 탭은 거기 겹쳐 놓은 뒤 보이고 말고만 정한다.
                Item {
                    width: parent.width
                    height: parent.height - y

                    ShaderTab {
                        anchors.fill: parent
                        visible: win.tab === 0
                        onNote: msg => win.say(msg)
                    }

                    DecorTab {
                        anchors.fill: parent
                        visible: win.tab === 1
                    }
                }
            }

            // 토스트는 창 위에 겹친다. 자리를 차지하면 뜰 때마다 아래 내용이 밀린다.
            Rectangle {
                id: toast

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                visible: win.toast !== ""
                width: Math.min(parent.width - Theme.spacingL * 2, toastText.implicitWidth + Theme.spacingL * 2)
                height: toastText.implicitHeight + Theme.spacingM * 2
                radius: Theme.radiusS
                color: win.toastBad ? Theme.fade(Theme.error, 0.92) : Theme.surfaceRaised
                border.width: 1
                border.color: Theme.line

                Txt {
                    id: toastText
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    text: win.toast
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    font.pixelSize: Theme.fontS
                    color: win.toastBad ? Theme.surface : Theme.surfaceText
                }

                // 손잡이 목록의 아래쪽을 가리므로, 다 읽었으면 눌러서 치울 수 있다.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        toastTimer.stop();
                        win.toast = "";
                    }
                }
            }
        }
    }
}
