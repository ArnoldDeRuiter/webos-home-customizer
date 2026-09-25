# AGENTS.md

Read `~/git/personal/slopbro/TV-HANDOVER.md` first for the TV's IP/SSH
access, CDP, root exec bridge, and standing rules. This file covers what's
specific to this repo.

## What this is

`type: web` Homebrew app (`com.arnolderuiter.homecustomizer`) — pick/apply a
home-screen layout+wallpaper preset (bind-mount overlay over the stock
Flutter Home app) without needing SSH. Packages the same technique
documented and used manually in `../lgtv/homescreen/` — that's the source
of truth for the underlying mechanism if something here needs debugging.

## Build

```sh
sh build.sh
```

Hand-rolled deterministic `.ipk` build (`ar`+`tar`, `--mtime`-pinned for
reproducibility). Version from `appinfo.json` — this app is **not** on the
auto-derive-from-tag CI pattern the other 4 apps use; version bumps here are
still manual, and its Homebrew "Add repository" URL is still the older raw
`master/repo.json` path, not the asset-based one. Don't assume otherwise.

## Testing changes live

`scp` changed files to
`/media/developer/apps/usr/palm/applications/com.arnolderuiter.homecustomizer/`
on the TV, apply a preset, verify before committing.

## Rules

- Never `git push` — Captain pushes himself.
