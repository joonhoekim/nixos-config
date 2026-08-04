{ config, lib, pkgs, user, ... }:

# DankMaterialShell 의 플러그인. 셸 자체(programs.dms-shell)는 ../niri 에서 켠다 —
# 거기가 DMS 를 처음 들여온 자리이고, 세션과 systemd 배선이 같이 있어야 읽힌다.
# 이 모듈은 **두 세션이 같이 쓰는 DMS 조각**만 맡는다. niri 쪽에 두면 하이프랜드
# 전용 축(화면 셰이더)이 니리 모듈 안에 숨는 꼴이 되어서 갈랐다.
#
# ── RiceSwitcher ───────────────────────────────────────────────────────────
# 라이싱 축 전부를 런처(Mod+space) 안에서 고르는 런처 플러그인이다. 값도 목록도
# 여기 없다 — apps/rice-menu 가 JSON 으로 주고, 그건 다시 축별 스위처에게 묻는다.
# 그래서 축을 추가해도 QML 은 그대로다.
#
# ── 왜 /etc/xdg 가 아니라 $HOME 에 심는가 ─────────────────────────────────
# DMS 는 플러그인을 두 곳에서 찾는다 (Services/PluginService.qml):
#
#   ~/.config/DankMaterialShell/plugins/     사용자
#   /etc/xdg/quickshell/dms-plugins/         시스템
#
# 시스템 쪽에 environment.etc 로 두면 선언적이고 rebuild 마다 갱신된다는 장점이
# 있지만, 스토어 심볼릭 링크라 고쳐 볼 수가 없다. 이 레포의 라이싱 파일이 전부
# $HOME 에 시드되는 것과 같은 이유로 여기도 사용자 쪽이다 — QML 을 고치면 DMS 가
# 폴더를 감시하다 바로 다시 읽는다. 되받아 저장하는 건 apps/rice-save.
#
# ── plugin_settings.json ───────────────────────────────────────────────────
# 플러그인은 파일만 놓아서는 안 뜬다. DMS 가 `enabled: true` 를 봐야 로드한다
# (PluginService.qml 의 SettingsData.getPluginSetting(id, "enabled", false)).
# 그 값은 settings.json 이 아니라 plugin_settings.json 이라는 별도 파일에 산다.

let
  pluginDir = "$HOME/.config/DankMaterialShell/plugins";
  settingsFile = "$HOME/.config/DankMaterialShell/plugin_settings.json";
in
{
  config = lib.mkIf config.programs.dms-shell.enable {
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedDmsPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        seed ${./plugins/RiceSwitcher} "${pluginDir}/RiceSwitcher"
        seed ${./plugin-settings.json} "${settingsFile}"

        # seed 의 존재 검사에는 대가가 있다(../../shared/rice-seed-helpers.nix 머리말):
        # 파일이 이미 있는 머신에는 새 키가 영영 안 들어간다. 여기서는 그게 "플러그인
        # 파일은 깔렸는데 런처에 안 뜬다"가 되어 원인을 찾기 나쁘다. 그래서 줄 하나를
        # 보장하는 ensure 와 같은 취지로, 이 키만 없을 때 끼워 넣는다. 나머지 플러그인
        # 설정은 건드리지 않는다.
        if [ -f "${settingsFile}" ] &&
           ! ${pkgs.jq}/bin/jq -e 'has("riceSwitcher")' "${settingsFile}" >/dev/null 2>&1; then
          $DRY_RUN_CMD ${pkgs.jq}/bin/jq '. + { riceSwitcher: { enabled: true } }' \
            "${settingsFile}" > "${settingsFile}.tmp" \
            && $DRY_RUN_CMD mv "${settingsFile}.tmp" "${settingsFile}"
          echo "enabled riceSwitcher in plugin_settings.json"
        fi
      '';
    };
  };
}
