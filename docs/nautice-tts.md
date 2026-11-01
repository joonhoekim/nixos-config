# nautice 음성 엔진

nautice 는 에이전트가 사람을 부를 때 소리로 알리는 CLI 다(`nautice call` 등). 문구를 말하는 TTS 엔진은 nautice 가
환경 변수로 찾는다. `modules/nixos/nautice.nix` 는 그 엔진과 변수만 둔다.

- **nautice 본체는 선언하지 않는다.** 자주 바뀌어 릴리즈 인스톨러로 `~/.local/bin` 에 깔고 `nautice update` 로 올린다.
  모듈은 nautice 가 PATH 와 환경에서 찾는 것만 둔다.
- **`NAUTICE_TTS_CMD_<LANG>`** 은 `sh -c` 로 도는 명령이고, 텍스트를 stdin 으로 받아 `$NAUTICE_TTS_OUT` 에 WAV 를 쓴다
  (nautice 의 docs/cli.md, "TTS command"). 언어는 nautice 가 문구의 문자로 가린다. EN 을 두는 건 `nautice call` 의 기본
  문구("Your agent is calling")가 영어라서다.
- **스크립트로 감싼 이유.** HM 은 sessionVariables 를 `export X="…"` 로 이스케이프 없이 쓴다(modules/lib/shell.nix 의
  `export`). README 레시피를 그대로 넣으면 로그인 때 `$(awk …)` 와 `$NAUTICE_TTS_RATE` 가 풀려 `--rate -100%` 에 빈 출력
  경로가 되고, 명령이 매번 실패해 espeak-ng 로 조용히 떨어진다. 스토어 경로 하나는 풀릴 게 없다.
- **로컬 엔진**은 오프라인 Supertonic 3(subline 의 crates/voice, CPU 백엔드)다. 모델과 onnxruntime 이 클로저에 있어
  네트워크가 필요 없다. mn56 에서 4초짜리 알림 한 문장이 프로세스 시작부터 약 1.2 s, 그중 세션 로드 0.5 s.
- **순서**: 로컬 먼저, 실패하면 edge-tts(Microsoft Edge 의 온라인 TTS, 인자로 받은 고정 보이스). stdin 은 한 번만
  읽히므로 파일로 받아 둔다. NAUTICE_TTS_VOICE 는 subline-tts 의 보이스(F1–F5, M1–M5). 둘 다 실패하면 nautice 내장
  espeak-ng 가 말하므로 그것도 PATH 에 둔다.
