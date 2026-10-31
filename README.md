# Ember

A menu-bar app for late-night work. Click the moon in the menu bar and every
display fades to red; click it again and colours come back.

- Left click: red on or off. The icon is a filled moon while red is on.
- Right click or Control-click opens the menu:
  - Red Screen
  - Redness slider: 0% is normal colours, 100% is pure red, with warm
    white, amber and orange in between. It applies live, and moving it
    while red is off turns red on.
  - Follow Schedule, with the schedule and its next change
  - Open at Login
  - Quit Ember
- Schedule, on by default: red from 8 PM to 7 AM, off for the weekday
  standup (9 to 10 PM) and Thursday's sprint review (9 to 10:30 PM). A click
  overrides the schedule until its next change. For example, if standup
  ends at 9:40, click to bring red back; the schedule takes over again at
  the next boundary.
- Opens at login. macOS registers it the first time the installed copy runs.
- Works entirely offline. It has no network code and no updater; it changes
  only when you rebuild it.

## Changing things

Schedule, default redness and fade length are in
`Sources/EmberCore/Config.swift`. Edit, then run `scripts/install.sh`.

## How it works

Each display has a colour lookup table that maps every input level to an
output level, per channel. Ember reads each display's normal table and
scales green and blue down (to zero at 100% redness), then writes it back
with `CGSetDisplayTransferByTable`. That is public CoreGraphics API. At 100%,
white becomes pure red and the panel emits no blue or green light.

It uses no private frameworks, asks for no permissions and has no
third-party code. It writes one preference file
(`~/Library/Preferences/dev.unlux.ember.plist`).

Safety comes from macOS: the window server undoes a process's colour tables
when that process exits, including on a crash or `kill -9`. Quitting Ember
always gives you normal colours back. Other apps resetting their own colours
don't touch Ember's.

Ember puts red back if displays change (plugging in a monitor, changing
resolution), after sleep and wake, and every 3 seconds while red is on if a
display's table no longer matches. The 3-second check only reads, and writes
only on a mismatch.

Night Shift doesn't conflict: it works at a different stage of the display
pipeline, and toggling it while Ember is red leaves Ember's tables alone
(tested on macOS 27.0.1). The two stack. At 100% redness Night Shift has
nothing left to remove; below 100% it adds its own warmth on top.

Screenshots and screen recordings don't show the tint. The table is applied
after the image is captured.

## Build and install

Needs macOS 13 or later and the Xcode Command Line Tools (`xcode-select
--install`). Full Xcode is not needed.

```bash
scripts/test.sh      # unit tests
scripts/install.sh   # build, replace /Applications/Ember.app, start it
scripts/make-icon.sh # only after editing Resources/icon/AppIcon.svg
```

`install.sh` quits a running Ember first and moves any previous copy to the
Trash. A locally built app carries no quarantine flag, so Gatekeeper allows it
without `xattr` or System Settings changes.

## Troubleshooting

- Logs: `/usr/bin/log stream --info --predicate 'subsystem == "dev.unlux.ember"'`.
  Each launch logs the Open at Login status.
- Login item: System Settings > General > Login Items lists Ember under
  "Open at Login".
- Colours stuck after something odd: quit Ember. macOS restores them on exit.
- On some Macs, macOS 26 and later accept a colour-table change but don't show
  it on the built-in panel (Apple bugs FB18559786, FB19136488, FB22273730).
  Turning off automatic brightness helps on many of them. External monitors
  have not been affected in testing.

Credits for the icon and colour steps are in `THIRD_PARTY_NOTICES.md`.
