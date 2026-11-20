{ config, lib, pkgs, user, ... }:

# Thunar 파일 관리자와 우클릭 메뉴(Custom Actions). 액션은 ~/.config/Thunar/uca.xml 하나에 있고,
# 여기서 home-manager 링크로 선언하므로 Thunar 의 "사용자 정의 동작 설정" 창에서 고친 것은 저장되지 않는다
# (읽기 전용 링크라 쓰기가 실패한다). 액션을 늘리려면 아래 `actions` 에 붙인다.
let
  # Thunar 는 %f·%F 를 셸 인용해서 명령줄에 넣는다. 그래서 명령에서 `sh -c '... %f'` 처럼 다시 따옴표로
  # 감싸면 인용이 깨진다 — 인자를 받는 스크립트를 두고 명령은 `스크립트 %f` 로만 쓴다.

  # 세션은 실행한 곳의 cwd 를 이어받는다(subline-terminal new 가 그 디렉터리에서 셸을 띄운다).
  terminalHere = pkgs.writeShellScript "thunar-terminal-here" ''
    cd "$1" && exec subline-terminal new
  '';

  # `cld` 는 대화형 셸의 alias(modules/shared/shell-init.nix)라 `subline-terminal run` 으로는 못 부른다.
  # 세션을 만들어 그 셸에 입력으로 보내고 창을 붙인다 — 끝나도 셸이 남는다.
  claudeHere = pkgs.writeShellScript "thunar-claude-here" ''
    cd "$1" || exit 1
    base="$(basename "$PWD" | tr -c 'A-Za-z0-9-' '-' | tr 'A-Z' 'a-z' | cut -c1-24)"
    name="claude-''${base%-}-$(date +%H%M%S)"
    subline-terminal new -d "$name" >/dev/null || exit 1
    # send 는 줄바꿈을 붙이지 않는다. $(printf …) 로 만들면 명령 치환이 끝 줄바꿈을 떼어 Enter 가 안 들어간다.
    subline-terminal send "$name" $'cld\n'
    exec subline-terminal attach "$name"
  '';

  copyPath = pkgs.writeShellScript "thunar-copy-path" ''
    printf '%s\n' "$@" | ${pkgs.coreutils}/bin/head -c -1 | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  # 세션마다 배경을 쥔 쪽이 다르다. subline 은 ~/.config/subline/config.toml 의 [background] image 를
  # 1초마다 다시 읽고(subline crates/compositor/src/settings.rs), 그 파일은 설정 앱도 쓰므로 tomlkit 으로
  # 그 키만 바꾸고 나머지 서식은 둔다. niri·Hyprland 는 DMS(apps/rice/wall 과 같은 호출), GNOME 은 gsettings.
  setWallpaper = pkgs.writers.writePython3 "thunar-set-wallpaper"
    { libraries = [ pkgs.python3Packages.tomlkit ]; flakeIgnore = [ "E501" ]; }
    ''
      import os
      import subprocess
      import sys
      import tomlkit

      path = os.path.abspath(sys.argv[1])
      desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()

      if "subline" in desktop:
          conf = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "subline", "config.toml")
          try:
              with open(conf) as f:
                  doc = tomlkit.parse(f.read())
          except FileNotFoundError:
              doc = tomlkit.document()
          if "background" not in doc:
              doc["background"] = tomlkit.table()
          doc["background"]["image"] = path
          # 같은 디렉터리에 쓰고 바꿔치기한다. 반쯤 쓴 파일을 subline 이 읽으면 설정 전체가 기본값으로 돌아간다.
          tmp = conf + ".tmp"
          with open(tmp, "w") as f:
              f.write(tomlkit.dumps(doc))
          os.replace(tmp, conf)
      elif "gnome" in desktop:
          uri = "file://" + path
          for key in ("picture-uri", "picture-uri-dark"):
              subprocess.run(["gsettings", "set", "org.gnome.desktop.background", key, uri], check=True)
      else:
          subprocess.run(["dms", "ipc", "call", "wallpaper", "set", path], check=True)
    '';

  # appearsOn: directories 는 폴더를 고른 때와 폴더 빈 곳을 우클릭한 때(그 폴더가 %f) 둘 다다.
  # 메뉴 이름은 영어로 둔다. 한글 글꼴이 없는 환경에서는 두부(□)로 깨진다.
  allFiles = [ "directories" "audio-files" "image-files" "other-files" "text-files" "video-files" ];
  actions = [
    { id = "terminal-here"; name = "Open Terminal Here"; icon = "utilities-terminal";
      command = "${terminalHere} %f"; range = "1"; appearsOn = [ "directories" ]; }
    { id = "claude-here"; name = "Open Claude Here"; icon = "utilities-terminal";
      command = "${claudeHere} %f"; range = "1"; appearsOn = [ "directories" ]; }
    { id = "vscode"; name = "Open with VS Code"; icon = "vscode";
      command = "code %F"; appearsOn = allFiles; }
    { id = "wallpaper"; name = "Set as Wallpaper"; icon = "preferences-desktop-wallpaper";
      command = "${setWallpaper} %f"; range = "1";
      patterns = "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.PNG;*.JPG;*.JPEG;*.WEBP;*.BMP"; appearsOn = [ "image-files" ]; }
    { id = "copy-path"; name = "Copy Path"; icon = "edit-copy";
      command = "${copyPath} %F"; appearsOn = allFiles; }
    { id = "localsend"; name = "Send with LocalSend"; icon = "localsend";
      # 이미 떠 있으면 그 창으로 넘겨 보내기 목록에 넣는다(localsend app/lib/config/init.dart 의 notifyRunningInstance).
      command = "localsend_app %F"; appearsOn = allFiles; }
  ];

  # 명령에 &·< 가 들어가면 XML 이 깨져 Thunar 가 액션 전부를 조용히 버린다. 위 명령은 스토어 경로와 %f 뿐이다.
  actionXml = a: ''
    <action>
    	<icon>${a.icon}</icon>
    	<name>${a.name}</name>
    	<submenu></submenu>
    	<unique-id>nix-${a.id}</unique-id>
    	<command>${a.command}</command>
    	<description></description>
    	<range>${a.range or ""}</range>
    	<patterns>${a.patterns or "*"}</patterns>
    	<startup-notify/>
    ${lib.concatMapStrings (t: "\t<${t}/>\n") a.appearsOn}</action>
  '';
in
{
  options.local.thunar.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Thunar 파일 관리자와 선언된 우클릭 액션.";
  };

  config = lib.mkIf config.local.thunar.enable {
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
    };
    # 이 둘이 없으면 Thunar 는 뜨지만 휴지통·외장 디스크·네트워크 경로(gvfs)와 썸네일(tumbler)이 조용히 빠진다.
    services.gvfs.enable = lib.mkDefault true;
    services.tumbler.enable = lib.mkDefault true;
    # thunar-archive-plugin 은 압축 작업을 이 앱에 넘긴다. 없으면 "압축 풀기" 메뉴가 안 뜬다.
    environment.systemPackages = [ pkgs.file-roller ];

    home-manager.users.${user}.xdg.configFile."Thunar/uca.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
      ${lib.concatMapStrings actionXml actions}</actions>
    '';
  };
}
