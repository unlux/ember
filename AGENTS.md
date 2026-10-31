# Ember: guide for coding agents

Ember is a macOS menu-bar app that tints every display red by rewriting each
display's colour lookup table. People install it on their own Macs from
source and change it by asking their coding agent. This file is for that
agent.

## Words used in the code

- **Tint**: per-channel multipliers (red, green, blue) applied to a table.
- **Redness**: the slider value, 0 (normal colours) to 1 (pure red), mapped
  to a tint by `Tint.redness(_:)`.
- **Baseline**: a display's normal colour table, which every tint scales.
- **Exclusion**: a recurring time the schedule keeps red off, such as a
  meeting.

## Where a change goes

| The person wants… | Change |
|---|---|
| Different red hours, meetings or fade length | Their `~/.config/ember/config.json`, not the repo. Format: `config.example.json` and the doc comment on `Config` in `Sources/EmberCore/Config.swift`. |
| New logic that needs no AppKit or CoreGraphics (time maths, colour maths, parsing) | `Sources/EmberCore/`, with Swift Testing tests in `Tests/EmberCoreTests/` |
| A menu item or menu wording | `Sources/Ember/StatusItemController.swift` |
| When red turns on or off, or something remembered between launches | `Sources/Ember/EmberController.swift` |
| How colours reach the displays | `Sources/Ember/GammaController.swift` |
| A new setting in config.json | `Config.parse` (strict: add the key to `requireOnly`), `Config.summary`, `config.example.json` and `ConfigTests` |

## Rules

- Build on Apple's public frameworks only. Friends install Ember without
  reading the code, so it stays free of network code, private APIs,
  third-party packages, entitlements and permission prompts. If a request
  needs any of these, tell the person what it would add and ask first.
- Route every colour-table write through `GammaController`. Its rule:
  baselines are read only straight after `CGDisplayRestoreColorSyncSettings()`,
  so a tinted table can never be captured as normal.
- Keep app code `@MainActor`. Add timers to `RunLoop.main` in `.common`
  mode so they keep firing while the menu is open (`repeatingTimer` in
  `EmberController` does this).
- macOS restores a process's colour tables when it exits, even on a crash.
  Quitting is always safe; a new feature needs no cleanup path of its own
  beyond `EmberController.shutdown()`.
- When adding a third-party asset (icon, curve, code), credit it in
  `THIRD_PARTY_NOTICES.md` with its licence.

## Checking your work

You can't see the tint: screenshots and screen recordings are captured
before the colour table applies. Check it with the display probe, and ask
the person to confirm anything visual (menu layout, how a colour looks).

```bash
scripts/test.sh                                    # unit tests
scripts/install.sh                                 # build, install to /Applications, restart Ember
swift scripts/show-displays.swift                  # each display: normal, tinted or full red
/Applications/Ember.app/Contents/MacOS/Ember --check-config   # validate config.json, exit 1 if broken
pkill -TERM -x Ember; open -a Ember                # restart after editing config.json
/usr/bin/log show --last 5m --info --predicate 'subsystem == "dev.unlux.ember"'
```

A change is done when `scripts/test.sh` passes, `scripts/install.sh`
succeeds, and the probe shows the state you expect. In zsh, `log` is a
shell builtin; use `/usr/bin/log`.
