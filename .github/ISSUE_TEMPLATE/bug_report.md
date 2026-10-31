---
name: Bug report
about: Something in Ember doesn't work as expected
---

## What happened

<!-- What you did, what you expected, what you saw instead. -->

## Your Mac

- Mac model (Apple menu > About This Mac):
- macOS version:
- Displays (built-in, external, how connected):
- Ember version: <!-- defaults read /Applications/Ember.app/Contents/Info.plist CFBundleShortVersionString -->

## Output

Run these in Terminal from your Ember folder and paste the results:

```
swift scripts/show-displays.swift
/Applications/Ember.app/Contents/MacOS/Ember --check-config
/usr/bin/log show --last 10m --info --predicate 'subsystem == "dev.unlux.ember"' | tail -30
```

Screenshots can't show Ember's tint, so describe what the screen looks like.
