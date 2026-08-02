{ pkgs, user, ... }:

# Hand the terminal-shaped file types to Ghostty.
#
# macOS has no "default terminal" setting: LaunchServices only knows the
# pseudo-UTIs com.apple.default-app.{web-browser,mail-client,phone,...}, and
# there is no ...default-app.terminal. What actually decides where a .command
# file or a bare executable opens is the per-UTI role handler, and with no user
# override LaunchServices falls back to Terminal.app.
#
# The handlers live in ~/Library/Preferences/com.apple.LaunchServices/
# com.apple.launchservices.secure.plist, which must be written through the
# LaunchServices API (a plain `defaults write` is ignored until the LS database
# is rebuilt), so we drive it with duti.
#
# Only types Ghostty declares in its Info.plist are claimed. Deliberately left
# alone: public.directory (Finder owns folders — Ghostty is only registered as
# an Alternate) and com.apple.terminal.session (.term files are Terminal's own
# format and Ghostty cannot read them).

let
  ghostty = "com.mitchellh.ghostty";

  types = [
    "com.apple.terminal.shell-script"  # .command
    "public.unix-executable"           # .tool and bare binaries
    "public.shell-script"              # .sh
    "public.zsh-script"                # .zsh — otherwise defaults to Xcode
    "public.csh-script"                # .csh
  ];

  setHandlers = builtins.concatStringsSep "\n" (
    map (t:
      "/usr/bin/sudo -u ${user} ${pkgs.duti}/bin/duti -s ${ghostty} ${t} all || true"
    ) types
  );
in
{
  system.activationScripts.postActivation.text = ''
    echo "pointing terminal file types at Ghostty..." >&2
    ${setHandlers}
  '';
}
