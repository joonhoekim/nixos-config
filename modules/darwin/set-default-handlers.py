"""Set LaunchServices default-application handlers, idempotently.

Usage: set-default-handlers.py <secure-plist-path> <uti>=<bundle-id> ...

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
    wanted = dict(arg.split("=", 1) for arg in sys.argv[2:])

    data = read_domain(path)
    handlers = data.get("LSHandlers", [])

    # Rebuild the array: keep every entry we don't manage (URL schemes, types
    # set by hand in Finder), keep ours if already correct, drop ours if stale.
    kept = []
    missing = dict(wanted)
    for h in handlers:
        content_type = h.get("LSHandlerContentType")
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

    if not missing:
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
    print("default handlers: wrote %d (%s)" % (len(missing), ", ".join(sorted(missing))))


if __name__ == "__main__":
    main()
