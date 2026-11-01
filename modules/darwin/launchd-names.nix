{ config, lib, pkgs, ... }:

# Background App Activity(BTM)는 job 이름을 첫 ProgramArguments 의 basename 으로 정해서, nix-darwin 이 감싼
# `/bin/sh -c "/bin/wait4path ... && exec"`(modules/launchd/default.nix) 서비스는 전부 "sh" 로 보인다.
# 그래서 같은 줄을 서비스 이름의 스크립트로 /nix/store 밖에 둔다. 전체 그림: docs/macos-internals.md
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
