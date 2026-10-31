# Ember

A menu-bar app for late-night work. Click the moon in the menu bar and every
display turns pure red; click it again and colours come back.

- Left click: red on or off. The icon is a filled moon while red is on.
- Right click or Control-click: Red Screen, Open at Login, Quit Ember.
- Remembers whether red was on, and comes back that way after login.
- Opens at login. macOS registers it the first time the installed copy runs.

## How it works

Each display has a colour lookup table that maps every input level to an
output level, per channel. Ember reads each display's normal table, keeps the
red channel, sets green and blue to zero, and writes it back with
`CGSetDisplayTransferByTable`. That is public CoreGraphics API. White becomes
pure red and the panel stops emitting blue and green light.

It has no network code, no private frameworks, no permissions prompts and no
third-party dependencies. It writes one preference file
(`~/Library/Preferences/dev.unlux.ember.plist`).

Safety comes from macOS: the window server undoes a process's colour tables
when that process exits, including on a crash or `kill -9`. Quitting Ember
always gives you normal colours back.

Ember also puts red back if displays change (plugging in a monitor, changing
resolution), after sleep and wake, and every 3 seconds while red is on if a
display's table no longer matches. The 3-second check only reads, and writes
only on a mismatch.

Screenshots and screen recordings don't show the red. The table is applied
after the image is captured.

## Build and install

Needs macOS 13 or later and the Xcode Command Line Tools (`xcode-select
--install`). Full Xcode is not needed.

```bash
scripts/test.sh      # unit tests
scripts/install.sh   # build, replace /Applications/Ember.app, start it
```

`install.sh` quits a running Ember first and moves any previous copy to the
Trash. A locally built app carries no quarantine flag, so Gatekeeper allows it
without `xattr` or System Settings changes.

## Changing the colour

The tint is `Tint.night` in `Sources/EmberCore/GammaTable.swift`: per-channel
multipliers from 0 to 1. `Tint(red: 0.6, green: 0, blue: 0)` would be a
dimmer red. Change it and re-run `scripts/install.sh`.

## Troubleshooting

- Logs: `/usr/bin/log stream --info --predicate 'subsystem == "dev.unlux.ember"'`
- Login item: System Settings > General > Login Items shows Ember under "Open at Login".
- Colours stuck after something odd: quit Ember. macOS restores them on exit.
- On some Macs, macOS 26 and later accept a colour-table change but don't show
  it on the built-in panel (Apple bugs FB18559786, FB19136488, FB22273730).
  Turning off automatic brightness helps on many of them. External monitors
  have not been affected in testing.
