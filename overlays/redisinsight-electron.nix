# nixpkgs redisinsight 3.6.0 의 electron_41 이 EOL 로 insecure 가 되어, 그대로면 이걸 쓰는 NixOS 호스트 평가가 멈춘다.
# node 24.19+ 에선 better-sqlite3 12.x 가 종료 시 abort 해(nodejs/node#65446) 빌드 중 `yarn generate:api-client` 가 죽어서 26 으로 바꾼다.
# 지우는 조건: nixpkgs PR #555140 이 병합되면 이 override 가 "unexpected argument" 로 평가 에러를 낸다. 근거: docs/overlays.md
final: prev: {
  redisinsight = prev.redisinsight.override {
    electron_41 = final.electron_43;
    nodejs-slim_24 = final.nodejs-slim_26;
  };
}
