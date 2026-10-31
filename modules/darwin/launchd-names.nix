{ config, lib, pkgs, ... }:

# launchd 서비스가 System Settings > General > Login Items & Extensions 의 Background App
# Activity 에 제 이름으로 보이게 한다.
#
# macOS 의 백그라운드 항목 목록(BTM)은 legacy daemon/agent 의 이름을 plist 의 Label 이 아니라
# 첫 ProgramArguments 의 basename 으로 정한다(`sudo sfltool dumpbtm` 의 Name 과 Executable
# Path). nix-darwin 은 `command`/`script` 가 있는 서비스를 전부
#   [ "/bin/sh" "-c" "/bin/wait4path /nix/store && exec <command>" ]
# 로 감싸므로(nix-darwin modules/launchd/default.nix), 그런 서비스는 모두 "sh" 로 보이고
# 어느 것이 무엇인지 목록에서 가를 수 없다.
#
# 그래서 같은 한 줄을 서비스 이름의 래퍼 스크립트로 /usr/local/libexec/nix-darwin/ 에 두고
# ProgramArguments 를 그 하나로 바꾼다. 스크립트여도 BTM 은 해석기가 아니라 스크립트
# 경로를 기록한다(macOS 27.0.1 에서 시험 에이전트로 확인: Name: name-probe).
#
# 래퍼가 /nix/store 밖에 있는 이유: 부팅 때 launchd 가 이 경로를 실행하는 시점에는 Nix
# 볼륨이 아직 안 붙었을 수 있다 — wait4path 가 바로 그걸 기다리는 줄이다. 경로가 세대마다
# 바뀌지 않는 것도 필요하다. 바뀌면 BTM 이 새 항목으로 보고 "백그라운드 항목 추가됨"
# 알림을 다시 띄운다.
#
# submodule 타입을 확장하는 방식이라 `command` 를 가진 서비스는 앞으로 더해지는 것까지
# 자동으로 따라온다. ProgramArguments 를 직접 쓰는 서비스(org.nixos.kanata)는 이미 제
# 바이너리로 시작하므로 건드리지 않는다.
let
  dir = "/usr/local/libexec/nix-darwin";

  wrap = kind: { name, config, ... }: {
    config.serviceConfig.ProgramArguments =
      lib.mkIf (config.command != "") (lib.mkForce [ "${dir}/${kind}/${name}" ]);
  };

  # nix-darwin 이 감싸던 것과 같은 줄이다. 동작은 그대로이고 실행 파일 이름만 달라진다.
  scriptsOf = kind: jobs: lib.mapAttrsToList (name: job: {
    path = "${kind}/${name}";
    file = pkgs.writeText "launchd-${kind}-${name}" ''
      #!/bin/sh
      # ${job.serviceConfig.Label} — modules/darwin/launchd-names.nix 가 activation 때 쓴다.
      /bin/wait4path /nix/store && exec ${job.command}
    '';
  }) (lib.filterAttrs (_: job: job.command != "") jobs);

  scripts = scriptsOf "daemons" config.launchd.daemons
    ++ scriptsOf "agents" config.launchd.agents
    ++ scriptsOf "user-agents" config.launchd.user.agents;
in
{
  options.launchd = {
    daemons = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule (wrap "daemons")); };
    agents = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule (wrap "agents")); };
    user.agents = lib.mkOption { type = lib.types.attrsOf (lib.types.submodule (wrap "user-agents")); };
  };

  # preActivation 은 nix-darwin 이 launchd plist 를 다시 올리기 전에 돈다. 새 디렉토리를
  # 다 채운 뒤 통째로 바꿔 끼워서, 도는 중인 서비스가 반쯤 쓰인 래퍼를 실행하는 일이 없게 한다.
  # root 소유 755: root daemon 이 실행하는 파일을 사용자가 고칠 수 있으면 그게 곧 root 권한이다.
  config.system.activationScripts.preActivation.text = ''
    rm -rf ${dir}.new
    mkdir -p ${dir}.new/daemons ${dir}.new/agents ${dir}.new/user-agents
    ${lib.concatMapStrings (s: ''
      install -o root -g wheel -m 755 ${s.file} ${dir}.new/${s.path}
    '') scripts}
    rm -rf ${dir}.old
    [ -e ${dir} ] && mv ${dir} ${dir}.old
    mv ${dir}.new ${dir}
    rm -rf ${dir}.old
  '';
}
