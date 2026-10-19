# home.activation fragment: keeps Claude Code from adding its trailers (Co-Authored-By,
# the remote-session link) to commits and PRs by forcing the attribution keys off on every switch.
#
# An absent key means "on" (Claude Code's default adds Co-Authored-By), so a missing
# file is created too. Other keys are left alone because Claude Code rewrites this file itself.
{ pkgs, lib }:
lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  claude_settings="$HOME/.claude/settings.json"
  # `"attribution": false` already turns off all three sub-keys, so it is left as is.
  claude_fix='(if .attribution == false then . else
                 .attribution.commit = "" | .attribution.pr = "" | .attribution.sessionUrl = false end)
              | .includeCoAuthoredBy = false'
  claude_bad='[ (if .attribution == false then empty else
                   (if .attribution.commit != "" then "attribution.commit" else empty end),
                   (if .attribution.pr != "" then "attribution.pr" else empty end),
                   (if .attribution.sessionUrl != false then "attribution.sessionUrl" else empty end) end),
                (if .includeCoAuthoredBy != false then "includeCoAuthoredBy" else empty end) ]
              | join(", ")'

  if [ -L "$claude_settings" ]; then
    echo "WARNING: $claude_settings is a symlink; not touching it. Check its attribution keys by hand." >&2
  elif [ ! -e "$claude_settings" ]; then
    echo "claude: creating $claude_settings with attribution off"
    $DRY_RUN_CMD mkdir -p "$HOME/.claude"
    [ -n "$DRY_RUN_CMD" ] || ${pkgs.jq}/bin/jq -n "$claude_fix" > "$claude_settings"
  elif ! claude_found=$(${pkgs.jq}/bin/jq -r "$claude_bad" "$claude_settings" 2>/dev/null); then
    echo "WARNING: $claude_settings is not valid JSON (or has an odd shape); attribution keys not checked." >&2
  elif [ -n "$claude_found" ]; then
    echo "claude: turning off $claude_found in $claude_settings"
    if [ -z "$DRY_RUN_CMD" ]; then
      claude_tmp=$(mktemp "$claude_settings.XXXXXX")
      ${pkgs.jq}/bin/jq "$claude_fix" "$claude_settings" > "$claude_tmp" \
        && mv "$claude_tmp" "$claude_settings" \
        || { rm -f "$claude_tmp"; echo "WARNING: failed to rewrite $claude_settings" >&2; }
    fi
  fi
''
