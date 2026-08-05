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
# keydown's guard is repointed at the queue too. Leaving it reading the boolean
# looks harmless — nothing is cancelled any more — but it is not: the first
# callback to run would clear the flag while other sends were still queued, so
# the next non-composition key would decide nothing was in flight, skip the
# drain, and let those sends land AFTER it. That loses the ordering upstream
# does guarantee, which is the whole reason the synchronous path exists ("so
# that the composition is sent before the command is executed"). The bug is
# quieter than a dropped syllable and would have been much harder to find.
#
# Reported upstream, with this patch offered as the fix:
#
#   https://github.com/xtermjs/xterm.js/issues/6089
#   https://github.com/xtermjs/xterm.js/pull/6090
#
# The PR carries the identical algorithm — verified point by point — against
# xterm.js master, where it passes the project's own suite (2409 passing, 2407
# before) and adds two regression tests that fail without it. What is here and
# not there is the _hL/_hSnap tracing, kept because it is how the cause was
# found; it is inert unless globalThis.__hangulDebug is set. If the PR lands,
# delete this file rather than maintaining it.
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
# one. --replace-fail is deliberate — the build fails loudly instead of quietly
# producing an unpatched editor. When that happens, re-derive the anchors from
# the pristine bundle; the postmortem has the commands.


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
                       "this._compositionSuffix=\"\",this._dataAlreadySent=\"\"}_hL(t,o){if(!globalThis.__hangulDebug)return;try{const m=\"[HANGUL] \"+t+\" \"+JSON.stringify(o);(globalThis.__hangulLog=globalThis.__hangulLog||[]).push(m),console.log(m)}catch(_){}}_hSnap(){return{v:this._textarea.value,ss:this._textarea.selectionStart,se:this._textarea.selectionEnd,ps:this._compositionPosition.start,pe:this._compositionPosition.end,ic:this._isComposing,q:this._hQ?this._hQ.length:0,das:this._dataAlreadySent,w:this._hSentUpTo}}_hSlice(s,e){const f=Math.max(s,this._hSentUpTo||0),t=Math.max(f,e);return this._hSentUpTo=Math.max(this._hSentUpTo||0,t),this._textarea.value.substring(f,t)}compositionstart(){this._hL(\"compositionstart:enter\",this._hSnap()),this._isComposing=!0;" \
        --replace-fail "this._compositionView.textContent=\"\",this._dataAlreadySent=\"\",this._compositionView.classList.add(\"active\")}" \
                       "this._compositionView.textContent=\"\",this._dataAlreadySent=\"\",this._hSentUpTo=Math.min(this._hSentUpTo||0,this._compositionPosition.start),this._compositionView.classList.add(\"active\"),this._hL(\"compositionstart:exit\",this._hSnap())}" \
        --replace-fail "compositionupdate(e){this._compositionView.textContent=" \
                       "compositionupdate(e){this._hL(\"compositionupdate\",{data:e.data,snap:this._hSnap()}),this._compositionView.textContent=" \
        --replace-fail "compositionend(){this._finalizeComposition(!0)}keydown(e){if(this._isComposing||this._isSendingComposition){" \
                       "compositionend(){this._hL(\"compositionend\",this._hSnap()),this._finalizeComposition(!0)}keydown(e){this._hL(\"keydown\",{kc:e.keyCode,key:e.key,snap:this._hSnap()});if(this._isComposing||this._hQ&&this._hQ.length>0){" \
        --replace-fail "_finalizeComposition(e){if(this._compositionView.classList.remove(\"active\"),this._isComposing=!1,e){const e={start:this._compositionPosition.start,end:this._compositionPosition.end},t=this._compositionSuffix;this._isSendingComposition=!0,setTimeout(()=>{if(this._isSendingComposition){let i;if(this._isSendingComposition=!1,e.start+=this._dataAlreadySent.length,this._isComposing)i=this._textarea.value.substring(e.start,this._compositionPosition.start);else{const s=this._textarea.value,r=t.length>0&&s.endsWith(t)?s.length-t.length:s.length;i=s.substring(e.start,Math.max(e.start,r))}i.length>0&&this._coreService.triggerDataEvent(i,!0)}},0)}else{this._isSendingComposition=!1;const e=this._textarea.value.substring(this._compositionPosition.start,this._compositionPosition.end);this._coreService.triggerDataEvent(e,!0)}}" \
                       "_finalizeComposition(e){this._hL(\"finalize:enter\",{wait:e,snap:this._hSnap()}),this._compositionView.classList.remove(\"active\"),this._isComposing=!1;if(e){const p={start:this._compositionPosition.start,end:this._compositionPosition.end},t=this._compositionSuffix,d=this._dataAlreadySent;const cb=()=>{p.start+=d.length;const v=this._textarea.value,b=this._compositionPosition.start>p.start?this._compositionPosition.start:(t.length>0&&v.endsWith(t)?v.length-t.length:v.length),o=this._hSlice(p.start,b);this._hL(\"deferred:FLUSH\",{start:p.start,end:b,out:o}),o.length>0&&this._coreService.triggerDataEvent(o,!0)};(this._hQ=this._hQ||[]).push(cb),setTimeout(()=>{const k=this._hQ.indexOf(cb);k!==-1&&(this._hQ.splice(k,1),cb())},0)}else{if(this._hQ&&this._hQ.length){const q=this._hQ.splice(0,this._hQ.length);this._hL(\"sync:DRAIN\",{n:q.length});for(let n=0;n<q.length;n++)q[n]()}const b=Math.max(this._compositionPosition.end,this._textarea.selectionEnd??this._compositionPosition.end),o=this._hSlice(this._compositionPosition.start,b);this._hL(\"sync:RESULT\",{end:b,out:o}),o.length>0&&this._coreService.triggerDataEvent(o,!0)}}" \
        --replace-fail "_handleAnyTextareaChanges(){if(this._textareaChangeTimer)return;" \
                       "_handleAnyTextareaChanges(){if(this._textareaChangeTimer)return void this._hL(\"textarea:SKIPPED-timer-pending\",this._hSnap());"
    '';
  });
}
