(function () {
  "use strict";

  var APP_DIR = "/media/developer/apps/usr/palm/applications/com.arnolderuiter.homecustomizer";
  var STATE_FILE = APP_DIR + "/state/current_preset.txt";
  var APPLY_SCRIPT = APP_DIR + "/apply-current.sh";
  var BOOT_HOOK = "/var/lib/webosbrew/init.d/01-homecustomizer";
  var ASSETS_DIR = "/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets";

  function $(id) { return document.getElementById(id); }

  function log(msg) {
    var el = $("log");
    if (el) { el.textContent += msg + "\n"; el.scrollTop = el.scrollHeight; }
  }

  function setLoading(on, text) {
    var el = $("loading");
    if (!el) { return; }
    $("loadText").textContent = text || "Working…";
    el.style.display = on ? "block" : "none";
  }

  // Same bridge homebrew apps commonly use to run root shell commands via
  // Homebrew Channel's own already-elevated service -- no separate root
  // service needed for this app.
  function hbExec(command, cb, timeoutMs) {
    log("$ " + command);
    if (!window.webOS || !webOS.service || typeof webOS.service.request !== "function") {
      cb({ returnValue: false, errorText: "webOS.service.request not available (not running on-device?)" });
      return;
    }
    var done = false;
    var timer = null;
    if (typeof timeoutMs === "number" && timeoutMs > 0) {
      timer = setTimeout(function () {
        if (!done) { done = true; cb({ returnValue: false, errorText: "Timeout" }); }
      }, timeoutMs);
    }
    webOS.service.request("luna://org.webosbrew.hbchannel.service", {
      method: "exec",
      parameters: { command: command },
      onComplete: function (res) {
        if (done) { return; }
        done = true;
        if (timer) { clearTimeout(timer); }
        cb(res);
      }
    });
  }

  function refreshStatus() {
    var cmd = "cat " + STATE_FILE + " 2>/dev/null || echo none; " +
      "[ -L " + BOOT_HOOK + " ] && echo hooked || echo unhooked";
    hbExec(cmd, function (res) {
      var out = (res && res.stdoutString) ? res.stdoutString.trim().split("\n") : ["none", "unhooked"];
      var preset = (out[0] || "none").trim();
      var hooked = (out[1] || "unhooked").trim() === "hooked";
      renderStatus(preset, hooked);
    }, 8000);
  }

  function renderStatus(preset, hooked) {
    var el = $("status");
    var tiles = document.querySelectorAll(".tile");
    for (var i = 0; i < tiles.length; i++) {
      tiles[i].classList.toggle("active", tiles[i].getAttribute("data-preset") === preset && hooked);
    }
    if (preset === "none" || !hooked) {
      el.textContent = "Currently: stock home screen";
    } else {
      el.textContent = "Currently: \"" + preset + "\" preset active (persists across reboots)";
    }
  }

  function applyPreset(name) {
    setLoading(true, "Applying \"" + name + "\"…");
    var cmd = [
      "mkdir -p " + APP_DIR + "/state",
      "echo " + name + " > " + STATE_FILE,
      "chmod +x " + APPLY_SCRIPT,
      "ln -sf " + APPLY_SCRIPT + " " + BOOT_HOOK,
      "sh " + APPLY_SCRIPT
    ].join(" && ");
    hbExec(cmd, function (res) {
      setLoading(false);
      log(res && res.returnValue ? "OK" : "FAILED: " + (res && res.errorText || "unknown error"));
      refreshStatus();
    }, 20000);
  }

  function restoreStock() {
    setLoading(true, "Restoring stock home screen…");
    var cmd = [
      "rm -f " + BOOT_HOOK,
      "rm -f " + STATE_FILE,
      "umount " + ASSETS_DIR + " 2>/dev/null || true",
      "pkill -f com.webos.app.home || true"
    ].join("; ");
    hbExec(cmd, function (res) {
      setLoading(false);
      log(res && res.returnValue ? "OK" : "FAILED: " + (res && res.errorText || "unknown error"));
      refreshStatus();
    }, 20000);
  }

  // Minimal linear D-pad focus mover -- not a full spatial-navigation lib,
  // just enough for this app's simple vertical/horizontal button list.
  function setupNav() {
    var order = [];
    document.querySelectorAll(".tile, .wide, summary").forEach(function (el) {
      order.push(el);
    });
    order[0] && order[0].focus();

    document.addEventListener("keydown", function (e) {
      var idx = order.indexOf(document.activeElement);
      if (idx === -1) { idx = 0; }
      switch (e.keyCode) {
        case 39: // right
        case 40: // down
          idx = Math.min(order.length - 1, idx + 1);
          order[idx].focus();
          e.preventDefault();
          break;
        case 37: // left
        case 38: // up
          idx = Math.max(0, idx - 1);
          order[idx].focus();
          e.preventDefault();
          break;
        case 13: // OK / Enter
          document.activeElement && document.activeElement.click();
          break;
        default:
          break;
      }
    });
  }

  function bindUi() {
    document.querySelectorAll(".tile").forEach(function (tile) {
      tile.addEventListener("click", function () {
        applyPreset(tile.getAttribute("data-preset"));
      });
    });
    $("restoreBtn").addEventListener("click", restoreStock);
  }

  document.addEventListener("DOMContentLoaded", function () {
    bindUi();
    setupNav();
    refreshStatus();
  });
})();
