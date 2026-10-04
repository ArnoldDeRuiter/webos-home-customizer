# Boot speed research — custom home screen (2026-10-04)

Question: can the custom home screen apply sooner after a cold boot, without
any risk of bricking or losing remote (SSH/telnet) access? No physical
recovery options are available, so remote recovery must keep working.

Everything below was gathered **read-only** on the TV (files, logs, process
list, `getBootStatus`). Nothing was changed.

Note: the TV actually runs the personal version from `../lgtv/homescreen/`
(`tld.my.customhome`, hook `/var/lib/webosbrew/init.d/01-custom-homescreen`
→ its `apply.sh`), not this repo's `com.arnolderuiter.homecustomizer`, which
isn't installed. Same overlay technique.

## Boot chain

1. `bootd` raises boot signals (`/var/log/bootd.log`).
2. Homebrew Channel's service registers a persistent activityManager activity
   `org.webosbrew.hbchannel.service.autostart`, triggered on
   `luna://com.webos.bootManager/getBootStatus` signal `core-boot-done`,
   calling `luna://org.webosbrew.hbchannel.service/autostart`.
3. `autostart` spawns `/var/lib/webosbrew/startup.sh` (run-once lock
   `/tmp/webosbrew_startup`): failsafe flag + `sleep 2`, telnetd, dropbear
   (SSH), elevation, then `run-parts /var/lib/webosbrew/init.d`.
4. `01-custom-homescreen` (`apply.sh`) mounts the overlay and `pkill`s
   `com.webos.app.home`, which relaunches with the custom layout.

The devmode route (`/etc/systemd/system/scripts/devmode.sh` →
`start-devmode.sh`) isn't used on this TV; only `binaries-armv71` exists in
the devmode service dir.

## Timeline of the 2026-10-04 13:39:44 cold boot (seconds of uptime)

| Event | Uptime | Source |
|---|---|---|
| `bootd` start | 10.2 | bootd.log |
| `SIGNAL_core-boot-done` | 10.7 | bootd.log |
| `SIGNAL_init-boot-done` | 11.0 | bootd.log |
| `tv-ready` | 12.2 | bootd.log |
| Home app launch requested | 14.0 | bootd.log |
| `firstapp-launched` (Home visible) | 15.3 | bootd.log |
| `SIGNAL_minimal-boot-done` | 18.3 | bootd.log |
| Homebrew Channel service process start | 22.9 | `/proc/<pid>/stat` |
| `startup.sh` start (`/tmp/webosbrew_startup` mtime) | ~25.0 | file mtime |
| `init.d` hook runs | 27.4 | homescreen-boot-timing.log |
| Home restarted with custom layout | ~29–30 | estimate |
| Running activitymanager instance start | 31.1 | `/proc/<pid>/stat` |
| `SIGNAL_rest-boot-done` / `boot-done` | 31.0 / 38.0 | bootd.log |

The timing log shows the hook consistently at 23–28s uptime across ~20 boots.
Most logged boots are around 06:00, probably the TV's nightly standby
maintenance. Normal power-ons with Quick Start+ resume from standby without a
reboot, so the overlay stays mounted and there's no delay.

## Findings

- The script itself takes well under a second. The ~13–15s of stock home
  screen comes entirely from **when** the hook runs.
- The trigger signal `core-boot-done` fires at **10.7s**, but the Homebrew
  Channel service only starts at **22.9s**. The bottleneck is webOS's own
  activity/service startup, not the choice of signal.
- The running activitymanager instance started at 31.1s, after the HB
  service. Either an earlier instance ran and restarted, or something else
  launched the HB service. Syslog (`/var/log/messages*`, ~2h rotation) had
  already rotated past that boot, so this gap is unexplained.
- `getBootStatus` signals available for triggers: `datastore-init-start`,
  `init-boot-done`, `minimal-boot-done`, `core-boot-done`, `rest-boot-done`,
  `boot-done`, `snapshot-resume-done` (TV boots from a snapshot image). There's
  no `tv-ready` signal there.

## Option considered: earlier activity calling hbchannel `exec`

Idea: a persistent activity on an earlier signal, calling
`luna://org.webosbrew.hbchannel.service/exec` to run `apply.sh` before Home
launches (no `pkill`, no flicker), with the `init.d` hook as an idempotent
fallback.

Safety analysis (verified):
- SSH and telnet come from `startup.sh` via `autostart`. This option leaves
  that chain untouched.
- The **only** definition of the HB service is the elevated one in
  `/var/luna-service2-dev/services.d/org.webosbrew.hbchannel.service.service`
  (jail-free `run-js-service`, on the persistent `/var` partition, running as
  root). An early call either starts that same root service or fails because
  it's not available yet. It can't create a non-root instance that would make
  `autostart` answer "Not running as root" and skip SSH/telnet.
- `startup.sh`'s run-once lock makes a second trigger harmless.
- A probe could be fully harmless (`echo uptime >> log`, no mount/pkill).
  Rollback is `luna://com.webos.service.activitymanager/cancel` over SSH.

Verdict: **not worth building.** Any activity goes through the same
activitymanager, which evidently runs late, so it would most likely fire no
earlier than today's path. The remaining possible gain (~2–3s: Node service
start plus `startup.sh`'s `sleep 2`) sits in the part that must not be
touched.

## Never touch

`/var/lib/webosbrew/startup.sh`, `jumpstart.sh`, `elevate-service`, the HB
service files: root chain, hash-checked by Homebrew Channel, and the
`sleep 2` is the crash failsafe. Renaming hooks gains nothing (`01-` already
runs first).

## Possible follow-up (not done)

To explain the 22.9s HB service start: add one append-only line to the
hook's existing timing log, recording the HB service's parent process and
the activitymanager's start time, then compare after the next natural
reboot.
