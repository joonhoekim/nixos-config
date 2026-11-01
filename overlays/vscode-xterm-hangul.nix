# Fast Hangul typing in VS Code's terminal drops syllables ("알겠습니다." → "알겠습다."): xterm.js guards every pending
# composition send with one shared boolean, so a sync finalize cancels them all. The patch turns it into a FIFO queue.
# Full story: docs/postmortems/2026-08-05-vscode-terminal-hangul.md, docs/overlays.md. Upstream PR xtermjs/xterm.js#6090 — if it lands, delete this.


final: prev:

# Linux only: on darwin VS Code is an .app bundle, so the path below does not exist and substituteInPlace would fail the build.
# Anchors are literal slices of minified VS Code output; --replace-fail makes an update fail loudly instead of shipping unpatched.
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
