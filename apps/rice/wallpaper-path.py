"""macOS 배경화면 파일 경로를 출력한다(못 찾으면 exit 1). 쓰는 법: wallpaper-path.py <Index.plist>

osascript 는 LaunchAgent 에서 Automation 권한 창 없이 빈 문자열만 조용히 돌려줘서 plist 를 직접 읽는다.
경로는 중첩 바이너리 plist 안의 퍼센트 인코딩된 file:// URL 이다. 기본(동적) 벽지는 URL 이 없다.
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
