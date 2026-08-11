// 글자 한 줄. DMS 의 StyledText 자리를 대신한다 — 그건 DMS 루트 모듈에 매여 있어서
// 별도 프로세스인 여기서는 못 가져온다(../Rice/Theme.qml 머리말).
//
// 기본값만 바꾼 Text 다. renderType 을 고정해 두는 것이 요점인데, 이 창은 화면
// 셰이더를 통과해 그려지므로 서브픽셀 안티에일리어싱이 색수차와 겹쳐서 글자
// 가장자리에 색이 낀다. 조절하는 화면이 곧 표본인 창에서 그건 셰이더 탓인지
// 렌더링 탓인지 구별이 안 되는 종류의 흠이다.

import QtQuick
import qs.Rice

Text {
    color: Theme.onSurface
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontM
    renderType: Text.QtRendering
    textFormat: Text.PlainText
    elide: Text.ElideRight
}
