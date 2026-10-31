"""Set LaunchServices default-application handlers, idempotently.

Usage: set-default-handlers.py <secure-plist-path> [<uti>=<bundle-id> | !<bundle-id>] ...

`!<bundle-id>` drops every entry that points at that app, whatever the type.
default-apps.nix passes it for an app whose cask is not declared on this host:
without it the entries written while the app was installed stay behind, and
LaunchServices keeps resolving those types to an app that is gone.

Called from modules/darwin/default-apps.nix at activation. See that file for
why this is a hand-written plist edit rather than `duti`.
"""

import plistlib
import subprocess
import sys


def read_domain(path):
    out = subprocess.run(
        ["/usr/bin/defaults", "export", path, "-"], capture_output=True
    )
    if not out.stdout.strip():
        return {}
    return plistlib.loads(out.stdout)


def main():
    path = sys.argv[1]
    wanted = dict(a.split("=", 1) for a in sys.argv[2:] if not a.startswith("!"))
    dropped = {a[1:] for a in sys.argv[2:] if a.startswith("!")}

    data = read_domain(path)
    handlers = data.get("LSHandlers", [])

    # Rebuild the array: keep every entry we don't manage (URL schemes, types
    # set by hand in Finder), keep ours if already correct, drop ours if stale.
    kept = []
    missing = dict(wanted)
    removed = 0
    for h in handlers:
        content_type = h.get("LSHandlerContentType")
        if content_type not in wanted and h.get("LSHandlerRoleAll") in dropped:
            removed += 1
            continue
        if content_type not in wanted:
            kept.append(h)
            continue
        correct = (
            h.get("LSHandlerRoleAll") == wanted[content_type]
            # Entries without this key are ignored by LaunchServices outright,
            # so an otherwise-correct one still has to be rewritten.
            and "LSHandlerPreferredVersions" in h
        )
        if correct:
            missing.pop(content_type, None)
            kept.append(h)

    if not missing and not removed:
        print("default handlers: already correct")
        return

    for uti, bundle in missing.items():
        kept.append({
            "LSHandlerContentType": uti,
            "LSHandlerRoleAll": bundle,
            "LSHandlerPreferredVersions": {"LSHandlerRoleAll": "-"},
        })

    data["LSHandlers"] = kept
    subprocess.run(
        ["/usr/bin/defaults", "import", path, "-"],
        input=plistlib.dumps(data),
        check=True,
    )
    print("default handlers: wrote %d (%s), dropped %d" % (len(missing), ", ".join(sorted(missing)), removed))


if __name__ == "__main__":
    main()
