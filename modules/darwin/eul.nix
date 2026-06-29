{ user, ... }:

# Declarative settings for eul (https://github.com/gao-sun/eul), a macOS
# menu-bar system monitor installed via Homebrew cask.
#
# eul has no dotfile config — it stores everything in the UserDefaults domain
# `com.gaosun.eul` (~/Library/Preferences/com.gaosun.eul.plist). Most keys are
# Swift `Codable` structs serialized to JSON and stored as a *Data* value, not
# a String. nix-darwin's `system.defaults.CustomUserPreferences` can only emit
# `<string>`/`<bool>` types, so writing these as strings makes eul fail to
# decode and silently reset to defaults.
#
# We therefore write the Data-typed keys via `defaults write -data <hex>`,
# generating the hex from the JSON at activation time with `xxd`. Scalar keys
# go through the typed-but-Data-free `defaults write` calls below too, so eul's
# whole config lives in this one module.
#
# Machine-specific keys are deliberately NOT managed: `NSWindow Frame Eul
# Preferences` (window position) and `NSStatusItem VisibleCC eul` placement.
#
# eul must be restarted to pick up changes (it reads defaults at launch).

let
  # Each value is the exact JSON eul serializes into a Data blob.
  dataKeys = {
    EulComponent = ''{"showComponents":true,"activeComponents":["CPU","Memory","Network"],"availableComponents":["GPU","Disk","Battery"]}'';

    CpuTextComponent = ''{"showComponents":true,"activeComponents":["usagePercentage"],"availableComponents":["loadAverage1Min","loadAverage5Min","loadAverage15Min","temperature"]}'';

    componentConfig = ''{"converted":true,"configs":[{"showIcon":false,"showGraph":false,"diskSelection":"","component":"Memory","networkPortSelection":""},{"showIcon":true,"showGraph":false,"diskSelection":"","component":"Disk","networkPortSelection":""},{"showIcon":false,"showGraph":false,"diskSelection":"","component":"CPU","networkPortSelection":""},{"showIcon":false,"showGraph":false,"diskSelection":"","component":"GPU","networkPortSelection":""},{"showIcon":true,"showGraph":false,"diskSelection":"","component":"Battery","networkPortSelection":""},{"showIcon":false,"showGraph":false,"diskSelection":"","component":"Network","networkPortSelection":""}]}'';

    preference = ''{"showCPUTopActivities":true,"fontDesign":"default","language":"en","showIcon":true,"cpuMenuDisplay":"usagePercentage","showRAMTopActivities":false,"appearance":"auto","showNetworkTopActivities":false,"temperatureUnit":"celius","smcRefreshRate":3,"networkRefreshRate":3,"textDisplay":"compact","checkStatusItemVisibility":true,"upgradeMethod":"showInStatusBar"}'';
  };

  writeDataCmds = builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (key: json:
        ''/usr/bin/sudo -u ${user} /usr/bin/defaults write com.gaosun.eul ${key} -data "$(printf '%s' ${"'"}${json}${"'"} | /usr/bin/xxd -p | /usr/bin/tr -d '\n')"''
      ) dataKeys
    )
  );
in
{
  system.activationScripts.postActivation.text = ''
    echo "configuring eul (com.gaosun.eul) defaults..." >&2
    ${writeDataCmds}
  '';
}
