# 일상 편의 도구 (개발 무관 QoL)

개발 워크플로와 무관하게, 일상에서 파일·미디어·문서를 다룰 때 꺼내 쓰는 도구들.
선언은 `modules/shared/packages.nix`의 "Everyday convenience tools" 절에 있다.
기준선은 이미 있던 `yt-dlp`/`ffmpeg`/`imagemagick`/`poppler-utils` — 이 문서의
도구들은 전부 그 곁의 빈틈을 채우는 짝이다.

---

## 무엇이 있나

| 도구 | 한 줄 | 짝 |
|---|---|---|
| `gallery-dl` | yt-dlp의 이미지판 (트위터·픽시브·…) | yt-dlp |
| `aria2` | 멀티커넥션 다운로더 | yt-dlp의 가속기 |
| `streamlink` | 라이브 스트림 → mpv | yt-dlp가 못 하는 실시간 |
| `mediainfo` | 코덱·비트레이트·해상도 상세 | ffmpeg 전 진단 |
| `exiftool` | 메타데이터 확인·제거 | 사진 공유 전 |
| `pngquant` / `jpegoptim` | 이미지 용량 압축 | imagemagick 후처리 |
| `gifsicle` / `gifski` | GIF 최적화 / 비디오→GIF | ffmpeg 후처리 |
| `pandoc` | 문서 포맷 만능 변환 | — |
| `qpdf` | PDF 암호·병합·분할 | poppler가 못 하는 암호화 |
| `ocrmypdf` + `tesseract`(kor) | 스캔 PDF에 텍스트 레이어 | poppler `pdftotext` 앞단 |
| `rclone` | 클라우드 스토리지 sync/mount | — |
| `croc` | 기기 간 파일 전송 | AirDrop 대용 |
| `unar` | cp949 zip 파일명 안 깨는 압축 해제 | unzip/ouch의 함정 회피 |
| `zbar` | QR 디코드 (`zbarimg`) | qrencode의 반대 방향 |
| `speedtest-cli` | 회선 속도 측정 | — |
| `monolith` | 웹페이지 → 단일 HTML 아카이브 | — |

---

## 다운로드 — yt-dlp 곁의 세 조각

```sh
# yt-dlp에 aria2를 물리면 대용량에서 체감 가속
yt-dlp --downloader aria2c --downloader-args 'aria2c:-x16 -s16' <url>

# 이미지 갤러리는 gallery-dl 담당 (사이트별 추출기는 yt-dlp와 같은 구조)
gallery-dl <gallery-url>

# 라이브는 streamlink — 끝난 방송(VOD)은 yt-dlp, 진행 중이면 이쪽
streamlink <live-url> best          # 기본 플레이어(mpv)로 바로 재생
```

`mediainfo <file>`은 "이 파일 왜 이래"의 첫 수 — ffmpeg로 손대기 전에
컨테이너·코덱·트랙 구성을 먼저 본다.

## 이미지 — 공유 전 위생과 용량

```sh
exiftool -gps:all= -overwrite_original photo.jpg   # GPS만 제거
exiftool -all= -overwrite_original photo.jpg       # 메타데이터 전부 제거

pngquant --ext .png --force screenshot.png         # PNG 손실 압축 (대개 -60~70%)
jpegoptim -m85 photo.jpg                           # JPEG 품질 85로 재압축

# 비디오→GIF는 ffmpeg 단독보다 gifski 품질이 좋다 (2-pass 팔레트)
ffmpeg -i in.mp4 -r 15 frame%04d.png && gifski -o out.gif frame*.png
gifsicle -O3 --lossy=80 in.gif -o out.gif          # 이미 있는 GIF 용량 줄이기
```

메타데이터 제거는 "공유 전"이 요점이라 [`security-hygiene.md`](security-hygiene.md)의
관심사와 이웃 — 시크릿이 repo로 새는 걸 막듯, 위치정보가 사진으로 새는 걸 막는다.

## 문서 / PDF

```sh
pandoc report.md -o report.docx                    # md → docx (역방향도 동일)
pandoc chapter*.md -o book.epub

qpdf --decrypt --password=1234 locked.pdf out.pdf  # 암호 해제
qpdf --empty --pages a.pdf b.pdf -- merged.pdf     # 병합

ocrmypdf -l kor+eng scan.pdf searchable.pdf        # 스캔본에 텍스트 레이어
```

ocrmypdf는 자체 tesseract를 번들하므로 위 한 줄로 끝난다. 별도로 선언한
`tesseract.override { enableLanguages = ["kor" "eng"]; }`는 이미지에서 텍스트만
바로 뽑을 때용 — `tesseract photo.png stdout -l kor`. 전체 언어팩(~수 GB) 대신
kor/eng만 고정한 것.

## 파일 전송 / 동기화

```sh
rclone config                        # 최초 1회 — 브라우저 OAuth로 리모트 등록
rclone sync ~/docs gdrive:backup/docs --dry-run    # 먼저 dry-run이 습관
rclone mount gdrive: ~/gdrive        # FUSE 마운트 (macOS는 macfuse cask 필요)

croc send file.zip                   # 코드워드 출력 → 상대가 `croc <codeword>`
```

croc는 릴레이 경유라 NAT 양쪽에서도 되고, macOS↔NixOS 간 AirDrop 부재를
메운다. 폰으로 URL만 넘기면 되는 상황은 croc보다
[`mobile.md`](mobile.md)의 qrencode 한 줄이 빠르다.

## 한국 환경 특화

```sh
unar 한글파일.zip                    # cp949 파일명 자동 감지 — 깨지지 않는다
zbarimg screenshot.png               # 이미지 속 QR/바코드 디코드
```

한국 윈도우에서 만든 zip은 파일명이 cp949로 들어 있어 `unzip`/`ouch`로 풀면
`á¤±â”€…` 식으로 깨진다. **압축 해제 기본값을 unar로** 두는 게 정답이고,
그래서 ouch가 이미 있는데도 unar를 따로 선언했다.

## 기타

```sh
speedtest-cli --simple               # ping / down / up 세 줄
monolith https://example.com -o page.html   # CSS·이미지 인라인된 단일 파일
```

monolith는 "나중에 볼 것" 아카이빙용 — 링크가 죽어도 파일은 남는다.

---

## 안 넣은 것과 이유

- **magic-wormhole** — croc와 동일 시나리오. 하나면 충분해서 croc로 통일.
- **ookla speedtest (공식)** — unfree 라이선스. speedtest-cli로 충분.
- **tesseract 전체 언어팩** — 기본 `tesseract`는 전 언어 traineddata를 끌고
  온다. kor/eng override로 고정.
- **syncthing** — 패키지가 아니라 상시 서비스로 켜는 물건. 필요해지면
  호스트별 `services.syncthing`으로 (선언 위치가 다르다).
- **iina / 데스크톱 플레이어류** — GUI는 이 레포 관례대로 casks
  (macOS) / `modules/nixos/packages.nix` (Linux, mpv 선언됨) 담당.

---

## 관련 문서

- [`README.md`](README.md) — 이 디렉토리(도구 안내서)의 인덱스
- [`security-hygiene.md`](security-hygiene.md) — exiftool과 이웃한 "새는 정보 막기" 관점
- [`mobile.md`](mobile.md) — qrencode로 URL을 폰에 넘기는 쪽
