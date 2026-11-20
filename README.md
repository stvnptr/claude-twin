# Claude Twin

Run two Claude accounts side by side in the Claude desktop app on macOS, for example a personal one and a work one. Each account has its own login, chats, Code-tab sessions and Claude Code settings, and you don't have to log out to switch.

Claude Twin comes as a **Claude skill** (Claude sets it up for you) and as a **standalone shell script** (you run it yourself).

> Unofficial community project. Not affiliated with or endorsed by Anthropic.

## How it works

The Claude desktop app has no account switcher. Claude Twin starts a second instance of the same `Claude.app` with its own data folders:

| What | Main instance | Twin instance |
|---|---|---|
| Login, chats, Code-tab session list | `~/Library/Application Support/Claude` | `~/Library/Application Support/Claude-<Name>` |
| Claude Code config, history, plugins, skills | `~/.claude` | `~/.claude-<name>` |

A small AppleScript launcher, `~/Applications/Claude - <Name>.app`, starts the twin:

```
open -n --env CLAUDE_CONFIG_DIR="$HOME/.claude-<name>" -a /Applications/Claude.app \
     --args --user-data-dir="$HOME/Library/Application Support/Claude-<Name>"
```

- **No duplicates:** the launcher won't start a second copy of the same profile.
- **Its own icon:** it gets a recolored Claude icon with the profile name on it, so you can tell it apart in the Dock and Launchpad.
- **`Claude.app` is never modified:** its code signature and auto-updates keep working.

## Requirements

- **macOS:** with the Claude desktop app installed in `/Applications` or `~/Applications`.
- **Xcode Command Line Tools:** needed only for the custom icon (`xcode-select --install`). Without them you still get a working launcher, just with the generic icon.

## Install

### As a Claude skill (recommended)

Clone it into your Claude Code skills folder:

```bash
git clone https://github.com/stvnptr/claude-twin.git ~/.claude/skills/claude-twin
```

Then ask Claude something like *"I want to use my work Claude account next to my personal one"*. The skill checks your Mac, runs the setup and walks you through the first login.

To install it in the Claude app instead, download `claude-twin.skill` from the [latest release](https://github.com/stvnptr/claude-twin/releases/latest) and upload it in the Claude app's skill settings.

### As a standalone script

```bash
git clone https://github.com/stvnptr/claude-twin.git
cd claude-twin
bash scripts/setup.sh --name Work
```

## Usage

```
bash scripts/setup.sh [options]

  --name NAME    Profile name (default: Work). Letters, digits, spaces, hyphens.
  --hue RADIANS  Icon color shift (default: 3.45 = blue; 2.2 = green, 4.6 = purple)
  --no-icon      Keep the generic launcher icon
  --uninstall    Remove the launcher (data folders are kept)
  --dry-run      Show what would happen, change nothing
  -h, --help     Show help
  --version      Show the version
```

You can create as many profiles as you like (`--name "Client A"`, `--name "Client B"`). Re-running the script for an existing profile replaces only the launcher and never touches its data.

### First login

Both instances are the same app, so macOS sends the browser login callback (`claude://…`) to whichever instance was started first. For the first login of the twin:

1. Quit the main Claude app (Cmd+Q).
2. Open **Claude - Work** and log in with your other account.
3. Reopen the main Claude app.

You only need to do this again if you get logged out.

## Tips

- **Telling the windows apart:** while running, both instances show the normal Claude icon in the Dock and Cmd-Tab, and that can't be changed without breaking the app's signature. Pin the launcher to the Dock, and give each instance a different theme in Settings → Appearance.
- **Updates:** both instances run the same `Claude.app`. After an update, restart both.
- **Don't move or rename `Claude.app`.** If you do, re-run the setup.
- **Sessions can't be moved between accounts.** Your project folders are shared on disk, so ask the old session to write a handoff note and start a new session from it.
- **Terminal CLI:** to use the twin profile from the terminal, add an alias:
  ```bash
  alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
  ```

## Uninstall

```bash
bash scripts/setup.sh --name Work --uninstall
```

This removes the launcher only. Delete `~/Library/Application Support/Claude-Work` and `~/.claude-work` yourself if you no longer need the chats and settings in them.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Claude - Work is already running" but no window | Click its Dock icon, or `pkill -f 'user-data-dir=.*Claude-Work'` and relaunch |
| Login ended up in the wrong instance | See [First login](#first-login) |
| Launcher shows the old or generic icon | Unpin it from the Dock and pin it again |
| "App is damaged and can't be opened" | Re-run the setup to re-sign the launcher |
| "…was not created by claude-twin" | Something else already uses that name. Pick another `--name` |

## Development

```bash
make lint     # shellcheck
make test     # sandboxed install/uninstall test (needs Claude.app installed)
make package  # builds dist/claude-twin.skill
```

Tagging a release (`git tag v1.0.0 && git push --tags`) builds `claude-twin.skill` and attaches it to a GitHub release.

## License

[MIT](LICENSE)
