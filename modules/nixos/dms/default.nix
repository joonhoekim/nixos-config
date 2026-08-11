{ config, lib, pkgs, user, ... }:

# DankMaterialShell 의 플러그인. 셸 자체(programs.dms-shell)는 ../niri 에서 켠다 —
# 거기가 DMS 를 처음 들여온 자리이고, 세션과 systemd 배선이 같이 있어야 읽힌다.
# 이 모듈은 **두 세션이 같이 쓰는 DMS 조각**만 맡는다. niri 쪽에 두면 하이프랜드
# 전용 축(화면 셰이더)이 니리 모듈 안에 숨는 꼴이 되어서 갈랐다.
#
# ── RiceSwitcher ───────────────────────────────────────────────────────────
# 면이 둘인 composite 플러그인이다(PLUGINS/plugin-schema.json 의 components).
#
#   launcher  라이싱 축을 런처(Mod+space)에서 고른다. 값도 목록도 여기 없다 —
#             apps/rice-menu 가 JSON 으로 주고, 그건 다시 축별 스위처에게 묻는다.
#             그래서 축을 추가해도 QML 은 그대로다.
#   widget    DankBar 조각 하나. 누르면 라이싱 스튜디오를 띄우는 것이 전부다.
#
# ── 화면 셰이더는 여기 없다 ────────────────────────────────────────────────
# 한동안 있었고, 그게 이 플러그인을 망가뜨렸다. 셰이더 축만 성질이 다르다 —
# 다른 축은 값 하나를 고르면 끝인데 이쪽은 여러 장을 순서대로 쌓고, 조합마다
# 비용이 곱으로 늘고, 칸마다 손잡이가 따로 있다. 그걸 런처의 한 줄짜리 항목
# 계약에 우겨넣다 보니 QML 이 갈래 이름을 자르고 탭 수를 곱하고 한도(64)를 자기
# 안에 적어 두게 됐고, "이 파일은 축이 뭔지 모른다"는 자기 머리말과 어긋났다.
#
# 그래서 셰이더는 별도 창으로 나갔다(apps/rice-studio · ../hyprland/rice/studio).
# 여기 남은 것은 그 창을 여는 단추와, 화면이 망가졌을 때 쓰는 탈출구(off ·
# 다음 것)다 — 셰이더가 화면을 못 알아보게 만들면 그 창도 같은 유리 뒤에 있다.
#
# ── 바에 올리는 것은 손으로 한다 ───────────────────────────────────────────
# DankBar 의 조각 배치는 settings.json 의 barConfigs[].{left,center,right}Widgets
# 이고, 플러그인 조각의 id 는 플러그인 id 그대로다(Modules/DankBar/WidgetHost.qml
# 의 getWidgetComponent — componentMap 에 없으면 `:` 앞을 플러그인 id 로 본다).
# 그러니 아래에서 jq 로 끼워 넣을 수도 있지만 안 한다. plugin_settings.json 의
# `enabled` 와 달리 **배치는 취향이라, 뺀 것을 리빌드가 도로 넣으면 그게 매번
# 되풀이된다.** 한 번만 하면 되는 일이다:
#
#   DMS 설정 → DankBar → 조각 목록에서 Rice 를 원하는 자리에
#   (또는 settings.json 의 rightWidgets 에 "riceSwitcher" 한 줄)
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
#
# ── plugin.json 을 고쳤으면 셸을 재시작해야 한다 ───────────────────────────
# QML 은 저장하는 즉시 반영된다(DMS 가 플러그인 폴더를 감시한다). **매니페스트는
# 아니다.** `dms ipc call plugins reload <id>` 는 컴포넌트만 다시 읽고,
# plugin-scan 도 이미 아는 매니페스트는 건너뛴다. 그래서 manifest 에 키를 새로
# 넣으면(예: settings) 파일에는 있는데 DMS 는 모르는 상태가 되고, 증상은 "설정
# 패널이 있는데 플러그인 목록만 보인다"로 나타난다 — 실제로 한 번 겪었다.
#
#   dms restart
#
# 값 조절이나 QML 손보는 동안에는 필요 없다. plugin.json 을 건드렸을 때만이다.

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
