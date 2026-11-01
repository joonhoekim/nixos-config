{ pkgs, ... }:

# 패키지와 유닛은 선언적, 설정(/etc/nginx)은 명령형이다. services.nginx 를 안 쓰는 이유와 적용법: docs/nginx.md
# 적용: cd <app repo>; bash scripts/nginx/deploy-nginx.sh apply local

let
  # nixpkgs nginx 에는 --conf-path 가 없어 맨 `nginx -t` 가 스토어 기본 설정을 검사하고 통과한다 —
  # deploy-nginx.sh 의 reload 전 검사가 조용히 무력해진다. --add-flags 라 호출자의 -c 가 뒤에서 이긴다.
  nginxEtc = pkgs.symlinkJoin {
    name = "nginx-etc-${pkgs.nginx.version}";
    paths = [ pkgs.nginx ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nginx --add-flags "-c /etc/nginx/nginx.conf"
    '';
  };
in
{
  environment.systemPackages = [
    nginxEtc

    # mkcert 인증서는 발급한 CA 의 머신에서만 믿어진다.
    pkgs.mkcert
    # `mkcert -install` 이 신뢰 저장소에 닿는 길(certutil). 없으면 아무도 안 믿는 인증서가 나온다.
    # Chrome·Firefox(~/.pki/nssdb)만 덮는다. curl·node 는 SSL_CERT_FILE / NODE_EXTRA_CA_CERTS 로 그때그때.
    pkgs.nssTools
  ];

  # environment.etc 가 아닌 이유: 읽기 전용 심링크가 된다. mime.types 만 아무도 안 고쳐서 스토어에 링크한다.
  systemd.tmpfiles.rules = [
    "d /etc/nginx 0755 root root -"
    "d /etc/nginx/conf.d 0755 root root -"
    "d /etc/nginx/ssl 0750 root root -"
    "L+ /etc/nginx/mime.types - - - - ${pkgs.nginx}/conf/mime.types"
    # 컴파일된 --error-log-path. 없으면 nginx 가 안 뜬다.
    "d /var/log/nginx 0755 root root -"
  ];

  systemd.services.nginx = {
    description = "nginx (config in /etc/nginx, not managed declaratively)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # 설정이 아직 없으면 실패가 아니라 건너뛴다(안 그러면 부팅마다 실패 유닛이 남는다).
    unitConfig.ConditionPathExists = "/etc/nginx/nginx.conf";

    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${nginxEtc}/bin/nginx -t";
      # daemon off: pid 파일을 거치면 유닛의 PIDFile 과 손으로 고치는 nginx.conf 의 `pid` 가 늘 맞아야 한다.
      ExecStart = "${nginxEtc}/bin/nginx -g 'daemon off;'";
      # 같은 이유로 `nginx -s reload`(pid 파일을 읽는다) 대신 HUP. deploy-nginx.sh 의 systemctl reload 가 이 길이다.
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      # PrivateTmp 는 끈다 — 임시 경로가 /tmp/nginx_* 라 비공개 /tmp 면 아무도 못 본다.
    };
  };

  # 방화벽은 닫아 둔다(브라우저·Playwright 는 loopback). LAN 의 다른 기기가 닿아야 할 때만 80/443 을 연다.
}
