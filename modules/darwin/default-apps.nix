{ pkgs, user, ... }:

# Default-application handlers: which app opens which kind of file.
#
# Two groups, one mechanism:
#   • terminal-shaped files  → Ghostty (double-clicking a .sh should RUN it)
#   • code and config files  → VS Code (rift's "settings" item, .toml, .json, …)
#
# macOS has no "default terminal" or "default editor" setting: LaunchServices
# only knows the pseudo-UTIs com.apple.default-app.{web-browser,mail-client,…},
# and there is no ...default-app.{terminal,editor}. What actually decides where
# a file opens is the per-UTI role handler. With no user override LaunchServices
# picks a registered claimant on its own — which is how `.toml` ended up at Zed
# (Zed's Info.plist claims the whole `public.text` UTI, so it inherits every
# text-ish type nobody else has claimed) and how the Xcode-owned source types
# ended up at Xcode.
#
# ── Why this writes the plist by hand instead of using `duti` ────────────────
# The handlers live in ~/Library/Preferences/com.apple.LaunchServices/
# com.apple.launchservices.secure.plist. This module used to drive it with
# duti, on the theory that a plain `defaults write` is ignored — that is only
# half true, and the half that matters is different.
#
# On macOS 26 duti is unreliable: LSSetDefaultRoleHandlerForContentType (what
# duti calls) returns noErr and then does nothing for a type that has no
# existing entry, so `duti -s com.microsoft.VSCode public.toml all` silently
# left the plist untouched. It only worked for types already in the array. The
# modern replacement, NSWorkspace.setDefaultApplication(at:toOpen:), never
# invokes its completion handler from a non-GUI process at all.
#
# A direct plist write does work, with one non-obvious requirement: the entry
# must carry `LSHandlerPreferredVersions = { LSHandlerRoleAll = "-" }`.
# Without that key LaunchServices ignores the entry completely — it is present
# on every entry the system writes itself, and it is the actual reason the
# "defaults write is ignored" folklore exists. With it, a hand-written entry is
# honoured. Verified end-to-end: after writing public.toml, `open x.toml`
# launches VS Code.
#
# ── A logout is required for types another app has already claimed ──────────
# LaunchServices caches its resolution per content type. A type nothing had
# claimed yet (public.toml) flips immediately; a type Xcode or TextEdit already
# owns keeps resolving to the old app until the LS database is rebuilt, which
# in practice means logging out and back in. `lsregister` cannot force it —
# note that `lsregister -domain user` is not even valid syntax (the flag is
# `-apps`/`-all`), and `-kill` was removed in macOS 26. So: after a rebuild
# that changes a handler here, log out and back in before concluding it failed.
#
# Types deliberately NOT claimed for VS Code:
#   public.html          → browser (Chrome); you want to *view* a web page
#   public.log           → Console.app
#   public.perl-script,  → Ghostty, by inheritance from the shell-script tree.
#   public.shell-script     Claiming these for an editor would stop .sh files
#   public.zsh-script       from running on double-click, which is the whole
#   public.csh-script       point of the Ghostty group.
#   public.comma-separated-values-text → OnlyOffice; a .csv is a spreadsheet

let
  ghostty = "com.mitchellh.ghostty";
  vscode = "com.microsoft.VSCode";

  handlers = {
    # ── Terminal-shaped files → Ghostty ──────────────────────────────────
    # Only types Ghostty declares in its Info.plist are claimed. Deliberately
    # left alone: public.directory (Finder owns folders — Ghostty is only
    # registered as an Alternate) and com.apple.terminal.session (.term is
    # Terminal's own format and Ghostty cannot read it).
    "com.apple.terminal.shell-script" = ghostty;  # .command
    "public.unix-executable" = ghostty;           # .tool and bare binaries
    "public.shell-script" = ghostty;              # .sh
    "public.zsh-script" = ghostty;                # .zsh — else defaults to Xcode
    "public.csh-script" = ghostty;                # .csh

    # ── Code and config → VS Code ────────────────────────────────────────
    # The umbrella types. public.text is what Zed was riding to claim
    # everything; taking it means an unrecognised text file lands in the
    # editor rather than in Zed or TextEdit. The shell-script entries above
    # are more specific, so they still win for .sh/.zsh/.csh.
    "public.text" = vscode;
    "public.plain-text" = vscode;
    "public.utf8-plain-text" = vscode;
    "public.source-code" = vscode;

    # Config formats. public.toml is the one that sent rift's "settings" menu
    # item to Zed — rift opens ~/.config/rift/config.toml via LaunchServices.
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
    # .js was going to Chrome and .css to Firefox — browsers *render* these,
    # which is never what you want from a double-click in a project folder.
    "com.netscape.javascript-source" = vscode;
    "public.css" = vscode;
  };

  args = builtins.concatStringsSep " " (
    builtins.attrValues (
      builtins.mapAttrs (uti: bundle: "${uti}=${bundle}") handlers
    )
  );

  plist = "/Users/${user}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist";
in
{
  system.activationScripts.postActivation.text = ''
    echo "setting default application handlers..." >&2
    /usr/bin/sudo -u ${user} ${pkgs.python3}/bin/python3 \
      ${./config/set-default-handlers.py} ${plist} ${args} || true
  '';
}
