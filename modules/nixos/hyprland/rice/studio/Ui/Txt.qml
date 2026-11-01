// DMS 의 StyledText 대신(별도 프로세스라 못 가져온다).
// renderType 고정이 요점이다 — 서브픽셀 AA 가 셰이더 색수차와 겹쳐 글자 가장자리에 색이 낀다.

import QtQuick
import qs.Rice

Text {
    color: Theme.surfaceText
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontM
    renderType: Text.QtRendering
    textFormat: Text.PlainText
    elide: Text.ElideRight
}
