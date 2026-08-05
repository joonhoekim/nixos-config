# VS Code's integrated terminal loses Hangul syllables when you type fast:
# "알겠습니다." arrives as "알겠습다." — the 니 never reaches the pty at all.
# It is not a configuration problem and there is no setting for it; the bug is
# inside the xterm.js bundle Microsoft ships prebuilt. So this overlay patches
# that bundle.
#
# The whole investigation, including how the cause was pinned down from a
# runtime trace rather than guessed, is in
# docs/postmortems/2026-08-05-vscode-terminal-hangul.md. The short version:
#
#   xterm.js sends a finished composition on a setTimeout(…, 0), and guards
#   every pending send with ONE shared boolean, _isSendingComposition. Type fast
#   enough and two compositions end in the same tick, so two timers are pending
#   at once. The next non-composition key (a period, a space) calls
#   _finalizeComposition(false), which clears that boolean to cancel "the"
#   pending send — and thereby cancels every pending send, including one that
#   had not run yet. That syllable is dropped silently.
#
# The patch replaces the shared boolean with a FIFO queue: a synchronous
# finalize DRAINS the queue in order instead of cancelling it, and a send
# watermark (_hSentUpTo) makes double-sending impossible no matter which path
# emits first. The end boundary stops asking _isComposing (which is already
# false by the time a drained callback runs) and asks the question it actually
# meant: "did a newer composition start past my start offset?"
#
# Why patching this file is safe:
#
#   - It is the file VS Code really loads. The workbench asks for it by name —
#     `await Qf("@xterm/xterm", "lib/xterm.js")` — so the .mjs sitting next to
#     it (package.json "module") is never used.
#   - It is not checksummed. product.json lists exactly 10 checksums and all of
#     them are under out/; node_modules/** is not covered, so this does not trip
#     the "installation appears corrupt" warning.
#   - Minification keeps property names (_compositionPosition, _textarea,
#     _coreService.triggerDataEvent …) and mangles only locals, which is what
#     makes these anchors matchable at all.
#
# What will break, and how you will find out: every anchor below is a literal
# slice of minified VS Code output, so a VS Code update will eventually change
# one and the build will fail with
#
#   substituteStream() … ERROR: pattern … doesn't match anything in file …
#
# --replace-fail is deliberate. Without it the patch would quietly apply to
# nothing and Hangul would start dropping again with no clue why.
#
# When it happens, run
#
#   ./overlays/vscode-xterm-hangul-anchors.py
#
# It reads the anchors back out of THIS file, reports which one broke, and
# prints how that method reads in the new bundle — usually enough to rewrite
# the anchor in place. Full runbook, including how to tell whether upstream
# fixed the bug (in which case delete this file rather than re-anchor):
# docs/postmortems/2026-08-05-vscode-terminal-hangul.md.


final: prev:

