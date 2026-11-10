// DAEMONS web: phone control deck.
// On a touch device held upright, the game becomes a 4:3 screen at the top of the page and a handheld-
// style deck (d-pad, A, B, MENU, RUN) fills the space below, so the controls never cover the game.
// Landscape and desktop: the game fills the window as usual and the game's own touch overlay is used.
//
// The export uses canvas resize policy 0 ("None"), so Godot follows the canvas size set here.
// Presses go to the game through window.daemonsDeck (registered by autoload/touch_controls.gd):
//   daemonsDeck("shown", bool)   daemonsDeck("button", action, pressed)   daemonsDeck("dir", x, y)
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
    #daemons-deck .main { top: 12%; }
    #daemons-deck .pills { bottom: calc(10% + env(safe-area-inset-bottom)); justify-content: center; gap: 9vw; }
    #daemons-deck .dpad { position: relative; width: var(--pad); height: var(--pad); }
    #daemons-deck .arm { position: absolute; background: #3a4060; border: 3px solid #0d0f1c;
      box-shadow: inset 0 -4px 0 #2a2f48; }
    #daemons-deck .arm.v { left: 33.3%; width: 33.4%; height: 100%; top: 0; border-radius: 8px; }
    #daemons-deck .arm.h { top: 33.3%; height: 33.4%; width: 100%; left: 0; border-radius: 8px; }
    #daemons-deck .hub { position: absolute; left: 33.3%; top: 33.3%; width: 33.4%; height: 33.4%;
      background: #3a4060; }
    #daemons-deck .tri { position: absolute; width: 0; height: 0; border: calc(var(--pad) * 0.06) solid transparent; }
    #daemons-deck .tri.up { left: 50%; top: 8%; transform: translateX(-50%); border-bottom-color: #9aa3c8; border-top: 0; }
    #daemons-deck .tri.down { left: 50%; bottom: 8%; transform: translateX(-50%); border-top-color: #9aa3c8; border-bottom: 0; }
    #daemons-deck .tri.left { top: 50%; left: 8%; transform: translateY(-50%); border-right-color: #9aa3c8; border-left: 0; }
    #daemons-deck .tri.right { top: 50%; right: 8%; transform: translateY(-50%); border-left-color: #9aa3c8; border-right: 0; }
    #daemons-deck .tri.on { filter: brightness(1.8); }
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
  `;

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
    if (portrait) h = Math.min(Math.round(w * 3 / 4), Math.round(window.innerHeight * 0.6));
    const dpr = window.devicePixelRatio || 1;
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    deck.style.top = h + "px";
    const room = window.innerHeight - h;
    deck.style.setProperty("--pad", Math.min(w * 0.4, room * 0.55) + "px");
    deck.style.setProperty("--btn", Math.min(w * 0.17, room * 0.24) + "px");
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
    el.querySelectorAll(".tri").forEach((t) => (tris[t.dataset.dir] = t));
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
        Object.values(tris).forEach((t) => t.classList.remove("on"));
        const name = dir[0] < 0 ? "left" : dir[0] > 0 ? "right" : dir[1] < 0 ? "up" : dir[1] > 0 ? "down" : "";
        if (name) { tris[name].classList.add("on"); buzz(); }
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
      Object.values(tris).forEach((t) => t.classList.remove("on"));
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
          <div class="arm v"></div><div class="arm h"></div><div class="hub"></div>
          <div class="tri up" data-dir="up"></div><div class="tri down" data-dir="down"></div>
          <div class="tri left" data-dir="left"></div><div class="tri right" data-dir="right"></div>
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
