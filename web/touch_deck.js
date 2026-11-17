// HEXFORGED web: phone control deck.
// On a touch device held upright, the game takes the top of the page and a compact handheld-style deck
// (d-pad, A, B, MENU, RUN) sits along the bottom, so the controls never cover the game. 2026-11-15: the deck
// used to take everything below a 4:3 game; it's now ~38% of the height, so the game view is much bigger.
// Landscape and desktop: the game fills the window as usual and the game's own touch overlay is used.
//
// The export uses canvas resize policy 0 ("None"), so Godot follows the canvas size set here.
// Presses go to the game through window.daemonsDeck (registered by autoload/touch_controls.gd):
//   daemonsDeck("shown", bool)   daemonsDeck("button", action, pressed)   daemonsDeck("dir", x, y)
// Phone keyboard (2026-11-16): the game calls window.daemonsTextInput(title, text, maxLength, placeholder) to
// show a real text box over the page, so the phone's own keyboard can type (Feedback). The answer comes back as
//   daemonsDeck("text", ok, value)     ok = false when cancelled
// Copied next to index.html by tools/serve_web.sh and .github/workflows/web.yml.
(function () {
  "use strict";
  const STYLE = `
    #daemons-deck { position: fixed; left: 0; right: 0; bottom: 0; display: none;
      background: linear-gradient(#22273f, #181c30); border-top: 3px solid #0d0f1c;
      touch-action: none; user-select: none; -webkit-user-select: none; -webkit-touch-callout: none;
      -webkit-tap-highlight-color: transparent; font-family: "Press Start 2P", monospace;
      padding-bottom: env(safe-area-inset-bottom); box-sizing: border-box; }
    #daemons-deck .row { position: absolute; left: 0; right: 0; display: flex; align-items: center;
      justify-content: space-between; padding: 0 7vw; box-sizing: border-box; }
    #daemons-deck .main { top: 7%; }
    #daemons-deck .pills { bottom: calc(5% + env(safe-area-inset-bottom)); justify-content: center; gap: 9vw; }
    #daemons-deck .dpad { position: relative; width: var(--pad); height: var(--pad); }
    #daemons-deck .dpad svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
    #daemons-deck .dpad .press { fill: #000; opacity: 0; }
    #daemons-deck .dpad .press.on { opacity: 0.28; }
    #daemons-deck .dpad .tri { fill: #9aa3c8; transition: transform 40ms; }
    #daemons-deck .dpad .tri.on { fill: #e6e9f8; }
    #daemons-deck .ab { position: relative; width: calc(var(--btn) * 2.3); height: calc(var(--btn) * 2.1); }
    #daemons-deck .btn { position: absolute; width: var(--btn); height: var(--btn); border-radius: 50%;
      border: 3px solid #0d0f1c; color: #f4f2ea; display: flex; align-items: center; justify-content: center;
      font-size: calc(var(--btn) * 0.32); box-shadow: inset 0 -5px 0 rgba(0,0,0,0.3); }
    #daemons-deck .btn.a { right: 0; top: 0; background: #d0484a; }
    #daemons-deck .btn.b { left: 0; bottom: 0; background: #4f7fd0; }
    #daemons-deck .btn small { position: absolute; top: 108%; font-size: 8px; color: #9aa3c8; white-space: nowrap; }
    #daemons-deck .pill { padding: 9px 16px; border-radius: 16px; background: #3a4060; color: #c8cde6;
      border: 3px solid #0d0f1c; font-size: 9px; box-shadow: inset 0 -3px 0 #2a2f48; }
    #daemons-deck .on { transform: translateY(2px); filter: brightness(1.25); box-shadow: none; }
    #daemons-deck .pill.toggled { background: #3f8a52; color: #f4f2ea; }
    #daemons-text { position: fixed; inset: 0; z-index: 1000; background: rgba(8, 10, 20, 0.72);
      display: flex; align-items: flex-start; justify-content: center; padding: 12px; box-sizing: border-box;
      padding-top: calc(12px + env(safe-area-inset-top)); font-family: "Press Start 2P", monospace; }
    #daemons-text .card { width: 100%; max-width: 560px; background: #f4f2ea; color: #1c1c2c;
      border: 3px solid #0d0f1c; box-shadow: 0 0 0 3px #5a6a9a; padding: 12px; box-sizing: border-box; }
    #daemons-text .title { font-size: 11px; margin-bottom: 10px; letter-spacing: 1px; }
    #daemons-text textarea { width: 100%; height: 30vh; min-height: 110px; box-sizing: border-box; resize: none;
      font: 16px/1.4 ui-monospace, Menlo, Consolas, monospace; color: #1c1c2c; background: #fff;
      border: 2px solid #1c1c2c; border-radius: 0; padding: 8px; outline: none; }
    #daemons-text textarea:focus { border-color: #4f7fd0; }
    #daemons-text .row { display: flex; align-items: center; justify-content: space-between; margin-top: 10px; gap: 8px; }
    #daemons-text .count { font-size: 8px; color: #6a6a80; }
    #daemons-text button { font: 10px "Press Start 2P", monospace; padding: 12px 14px; border: 3px solid #0d0f1c;
      background: #3a4060; color: #f4f2ea; box-shadow: inset 0 -3px 0 rgba(0,0,0,0.3); border-radius: 0; }
    #daemons-text button.done { background: #d0484a; }
  `;

  // The D-pad outline in a 100x100 box: arms 32 wide, rounded ends.
  const CROSS = "M38,2 H62 Q66,2 66,6 V34 H94 Q98,34 98,38 V62 Q98,66 94,66 H66 V94 Q66,98 62,98 H38 " +
    "Q34,98 34,94 V66 H6 Q2,66 2,62 V38 Q2,34 6,34 H34 V6 Q34,2 38,2 Z";

  let canvas = null;
  let deck = null;
  let shown = false;

  function send(...args) {
    if (typeof window.daemonsDeck === "function") window.daemonsDeck(...args);
  }

  function buzz() {
    if (navigator.vibrate) navigator.vibrate(8);
  }

  function isTouch() {
    return window.matchMedia("(pointer: coarse)").matches || "ontouchstart" in window;
  }

  function layout() {
    if (!canvas) return;
    const portrait = isTouch() && window.innerHeight > window.innerWidth;
    const w = window.innerWidth;
    let h = window.innerHeight;
    // Deck: about 38% of the height, but never under 250 px (thumb room) or over 360 px (wasted space).
    if (portrait) h = window.innerHeight - Math.round(Math.min(360, Math.max(250, window.innerHeight * 0.38)));
    const dpr = window.devicePixelRatio || 1;
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    deck.style.top = h + "px";
    const room = window.innerHeight - h;
    deck.style.setProperty("--pad", Math.min(w * 0.38, room * 0.6) + "px");
    deck.style.setProperty("--btn", Math.min(w * 0.16, room * 0.25) + "px");
    deck.style.display = portrait ? "block" : "none";
    if (portrait !== shown) {
      shown = portrait;
      window.daemonsDeckShown = portrait;
      send("shown", portrait);
    }
  }

  // Hold-to-press button. Each finger is its own pointer, so A + d-pad at once works.
  function holdButton(el, action) {
    el.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      el.setPointerCapture(e.pointerId);
      el.classList.add("on");
      buzz();
      send("button", action, true);
    });
    const up = () => {
      if (!el.classList.contains("on")) return;
      el.classList.remove("on");
      send("button", action, false);
    };
    el.addEventListener("pointerup", up);
    el.addEventListener("pointercancel", up);
  }

  // D-pad: the direction follows your thumb anywhere on the pad, so you can roll between directions.
  function dpad(el) {
    let id = null;
    let dir = [0, 0];
    const tris = {};
    const arms = {};
    el.querySelectorAll(".tri").forEach((t) => (tris[t.dataset.dir] = t));
    el.querySelectorAll(".press").forEach((a) => (arms[a.dataset.dir] = a));
    const clear = () => [...Object.values(tris), ...Object.values(arms)].forEach((n) => n.classList.remove("on"));
    function update(e) {
      const r = el.getBoundingClientRect();
      const dx = e.clientX - (r.left + r.width / 2);
      const dy = e.clientY - (r.top + r.height / 2);
      let next = [0, 0];
      if (Math.hypot(dx, dy) > r.width * 0.12) {
        next = Math.abs(dx) > Math.abs(dy) ? [Math.sign(dx), 0] : [0, Math.sign(dy)];
      }
      if (next[0] !== dir[0] || next[1] !== dir[1]) {
        dir = next;
        clear();
        const name = dir[0] < 0 ? "left" : dir[0] > 0 ? "right" : dir[1] < 0 ? "up" : dir[1] > 0 ? "down" : "";
        if (name) { tris[name].classList.add("on"); arms[name].classList.add("on"); buzz(); }
        send("dir", dir[0], dir[1]);
      }
    }
    el.addEventListener("pointerdown", (e) => {
      if (id !== null) return;
      e.preventDefault();
      id = e.pointerId;
      el.setPointerCapture(id);
      update(e);
    });
    el.addEventListener("pointermove", (e) => { if (e.pointerId === id) update(e); });
    const release = (e) => {
      if (e.pointerId !== id) return;
      id = null;
      dir = [0, 0];
      clear();
      send("dir", 0, 0);
    };
    el.addEventListener("pointerup", release);
    el.addEventListener("pointercancel", release);
  }

  function build() {
    const style = document.createElement("style");
    style.textContent = STYLE;
    document.head.appendChild(style);
    deck = document.createElement("div");
    deck.id = "daemons-deck";
    deck.innerHTML = `
      <div class="row main">
        <div class="dpad">
          <svg viewBox="0 0 100 100" aria-hidden="true">
            <!-- one solid cross: a dark base for depth, the top face, a center dimple -->
            <path d="${CROSS}" transform="translate(0 4)" fill="#151829" stroke="#0d0f1c" stroke-width="4" stroke-linejoin="round"/>
            <path d="${CROSS}" fill="#3a4060" stroke="#0d0f1c" stroke-width="4" stroke-linejoin="round"/>
            <rect x="38" y="5" width="24" height="3" rx="1.5" fill="#4a5178"/><rect x="5" y="38" width="3" height="24" rx="1.5" fill="#4a5178"/>
            <rect class="press" data-dir="up" x="34" y="2" width="32" height="32"/>
            <rect class="press" data-dir="down" x="34" y="66" width="32" height="32"/>
            <rect class="press" data-dir="left" x="2" y="34" width="32" height="32"/>
            <rect class="press" data-dir="right" x="66" y="34" width="32" height="32"/>
            <circle cx="50" cy="50" r="9" fill="#2c3150"/>
            <circle cx="50" cy="51.5" r="7" fill="#353b5a"/>
            <polygon class="tri" data-dir="up" points="50,12 58,23 42,23"/>
            <polygon class="tri" data-dir="down" points="50,88 58,77 42,77"/>
            <polygon class="tri" data-dir="left" points="12,50 23,42 23,58"/>
            <polygon class="tri" data-dir="right" points="88,50 77,42 77,58"/>
          </svg>
        </div>
        <div class="ab">
          <div class="btn a">A<small>OK</small></div>
          <div class="btn b">B<small>BACK</small></div>
        </div>
      </div>
      <div class="row pills">
        <div class="pill run">RUN</div>
        <div class="pill menu">MENU</div>
      </div>`;
    document.body.appendChild(deck);
    deck.addEventListener("contextmenu", (e) => e.preventDefault());
    dpad(deck.querySelector(".dpad"));
    holdButton(deck.querySelector(".btn.a"), "ui_accept");
    holdButton(deck.querySelector(".btn.b"), "ui_cancel");
    holdButton(deck.querySelector(".pill.menu"), "menu");
    // RUN is a toggle: tap once to run everywhere, again to walk.
    const run = deck.querySelector(".pill.run");
    let running = false;
    run.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      running = !running;
      run.classList.toggle("toggled", running);
      buzz();
      send("button", "run", running);
    });
    // The game registers window.daemonsDeck once it boots; tell it the current state then.
    const hello = setInterval(() => {
      if (typeof window.daemonsDeck === "function") {
        clearInterval(hello);
        send("shown", shown);
        if (running) send("button", "run", true);
      }
    }, 250);
  }

  // A real text box over the game so the phone keyboard can type (game text grids are slow on a touch screen).
  // Keys typed here stop at the overlay so the game doesn't also react to them.
  function textInput(title, text, maxLength, placeholder) {
    closeTextInput();
    const max = Math.max(1, Number(maxLength) || 2000);
    const box = document.createElement("div");
    box.id = "daemons-text";
    box.innerHTML = `
      <div class="card" role="dialog" aria-modal="true">
        <div class="title"></div>
        <textarea autocapitalize="sentences" autocomplete="off" spellcheck="true"></textarea>
        <div class="row">
          <span class="count"></span>
          <span><button type="button" class="cancel">BACK</button> <button type="button" class="done">DONE</button></span>
        </div>
      </div>`;
    box.querySelector(".title").textContent = String(title || "TYPE");
    const area = box.querySelector("textarea");
    area.maxLength = max;
    area.placeholder = String(placeholder || "");
    area.value = String(text || "").slice(0, max);
    const count = box.querySelector(".count");
    const recount = () => { count.textContent = area.value.length + " / " + max; };
    recount();
    area.addEventListener("input", recount);
    const finish = (ok) => {
      const value = area.value;
      closeTextInput();
      if (canvas) canvas.focus();
      send("text", ok, ok ? value : "");
    };
    box.querySelector(".done").addEventListener("click", () => finish(true));
    box.querySelector(".cancel").addEventListener("click", () => finish(false));
    for (const type of ["keydown", "keyup", "keypress"]) {
      box.addEventListener(type, (e) => {
        e.stopPropagation();
        if (type === "keydown" && e.key === "Escape") finish(false);
        if (type === "keydown" && e.key === "Enter" && (e.ctrlKey || e.metaKey)) finish(true);
      });
    }
    for (const type of ["pointerdown", "pointerup", "touchstart", "touchend", "mousedown", "mouseup"]) {
      box.addEventListener(type, (e) => e.stopPropagation());
    }
    document.body.appendChild(box);
    // Android opens the keyboard right away; iOS only does when the box is tapped, so it's large and on top.
    setTimeout(() => { area.focus(); area.setSelectionRange(area.value.length, area.value.length); }, 30);
  }

  function closeTextInput() {
    const old = document.getElementById("daemons-text");
    if (old) old.remove();
  }

  window.daemonsTextInput = textInput;
  window.daemonsTextInputClose = closeTextInput;

  function start() {
    canvas = document.getElementById("canvas");
    if (!canvas) return;
    build();
    layout();
    window.addEventListener("resize", layout);
    window.addEventListener("orientationchange", () => setTimeout(layout, 200));
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
