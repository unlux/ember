# Changelog

## 1.2 (2026-11-01)

- Settings move to `~/.config/ember/config.json`, outside the repository, so
  updates never overwrite them. Every key is optional.
- `Ember --check-config` validates that file; a broken file shows its error
  in the menu, and Ember falls back to the default schedule.
- `scripts/show-displays.swift` reports whether each display is tinted.
- Open-source release: MIT licence, contributing guide, CI, formatter.

## 1.1 (2026-11-01)

- Redness slider in the menu, from normal colours to pure red.
- Half-second fade when red turns on or off.
- Schedule with times that keep red off, such as meetings.
- App icon.

## 1.0 (2026-10-31)

- Menu-bar toggle that turns every display red, Open at Login, and recovery
  after sleep and display changes.
