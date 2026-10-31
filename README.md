# Ember

[![CI](https://github.com/unlux/ember/actions/workflows/ci.yml/badge.svg)](https://github.com/unlux/ember/actions/workflows/ci.yml)

A menu-bar app for late-night work. Click the moon in the menu bar and every
display fades to red; click it again and colours come back.

- Left click: red on or off. The moon is filled while red is on.
- Right click or Control-click: Red Screen, the Redness slider (0% normal
  to 100% pure red), Follow Schedule with its next change, Open at Login,
  Quit.
- Schedule: red from 8 PM to 7 AM by default. You can add times when red
  stays off, such as meetings. A click overrides the schedule until its
  next change.
- Opens at login, and works entirely offline: no network code, no updater,
  no permission prompts, no third-party code.

## Install

You need a Mac on macOS 13 or later.

```bash
xcode-select --install          # Apple's command line tools, once (no full Xcode needed)
git clone https://github.com/unlux/ember.git ~/code/ember
cd ~/code/ember && scripts/install.sh
```

Ember appears as a moon in the menu bar. Building it yourself means macOS
trusts it without any security prompts.

If you use a coding agent, you can instead tell it: "Install Ember from
github.com/unlux/ember and set it up for me." It reads `AGENTS.md`.

## Make it yours

Your settings live in `~/.config/ember/config.json`, outside the repository,
so updates never overwrite them. Start from the example:

```bash
mkdir -p ~/.config/ember && cp config.example.json ~/.config/ember/config.json
```

```json
{
  "red": { "from": "20:00", "to": "07:00" },
  "exclusions": [
    { "name": "Standup", "days": ["mon", "tue", "wed", "thu", "fri"], "from": "21:00", "to": "22:00" }
  ],
  "fadeSeconds": 0.6
}
```

Times are 24-hour, in your Mac's time zone. Every key is optional. Check
the file, then restart Ember:

```bash
/Applications/Ember.app/Contents/MacOS/Ember --check-config
pkill -TERM -x Ember; open -a Ember
```

If the file has a mistake, Ember uses the default schedule and says why in
its menu.

## Update

```bash
cd ~/code/ember && git pull && scripts/install.sh
```

## How it works

Each display has a colour lookup table. Ember keeps the red channel and
scales green and blue down (to zero at 100%), using public CoreGraphics
calls. At 100%, the screen emits no blue or green light. macOS restores the
normal tables whenever Ember quits, even if it crashes.

Night Shift doesn't conflict with Ember; the two stack. At 100% redness,
Night Shift has nothing left to change.

On some Macs, macOS 26 and later ignore colour-table changes on the
built-in screen (Apple bugs FB18559786, FB19136488, FB22273730). Turning
off automatic brightness in System Settings > Displays helps on many of
them. External monitors have not been affected.

## Contributing

Pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Coding
agents: start with [AGENTS.md](AGENTS.md).

## Licence

[MIT](LICENSE). Credits for the icon and colour steps are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
