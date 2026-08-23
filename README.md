# webOS Home Customizer

A small Homebrew Channel app for rooted LG webOS TVs (built/tested against
webOS TV 10.3.1, "webOS 26" marketing name). Pick a home-screen layout +
wallpaper preset from an on-TV UI, apply it, or restore stock — no SSH
required once installed.

Built the same night as (and directly reusing the groundwork from)
[mareklarek/webos10-homescreen-customization](https://github.com/mareklarek/webos10-homescreen-customization),
which documents the underlying bind-mount-overlay technique this app
automates. Root-command execution reuses the same bridge
[AmazOff](https://github.com/azoffshowy/AmazOff) uses — Homebrew Channel's
own already-elevated `luna://org.webosbrew.hbchannel.service` service exposes
a generic `exec` method, so this app needs no root service of its own.

## What it does

- Two bundled presets:
  - **Full banner** — fullscreen hero banner, nav/account icons hidden.
  - **Compact** — nav icons kept, banner narrowed to make room, tighter gap
    to the app row.
- **Restore stock** — undoes everything, back to the factory home screen.
- Status line shows which preset (if any) is currently active.

Both presets are pre-rendered (cropped + edge-faded) at build time — the app
does no image processing on-device, it just copies the right bundled files
into place and re-mounts, same as the manual process this automates.

## How it works

Nothing on the signed system partition is ever touched. `apply-current.sh`
(bundled in the app, also symlinked into webosbrew's boot-hook folder so it
survives reboots) copies the real Home-app assets to `/tmp`, overlays the
selected preset's `home.xml` / images / i18n on top, and `mount --bind`s that
over the real (read-only) assets directory, then restarts the Home app. The
UI triggers this by asking Homebrew Channel's own service to run the script
as root — see `js/app.js` / `hbExec()`.

## Status: install flow not yet device-tested

The core mechanism (bind-mount overlay, the `hbchannel.service` `exec`
bridge) is proven — it's the exact technique used by hand, live, on a real
TV, to build these presets in the first place. What is **not** yet verified
end-to-end: the *packaged* `.ipk` install path itself. `opkg` on these TVs
manages system firmware packages (kernel, drivers, ~1800 of them) — homebrew
apps install through a completely different path (Homebrew Channel's own
`install` Luna method), and calling that from a plain SSH shell via
`luna-send` got no response (same silent-failure behavior seen earlier this
session for other Luna services called outside a real registered WAM-app
context) — so this couldn't be test-installed non-interactively tonight.

Practical path to actually install/test it: add this repo to Homebrew
Channel the normal way once it's pushed (Settings → Add repository →
`repo.json`'s raw GitHub URL) and install "Home Customizer" from the app
list like any other homebrew app — that's the same install path every other
app in this ecosystem uses, just not something scriptable from a bare shell.

## Building the .ipk

```sh
./build.sh
```

Hand-rolled (`ar` + `tar`, no `ares-cli` dependency) — produces
`com.arnolderuiter.homecustomizer_<version>_all.ipk` and prints its sha256.
Update that hash in `repo.json`'s `ipkHash` and in the release you attach it
to before publishing.

## Adding more presets

1. Crop a source image to whatever aspect ratio `home.xml`'s `herobanner`
   item uses for that preset (`itemWidth`/`itemHeight`).
2. Render three sizes as PNG: `4k` = exact box size, `2k` = ~0.5x, `hd` =
   ~0.362x, each with a top/bottom (and left, if there's a nav column)
   edge fade baked in so it blends into the surrounding black bars.
3. Drop them + a `home.xml` + `i18n/{nl,en}.json` (with the overlay
   headline/button text blanked, if the banner would clash with it) into a
   new `assets/presets/<name>/` folder.
4. Add a `.tile` button for it in `index.html`.

Not possible via this technique at all (confirmed, hardcoded in the Home
app's compiled `libapp.so`): per-icon text labels on the app row, the icon
focus-zoom animation, and a wallpaper rendered behind the app row itself.

## License

AGPLv3, matching the rooting tooling ([SlopBro](https://github.com/throwaway96/slopbro))
this depends on.
