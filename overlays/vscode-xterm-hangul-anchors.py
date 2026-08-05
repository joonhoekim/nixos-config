#!/usr/bin/env python3
"""Diagnose overlays/vscode-xterm-hangul.nix against a VS Code build.

Run this when a rebuild fails with

    substituteStream() in derivation vscode-…: ERROR: pattern … doesn't match
    anything in file '…/@xterm/xterm/lib/xterm.js'

which is what --replace-fail does when a VS Code update moves the minified code
the overlay anchors on. It is the intended failure: loud, not silent.

    ./overlays/vscode-xterm-hangul-anchors.py              # against `which code`
    ./overlays/vscode-xterm-hangul-anchors.py /nix/store/…-vscode-1.131.0

For every anchor it reports FOUND / MISSING / AMBIGUOUS, and for the ones that
broke it prints the method as it now reads in the new bundle next to the
upstream TypeScript recovered from the shipped sourcemap. Rewriting the anchor
is then a matter of copying the new minified text into the .nix file.

The anchors are read out of the .nix file rather than repeated here, so there is
only ever one copy of them.
"""

import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.path.join(HERE, "vscode-xterm-hangul.nix")
REL_XTERM = "lib/vscode/resources/app/node_modules/@xterm/xterm"

# Methods the overlay touches, in the order they appear in CompositionHelper.
# Used only to print context for a broken anchor.
METHODS = ["compositionstart(", "compositionupdate(", "compositionend(",
           "keydown(", "_finalizeComposition(", "_handleAnyTextareaChanges("]

JSTR = r'"(?:[^"\\]|\\.)*"'


def read_anchors():
    """Pull the (old, new) pairs straight out of the overlay."""
    src = open(OVERLAY, encoding="utf8").read()
    pairs = re.findall(rf"--replace-fail\s+({JSTR})\s*\\\s*\n\s*({JSTR})", src)
    if not pairs:
        sys.exit(f"no --replace-fail pairs found in {OVERLAY}")
    # The .nix file holds them shell-escaped inside a '' block; the escaping is
    # exactly JSON's, so json.loads is the correct inverse.
    return [(json.loads(o), json.loads(n)) for o, n in pairs]


def resolve_vscode(argv):
    if len(argv) > 1:
        return argv[1]
    code = shutil.which("code")
    if not code:
        sys.exit("no `code` on PATH; pass a VS Code store path explicitly")
    return os.path.dirname(os.path.dirname(os.path.realpath(code)))


def method_body(blob, name):
    """Text of a method *definition*, not a call site.

    `_handleAnyTextareaChanges(` matches both `…Changes(),!1)}` inside keydown
    and the definition itself, so anchor on the `(args){` that only a
    definition has.
    """
    m = re.search(re.escape(name) + r"\w*\)\{", blob)
    if not m:
        return None
    i = m.start()
    ends = [blob.find(x, i + len(name)) for x in METHODS]
    ends = [e for e in ends if e > 0]
    return blob[i:min(ends)] if ends else blob[i:i + 1200]


def upstream_ts(xtermdir):
    path = os.path.join(xtermdir, "lib/xterm.mjs.map")
    if not os.path.exists(path):
        return None
    m = json.load(open(path, encoding="utf8"))
    want = "../src/browser/input/CompositionHelper.ts"
    if want not in m.get("sources", []):
        return None
    return m["sourcesContent"][m["sources"].index(want)]


def main():
    root = resolve_vscode(sys.argv)
    xtermdir = os.path.join(root, REL_XTERM)
    target = os.path.join(xtermdir, "lib/xterm.js")
    if not os.path.exists(target):
        sys.exit(f"not found: {target}\n"
                 "(macOS lays VS Code out as an .app bundle; this overlay and "
                 "this script are Linux-only)")

    print(f"vscode : {root}")
    print(f"bundle : {target}")
    # Which file the workbench actually loads — re-check this if it ever changes
    # from lib/xterm.js to the .mjs, because the overlay patches the .js only.
    wb = os.path.join(root, "lib/vscode/resources/app/out/vs/workbench/"
                            "workbench.desktop.main.js")
    if os.path.exists(wb):
        hit = re.search(r'\("@xterm/xterm","([^"]+)"\)',
                        open(wb, encoding="utf8", errors="replace").read())
        print(f"loads  : {hit.group(1) if hit else '?? (loader call changed)'}")

    blob = open(target, encoding="utf8", errors="replace").read()
    anchors = read_anchors()
    broken, patched, found = [], 0, 0
    print()
    for i, (old, new) in enumerate(anchors, 1):
        n_old, n_new = blob.count(old), blob.count(new)
        if n_new and not n_old:
            state, patched = "ALREADY PATCHED", patched + 1
        elif n_old == 1:
            state, found = "FOUND", found + 1
        elif n_old == 0:
            state, _ = "MISSING", broken.append((i, old))
        else:
            state, _ = f"AMBIGUOUS ({n_old}x)", broken.append((i, old))
        print(f"  [{state:>15}] anchor {i}: {old[:64]}…")

    if not broken:
        if patched == len(anchors):
            print("\nThis build already carries the patch — nothing to do. "
                  "(Point the script at an unpatched build to check anchors.)")
        elif patched:
            print(f"\nMixed: {patched} already patched, {found} still to apply. "
                  "That should not happen — inspect before trusting it.")
            return 1
        else:
            print("\nAll anchors match. The overlay applies cleanly to this build.")
        return 0

    ts = upstream_ts(xtermdir)
    print(f"\n{len(broken)} anchor(s) need rewriting.\n" + "=" * 72)
    for i, old in broken:
        print(f"\n--- anchor {i} no longer matches ---\n{old}\n")
        for m in METHODS:
            if m.split("(")[0] in old:
                body = method_body(blob, m)
                if body:
                    print(f"  {m[:-1]} as it now reads in this build:\n\n{body}\n")
                break
    print("=" * 72)
    if ts:
        # 285 lines; a path beats dumping it into the terminal every run.
        out = "/tmp/CompositionHelper.ts"
        open(out, "w", encoding="utf8").write(ts)
        print(f"Upstream CompositionHelper.ts recovered from this build's "
              f"sourcemap:\n  {out}\n\nDiff it against the version the patch was "
              "written for to see what upstream changed. If the fix landed "
              "upstream, delete the overlay instead of re-anchoring.")
    else:
        print("No sourcemap in this build — compare the minified text by hand.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
