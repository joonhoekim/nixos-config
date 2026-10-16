{ pkgs, subline, ... }:

# nautice(알림 CLI) 의 음성 엔진. nautice 본체는 선언하지 않는다 — 자주 바뀌는
# 도구라 릴리즈 인스톨러로 ~/.local/bin 에 깔고 `nautice update` 로 올린다.
# 여기는 그쪽이 PATH 와 환경에서 찾아 쓰는 것만 둔다.
#
# NAUTICE_TTS_CMD_<LANG> 은 `sh -c` 로 도는 명령이고, 텍스트를 stdin 으로 받아
# $NAUTICE_TTS_OUT 에 WAV 를 쓴다 (nautice 의 docs/cli.md, "TTS command").
# 명령을 변수에 바로 적지 않고 스크립트로 감싼 이유: home-manager 는
# sessionVariables 를 `export X="…"` 로 이스케이프 없이 쓴다
# (modules/lib/shell.nix 의 `export`). README 레시피를 그대로 넣으면 로그인할 때
# $(awk …) 와 $NAUTICE_TTS_RATE 가 풀려 `--rate -100%` 에 빈 출력 경로가 되고,
# 명령이 매번 실패해 espeak-ng 로 조용히 떨어진다. 스토어 경로 하나는 풀릴 것이
# 없다.
let
  # 오프라인 Supertonic 3 (subline 의 crates/voice, CPU 백엔드). 모델과
  # onnxruntime 이 클로저에 들어 있어 네트워크가 필요 없다. mn56 에서 4초짜리
  # 알림 한 문장이 프로세스 시작부터 약 1.2 s, 그중 세션 로드가 0.5 s.
  subline-tts = subline.packages.${pkgs.stdenv.hostPlatform.system}.subline-tts;

  edge-tts = pkgs.writeShellScript "nautice-edge-tts" ''
    set -o pipefail
    rate=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%+d%%\", ($NAUTICE_TTS_RATE - 1) * 100 }")
    ${pkgs.python3Packages.edge-tts}/bin/edge-tts -v "$1" --rate "$rate" \
        -f /dev/stdin --write-media /dev/stdout \
      | ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error -i pipe: -y "$NAUTICE_TTS_OUT"
  '';

  # 로컬이 먼저, 실패하면 edge-tts. stdin 은 한 번만 읽히므로 파일로 받아 둔다.
  # NAUTICE_TTS_VOICE 는 subline-tts 의 보이스(F1–F5, M1–M5)이고, edge-tts 는
  # 인자로 받은 고정 보이스를 쓴다.
  tts = pkgs.writeShellScript "nautice-tts" ''
    text=$(${pkgs.coreutils}/bin/mktemp) || exit 1
    trap '${pkgs.coreutils}/bin/rm -f "$text"' EXIT
    ${pkgs.coreutils}/bin/cat > "$text"
    ${subline-tts}/bin/subline-tts < "$text" && exit 0
    ${edge-tts} "$1" < "$text"
  '';
in
{
  # 둘 다 실패하면 nautice 가 내장 엔진(espeak-ng)으로 말하므로, 그것도 PATH 에
  # 있어야 한다.
  home.packages = [ pkgs.espeak-ng ];

  # 언어는 nautice 가 문구의 문자로 가린다. EN 이 있는 이유: `nautice call` 의
  # 기본 문구("Your agent is calling")가 영어다.
  home.sessionVariables = {
    NAUTICE_TTS_CMD_KO = "${tts} ko-KR-SunHiNeural";
    NAUTICE_TTS_CMD_EN = "${tts} en-US-AvaNeural";
  };
}
