---
name: claude-twin
description: Set up a second Claude account (e.g. personal + work) side by side in the Claude desktop app on macOS, each with its own login, chats, Code-tab sessions and Claude Code config, using a launcher app with its own badged icon. Use this whenever someone on a Mac wants to use two Claude accounts at once, switch between a personal and a company/work/client Claude account without logging out, run a second Claude desktop instance, or asks how to keep work and private Claude separate — even if they don't say "launcher" or "second instance". Also use it to troubleshoot or remove such a setup (wrong account after login, missing launcher icon, "already running" notice).
---

# Claude Twin — a second Claude account on macOS

The Claude desktop app has no built-in account switcher. What works reliably is starting a second instance of the same `Claude.app` with its own data folders:

- `--user-data-dir=~/Library/Application Support/Claude-<Name>` gives the instance its own login, cookies, chats and Code-tab session list.
- `CLAUDE_CONFIG_DIR=~/.claude-<name>` gives its Code tab its own Claude Code settings, history, plugins, skills and org policies.

A small AppleScript launcher app (`~/Applications/Claude - <Name>.app`) starts that instance, refuses to start a duplicate, and can carry a badged icon so it is easy to find in the Dock and Launchpad. `Claude.app` itself is never modified, so its signature and auto-update stay intact — this is the main reason to prefer this setup over copying or patching the app.

## Workflow

1. **Check the machine.** Confirm macOS and that `Claude.app` exists in `/Applications` or `~/Applications`. If it's missing, ask them to install the desktop app first.

2. **Agree on the profile name.** Default is `Work`. Ask only if the context suggests something else (a client name, "Personal" when the main app is the work account). The name ends up in the launcher title, the data folder and the badge text, so keep it short (letters, digits, spaces, hyphens; under ~8 characters looks best on the icon).

3. **Check for an existing setup** before creating anything: look for `~/Applications/Claude - <Name>.app`, `~/Library/Application Support/Claude-<Name>` and `~/.claude-<name>`. If they exist, this is a re-run — the script only replaces the launcher and leaves the data folders alone, but say so before running it.

4. **Run the setup script:**
   ```bash
   bash <skill-dir>/scripts/setup.sh --name "Work"
   ```
   Options: `--no-icon` (keep the generic launcher icon), `--hue <radians>` (badge color shift, default 3.45 = blue; e.g. 2.2 = green, 4.6 = purple), `--dry-run` (print what would happen), `--help`. The icon step needs `swift` (Xcode Command Line Tools); if it isn't there the script skips the icon and says so — offer `xcode-select --install` and a re-run, or carry on without an icon. The script refuses to overwrite an app at the launcher path that it didn't create; if that happens, pick another name rather than deleting the existing app.

5. **First login — the one tricky step.** Tell the user to quit the main Claude app (Cmd+Q) *before* opening the new launcher and logging in. Both instances are the same app, so macOS hands the `claude://` login callback to whichever instance started first; with the main one closed, it can only land in the new instance. After logging in, they can reopen the main app. This is only needed again if they're ever logged out.

6. **Verify** with `ps -axo command | grep '[C]laude.app/Contents/MacOS/Claude'`: there should be one line without `--user-data-dir` (main) and one with `Claude-<Name>`. Ask them to check the account name in each window's settings.

7. **Tell them the practical tips** below, briefly — these are the things people otherwise discover the hard way.

## Practical tips to pass on

- **Telling windows apart:** the running window still shows the normal Claude icon in the Dock and Cmd-Tab (a running app's icon can't be changed from outside without breaking the signature). Pin the launcher to the Dock, and set a different theme in each instance (e.g. dark for work, light for personal) under Settings → Appearance.
- **Updates:** both instances run the same `Claude.app`. After an update, restart both, otherwise the one left running stays on the old version.
- **Don't move or rename `Claude.app`**, or the launcher won't find it. Re-run the script if it moved.
- **Sessions don't move between accounts.** The project folder is shared on disk, so to continue work in the other account, have the old session write a short handoff note into the project and start a new session from it. Moving company work into a personal account may conflict with company policy — worth checking.
- **Terminal `claude` CLI** (if they use it): add an alias to `~/.zshrc`, e.g. `alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'` (use the profile's lowercase, hyphenated name).
- **Skills and plugins are per profile.** If they want the same personal skills in both, a symlink of `~/.claude/skills` into the other config dir works; many people prefer keeping work separate.

## Troubleshooting

- **"Claude - <Name> is already running" notice** but no window: the instance runs in the background — click its Dock icon, or quit it via `pkill -f 'user-data-dir=.*Claude-<Name>'` and relaunch.
- **Logged into the wrong account / login lands in the main app:** see step 5.
- **Launcher shows the old or generic icon:** remove it from the Dock and pin it again; the script already re-registers the app and restarts the Dock.
- **"App is damaged / can't be opened":** the ad-hoc signature broke (e.g. someone edited the bundle). Re-run the script.
- **Managed (MDM) Macs:** configuration profiles for the Claude app apply to the whole app, not per instance, so both instances get them. Where both a machine-level and a user-level profile exist, the desktop app uses only the machine-level one; this setup doesn't depend on either.

## Removing it

Quit the instance, then run `bash <skill-dir>/scripts/setup.sh --name "<Name>" --uninstall`. It removes only the launcher and prints the two data folders (`~/Library/Application Support/Claude-<Name>` and `~/.claude-<name>`). Move those to the Trash only if the user confirms they no longer need the chats, sessions and settings in them.
