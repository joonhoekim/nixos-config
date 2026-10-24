"""지금 깔린 macOS 배경화면의 파일 경로를 출력한다. 못 찾으면 exit 1.

쓰는 법: wallpaper-path.py <Index.plist>

apps/rice/colors(인자 없이 불렀을 때)와 modules/darwin/rice/default.nix 의
wal-watch 에이전트가 같이 쓴다.

osascript 로 System Events 에 묻지 않는 이유: Automation 권한이 필요한데
LaunchAgent 에게는 그 권한 창이 뜨지 않아서, 거부도 아닌 빈 문자열만 돌아오고
로그도 안 남는다. plist 는 자기 홈의 파일이라 권한이 필요 없다.

경로는 중첩된 바이너리 plist 안에 있어서 plutil 로 한 겹 벗겨도 base64 만
나온다. 그래서 바이트로 읽고 file:// URL 을 찾는다. URL 은 퍼센트 인코딩
(%20, 한글은 %ED%95%9C 꼴)이라 풀어야 한다. macOS 기본 벽지(동적 벽지 등)는
파일이 아니라 URL 이 없다.
"""

import re
import sys
import urllib.parse

try:
    raw = open(sys.argv[1], "rb").read()
except OSError:
    sys.exit(1)
# [!-~] = 공백을 뺀 출력 가능 ASCII. URL 안의 공백은 %20 이므로 이걸로 끝을 잡는다.
m = re.search(rb"file:///[!-~]+", raw)
if not m:
    sys.exit(1)
url = urllib.parse.unquote(m.group().decode("utf-8", "replace"))
print(url[len("file://"):])
