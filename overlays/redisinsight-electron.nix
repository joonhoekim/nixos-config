# redisinsight 를 electron 41 대신 43 으로 빌드한다.
#
# nixpkgs 의 redisinsight 3.6.0 은 electron_41 을 쓰는데, 41 이 EOL 이 되면서
# insecure 표시가 붙었다. 그대로 두면 modules/nixos/packages.nix 에서
# redisinsight 를 쓰는 NixOS 호스트 전부가 평가 단계에서 멈춘다.
# permittedInsecurePackages 로 여는 대신 electron 을 바꾼다.
#
# 근거:
#   - nixpkgs PR #555140 (redisinsight 메인테이너) 이 같은 교체를 한다 —
#     electron_41 -> electron_43, 앱 3.6.0 -> 3.8.0, nodejs-slim_24 -> 26.
#     x86_64/aarch64-linux 에서 빌드와 실행을 확인했다고 적혀 있다.
#     여기서는 electron 만 바꾸므로 그 PR 과 똑같은 조합은 아니다.
#   - 상류 RedisInsight 의 main 도 electron ^43 으로 넘어갔다.
#   - 네이티브 모듈(sqlite3, keytar)은 빌드 중에 electron.headers 로
#     `npm rebuild` 되므로, electron 을 바꾸면 ABI 도 같이 따라간다.
#
# 지우는 조건: #555140 이 병합되어 nixpkgs 의 redisinsight 가 electron_41 인자를
# 더 받지 않게 되면, 이 override 가 "unexpected argument" 로 평가 에러를 낸다.
# 그 에러가 이 파일을 지우라는 신호다.
#
# node 도 24 대신 26 으로 바꾼다. node 24.19 부터 node::ObjectWrap 에 cleanup hook
# 이 절반만 백포트되어(nodejs/node#65446), api 의 better-sqlite3 12.x 가 종료 시
# `RemoveEnvironmentCleanupHook ... (env) != nullptr` 로 abort 한다. 빌드 중
# `yarn generate:api-client` 가 SIGABRT 로 죽는다. 26 은 영향이 없고 #555140 도 26 을 쓴다.
final: prev: {
  redisinsight = prev.redisinsight.override {
    electron_41 = final.electron_43;
    nodejs-slim_24 = final.nodejs-slim_26;
  };
}
