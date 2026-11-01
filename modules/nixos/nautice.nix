{ pkgs, subline, ... }:

# nautice(알림 CLI)의 음성 엔진만 둔다. 본체는 자주 바뀌어 ~/.local/bin 에 깔고 `nautice update` 로 올린다.
# 명령을 변수에 바로 적지 않고 스크립트로 감싼다 — HM 은 sessionVariables 를 이스케이프 없이 export 해서
# $(awk …) 가 로그인 때 풀리고, 명령이 매번 실패해 espeak-ng 로 조용히 떨어진다(modules/lib/shell.nix).
let
  # 오프라인 Supertonic 3(subline 의 crates/voice, CPU). mn56 에서 4초짜리 문장이 시작부터 약 1.2 s(세션 로드 0.5 s).
  subline-tts = subline.packages.${pkgs.stdenv.hostPlatform.system}.subline-tts;

  edge-tts = pkgs.writeShellScript "nautice-edge-tts" ''
    set -o pipefail
    rate=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%+d%%\", ($NAUTICE_TTS_RATE - 1) * 100 }")
    ${pkgs.python3Packages.edge-tts}/bin/edge-tts -v "$1" --rate "$rate" \
        -f /dev/stdin --write-media /dev/stdout \
      | ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error -i pipe: -y "$NAUTICE_TTS_OUT"
  '';

  # 로컬이 먼저, 실패하면 edge-tts. stdin 은 한 번만 읽히므로 파일로 받아 둔다.
  tts = pkgs.writeShellScript "nautice-tts" ''
    text=$(${pkgs.coreutils}/bin/mktemp) || exit 1
    trap '${pkgs.coreutils}/bin/rm -f "$text"' EXIT
    ${pkgs.coreutils}/bin/cat > "$text"
    ${subline-tts}/bin/subline-tts < "$text" && exit 0
    ${edge-tts} "$1" < "$text"
  '';
in
{
  # 둘 다 실패하면 nautice 가 내장 espeak-ng 로 말한다.
  home.packages = [ pkgs.espeak-ng ];

  # EN 은 `nautice call` 의 기본 문구("Your agent is calling") 때문이다.
  home.sessionVariables = {
    NAUTICE_TTS_CMD_KO = "${tts} ko-KR-SunHiNeural";
    NAUTICE_TTS_CMD_EN = "${tts} en-US-AvaNeural";
  };
}
