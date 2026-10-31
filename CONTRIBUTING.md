# Contributing

Pull requests are welcome, including ones written with a coding agent.

## Setup

A Mac on macOS 13 or later with Apple's command line tools
(`xcode-select --install`). Fork the repository and clone your fork.

## Making a change

1. Read [AGENTS.md](AGENTS.md). It says where each kind of change goes and
   the rules Ember keeps, whether you're a person or an agent.
2. Branch from `main`.
3. Run `scripts/format.sh`, then `scripts/test.sh`.
4. Run `scripts/install.sh` and try the change on your Mac. Screenshots
   can't show the tint, so for colour changes use
   `swift scripts/show-displays.swift`.
5. Add a line under a new heading at the top of [CHANGELOG.md](CHANGELOG.md)
   if people will notice the change.
6. Open a pull request and fill in the template. CI checks formatting,
   tests and the build on every pull request; it needs to pass.

Keep a pull request to one change. If you add an icon, image or code from
elsewhere, credit it with its licence in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Reporting a bug

Open an issue with the bug report template. It asks for the output of
three commands that show what Ember sees.
