{ config, lib, pkgs, user, ... }:

# 두 세션이 같이 쓰는 DMS 플러그인을 $HOME 에 심는다(셸 자체는 ../niri 가 켠다).
# 배치·재시작·심는 자리 등 전체 그림: docs/dms-plugins.md
# settings.json 을 손으로 고쳤거나 plugin.json 을 고쳤으면 `dms restart` — 안 하면 조용히 안 바뀐다.

let
  cfg = config.local.dms;
  pluginDir = "$HOME/.config/DankMaterialShell/plugins";
  settingsFile = "$HOME/.config/DankMaterialShell/plugin_settings.json";

  # 폴더는 rice_sync 가, id 는 plugin_settings.json 의 `enabled` 가 쓴다.
  plugins =
    [ { dir = ./plugins/RiceSwitcher; id = "riceSwitcher"; } ]
    ++ lib.optional cfg.touchControls.enable
      { dir = ./plugins/TouchControls; id = "touchControls"; };
in
{
  options.local.dms.touchControls.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      TouchControls 조각을 심는다. 화면 키보드·회전 잠금·태블릿 모드를 DankBar
      에서 손가락으로 켜고 끈다.

      기본이 꺼짐인 것은 이 조각이 `touch-state` 와 그 뒤의 세 CLI 에 기대고
      있어서다. 그것들은 터치 하드웨어가 있는 호스트만 깔고(지금은
      hosts/nixos/galaxy-chromebook-1/touch.nix 하나), 없는 머신에 조각만 뜨면
      눌러도 아무 일도 안 하는 단추가 된다.
    '';
  };

  config = lib.mkIf config.programs.dms-shell.enable {
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedDmsPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        ${lib.concatMapStringsSep "\n        "
          (p: ''rice_sync ${p.dir} "${pluginDir}/${baseNameOf p.dir}"'') plugins}
        rice_sync ${./plugin-settings.json} "${settingsFile}"

        # DMS 가 늘 다시 쓰는 파일이라 rice_sync 가 손을 떼므로(판정표 3·4행), 이 키만 없을 때 끼워 넣는다.
        # 키가 이미 있으면 false 여도 건드리지 않는다 — 끈 것을 도로 켜지 않는다.
        ${lib.concatMapStringsSep "\n        " (p: ''
          if [ -f "${settingsFile}" ] &&
             ! ${pkgs.jq}/bin/jq -e 'has("${p.id}")' "${settingsFile}" >/dev/null 2>&1; then
            $DRY_RUN_CMD ${pkgs.jq}/bin/jq '. + { ${p.id}: { enabled: true } }' \
              "${settingsFile}" > "${settingsFile}.tmp" \
              && $DRY_RUN_CMD mv "${settingsFile}.tmp" "${settingsFile}"
            echo "enabled ${p.id} in plugin_settings.json"
          fi'') plugins}
      '';
    };
  };
}
