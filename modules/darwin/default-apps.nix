{ config, lib, pkgs, user, ... }:

# Default-application handlers per UTI. 전체 그림: docs/macos-internals.md
# Writes the LaunchServices plist directly: on macOS 26 duti returns noErr and silently does nothing for a type with no entry.
# Types another app already claimed flip only after a logout — log out before concluding it failed.

let
  terminal = "io.github.joonhoekim.SublineTerminal";
  vscode = "com.microsoft.VSCode";

  # Without the VS Code cask its id is passed as a drop (`!<id>`, set-default-handlers.py)
  # so entries left from an earlier install do not keep pointing at nothing.
  haveVscode = builtins.elem "visual-studio-code" (map (c: c.name) config.homebrew.casks);

  terminalHandlers = {
    # Exactly the types subline-terminal's Info.plist declares (tools/macos-bundle.sh in that repo);
    # an undeclared type would open the app and run nothing.
    "com.apple.terminal.shell-script" = terminal;  # .command, .tool
    "public.unix-executable" = terminal;           # bare executables
    "public.shell-script" = terminal;
    "public.bash-script" = terminal;
    "public.zsh-script" = terminal;                # .zsh — else defaults to Xcode
    "public.ksh-script" = terminal;
    "public.csh-script" = terminal;
    "public.tcsh-script" = terminal;
  };

  vscodeHandlers = {
    # public.text is the umbrella Zed's Info.plist claims; taking it keeps unknown text files out of Zed/TextEdit.
    # The more specific shell-script types above still win for .sh/.zsh/.csh.
    "public.text" = vscode;
    "public.plain-text" = vscode;
    "public.utf8-plain-text" = vscode;
    "public.source-code" = vscode;

    # rift-grid's "settings" menu item opens ~/.config/rift-grid/config.toml via LaunchServices.
    "public.toml" = vscode;
    "public.json" = vscode;
    "public.yaml" = vscode;
    "public.xml" = vscode;

    # Languages. These were all Xcode's by default.
    "public.python-script" = vscode;
    "public.ruby-script" = vscode;
    "public.php-script" = vscode;
    "public.c-source" = vscode;
    "public.c-header" = vscode;
    "public.c-plus-plus-source" = vscode;
    "public.objective-c-source" = vscode;
    "public.swift-source" = vscode;
    "public.make-source" = vscode;
    "net.daringfireball.markdown" = vscode;
    # By default browsers own .js/.css and *render* them on a double-click.
    "com.netscape.javascript-source" = vscode;
    "public.css" = vscode;
  };

  handlers = terminalHandlers // lib.optionalAttrs haveVscode vscodeHandlers;

  args = builtins.concatStringsSep " " (
    builtins.attrValues (
      builtins.mapAttrs (uti: bundle: "${uti}=${bundle}") handlers
    )
    ++ lib.optional (!haveVscode) "'!${vscode}'"
  );

  plist = "/Users/${user}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist";
in
{
  system.activationScripts.postActivation.text = ''
    echo "setting default application handlers..." >&2
    /usr/bin/sudo -u ${user} ${pkgs.python3}/bin/python3 \
      ${./set-default-handlers.py} ${plist} ${args} || true
  '';
}