# Linux only. modules/shared/default.nix hands this directory to macOS as well
# (hosts/darwin/default.nix imports ../../modules/shared), and there VS Code is
# an .app bundle — the path below does not exist, so substituteInPlace would
# fail the darwin build outright. The bug is a Linux/Wayland/fcitx5 one anyway.
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  vscode = prev.vscode.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      xt="$out/lib/vscode/resources/app/node_modules/@xterm/xterm/lib/xterm.js"
      substituteInPlace "$xt" \
        --replace-fail "this._compositionSuffix=\"\",this._dataAlreadySent=\"\"}compositionstart(){this._isComposing=!0;" \
                       "this._compositionSuffix=\"\",this._dataAlreadySent=\"\"}_hL(t,o){if(!globalThis.__hangulDebug)return;try{const m=\"[HANGUL] \"+t+\" \"+JSON.stringify(o);(globalThis.__hangulLog=globalThis.__hangulLog||[]).push(m),console.log(m)}catch(_){}}_hSnap(){return{v:this._textarea.value,ss:this._textarea.selectionStart,se:this._textarea.selectionEnd,ps:this._compositionPosition.start,pe:this._compositionPosition.end,ic:this._isComposing,isc:this._isSendingComposition,das:this._dataAlreadySent,w:this._hSentUpTo}}compositionstart(){this._hL(\"compositionstart:enter\",this._hSnap()),this._isComposing=!0;" \
        --replace-fail "this._compositionView.textContent=\"\",this._dataAlreadySent=\"\",this._compositionView.classList.add(\"active\")}" \
                       "this._compositionView.textContent=\"\",this._dataAlreadySent=\"\",this._hSentUpTo=Math.min(this._hSentUpTo||0,this._compositionPosition.start),this._compositionView.classList.add(\"active\"),this._hL(\"compositionstart:exit\",this._hSnap())}" \
        --replace-fail "compositionupdate(e){this._compositionView.textContent=" \
                       "compositionupdate(e){this._hL(\"compositionupdate\",{data:e.data,snap:this._hSnap()}),this._compositionView.textContent=" \
        --replace-fail "compositionend(){this._finalizeComposition(!0)}keydown(e){if(this._isComposing||this._isSendingComposition){" \
                       "compositionend(){this._hL(\"compositionend\",this._hSnap()),this._finalizeComposition(!0)}keydown(e){this._hL(\"keydown\",{kc:e.keyCode,key:e.key,snap:this._hSnap()});if(this._isComposing||this._isSendingComposition){" \
        --replace-fail "_finalizeComposition(e){if(this._compositionView.classList.remove(\"active\"),this._isComposing=!1,e){const e={start:this._compositionPosition.start,end:this._compositionPosition.end},t=this._compositionSuffix;this._isSendingComposition=!0,setTimeout(()=>{if(this._isSendingComposition){let i;if(this._isSendingComposition=!1,e.start+=this._dataAlreadySent.length,this._isComposing)i=this._textarea.value.substring(e.start,this._compositionPosition.start);else{const s=this._textarea.value,r=t.length>0&&s.endsWith(t)?s.length-t.length:s.length;i=s.substring(e.start,Math.max(e.start,r))}i.length>0&&this._coreService.triggerDataEvent(i,!0)}},0)}else{this._isSendingComposition=!1;const e=this._textarea.value.substring(this._compositionPosition.start,this._compositionPosition.end);this._coreService.triggerDataEvent(e,!0)}}" \
                       "_finalizeComposition(e){this._hL(\"finalize:enter\",{wait:e,snap:this._hSnap()}),this._compositionView.classList.remove(\"active\"),this._isComposing=!1;if(e){const p={start:this._compositionPosition.start,end:this._compositionPosition.end},t=this._compositionSuffix,d=this._dataAlreadySent;const cb=()=>{this._isSendingComposition=!1,p.start+=d.length;const v=this._textarea.value,b=this._compositionPosition.start>p.start?this._compositionPosition.start:(t.length>0&&v.endsWith(t)?v.length-t.length:v.length),f=Math.max(p.start,this._hSentUpTo||0),g=Math.max(f,b),o=v.substring(f,g);g>(this._hSentUpTo||0)&&(this._hSentUpTo=g),this._hL(\"deferred:FLUSH\",{from:f,to:g,out:o}),o.length>0&&this._coreService.triggerDataEvent(o,!0)};(this._hQ=this._hQ||[]).push(cb),this._isSendingComposition=!0,setTimeout(()=>{const k=this._hQ.indexOf(cb);k>=0&&(this._hQ.splice(k,1),cb())},0)}else{if(this._hQ&&this._hQ.length){const q=this._hQ.slice();this._hQ.length=0,this._hL(\"sync:DRAIN\",{n:q.length});for(let n=0;n<q.length;n++)q[n]()}this._isSendingComposition=!1;const v=this._textarea.value,b=Math.max(this._compositionPosition.end,this._textarea.selectionEnd??this._compositionPosition.end),f=Math.max(this._compositionPosition.start,this._hSentUpTo||0),g=Math.max(f,b),o=v.substring(f,g);g>(this._hSentUpTo||0)&&(this._hSentUpTo=g),this._hL(\"sync:RESULT\",{from:f,to:g,out:o}),o.length>0&&this._coreService.triggerDataEvent(o,!0)}}" \
        --replace-fail "_handleAnyTextareaChanges(){if(this._textareaChangeTimer)return;" \
                       "_handleAnyTextareaChanges(){if(this._textareaChangeTimer)return void this._hL(\"textarea:SKIPPED-timer-pending\",this._hSnap());"
    '';
  });
}
