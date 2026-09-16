# Overlays

이 디렉터리의 `.nix` 파일은 **빌드마다 자동으로 적용된다** —
`modules/shared/default.nix` 가 `readDir` 로 훑어서 `nixpkgs.overlays` 에 넣는다.
파일을 두는 것이 곧 등록이라, flake.nix 를 고칠 일이 없다.

자동 임포트의 규칙 하나를 알고 있어야 한다: 판별이 `builtins.match ".*\\.nix"` 인데
**match 는 전체 일치**다. 이름이 `.nix` 로 끝나는 파일과 `default.nix` 를 가진
하위 디렉터리만 오버레이로 읽히고, 이 README 나 옆의 `.py` 헬퍼가 임포트되지 않는
것이 그 성질 덕분이다. grep 감각(부분 일치)으로 읽고 고치면 깨진다.

## 지금 있는 것

- `vscode-xterm-hangul.nix` — VS Code 의 xterm.js 한글 조합 렌더링 버그를 패치한다.
  옆의 `vscode-xterm-hangul-anchors.py` 는 그 패치가 참조하는 앵커를 뽑는 헬퍼
  스크립트로, 오버레이가 아니다(위 규칙대로 자동 임포트에서 빠진다).
  상류 논의는 xterm.js PR #6090 — 해결되면 이 오버레이는 지운다.
- `redisinsight-electron.nix` — EOL 로 insecure 가 된 electron 41 대신 43 으로
  redisinsight 를 빌드한다. nixpkgs PR #555140 이 병합되면 평가 에러가 나므로 그때 지운다.
- `avro-cpp-fmt12.nix` — avro-cpp 헤더의 fmt include 를 fmt 12 에 맞게 고쳐 kcat 빌드를
  살린다. avro-cpp 헤더가 바뀌면 `--replace-fail` 로 빌드가 멈추므로 그때 지운다.
