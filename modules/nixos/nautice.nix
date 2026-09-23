{ pkgs, ... }:

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
  edge-tts = pkgs.writeShellScript "nautice-edge-tts" ''
    set -o pipefail
    rate=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%+d%%\", ($NAUTICE_TTS_RATE - 1) * 100 }")
    ${pkgs.python3Packages.edge-tts}/bin/edge-tts -v "$1" --rate "$rate" \
        -f /dev/stdin --write-media /dev/stdout \
      | ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error -i pipe: -y "$NAUTICE_TTS_OUT"
  '';
in
{
  # edge-tts 는 온라인이다. 실패하면 nautice 가 내장 엔진(espeak-ng)으로
  # 말하므로, 오프라인에서도 소리가 나려면 이게 PATH 에 있어야 한다.
  home.packages = [ pkgs.espeak-ng ];

  # 언어는 nautice 가 문구의 문자로 가린다. EN 이 있는 이유: `nautice call` 의
  # 기본 문구("Your agent is calling")가 영어다.
  home.sessionVariables = {
    NAUTICE_TTS_CMD_KO = "${edge-tts} ko-KR-SunHiNeural";
    NAUTICE_TTS_CMD_EN = "${edge-tts} en-US-AvaNeural";
  };
}
