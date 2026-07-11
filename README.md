# cenv

Claude Code Environment Switcher - Switch between different API providers per terminal.

## Why?

Claude Code's `settings.json` is global. `cenv` lets you:

- Use different providers in different terminals
- Keep your default settings via CC Switch
- Override per-session with `cenv <provider>`

## Upgrade

Already using cenv? Get the latest version:

```bash
cenv update
```

Or manually:

```bash
cd ~/Downloads/cenv          # Or wherever you cloned it
git pull
cp cenv.sh ~/.cenv/cenv.sh   # Overwrite old version
source ~/.cenv/cenv.sh       # Reload in current terminal
```

## Install (first time)

```bash
git clone https://github.com/wenjiaqi8255/cenv.git
cd cenv
chmod +x install.sh
./install.sh
```

## Setup API Keys

Store API keys in macOS Keychain (one-time):

```bash
envchain --set deepseek ANTHROPIC_AUTH_TOKEN
envchain --set minimax  ANTHROPIC_AUTH_TOKEN
envchain --set mimo     ANTHROPIC_AUTH_TOKEN
envchain --set glm      ANTHROPIC_AUTH_TOKEN
```

## Usage

```bash
cenv official           # Start with official Claude API (overrides CC Switch, uses OAuth)
cenv cc-switch list     # List providers from CC Switch
cenv cc-switch <name>   # Launch with a CC Switch provider
cenv deepseek           # Start with DeepSeek (via profiles.conf)
cenv mimo               # Start with Mimo (via profiles.conf)
cenv glm --resume       # Resume with GLM
cenv cursor             # Start with Cursor (via local cursor2api proxy)
cenv list               # Show available profiles
cenv status             # Show current profile
cenv update             # Update cenv to the latest version
cenv --version          # Show version
cenv reset              # Clear temp settings
cenv                    # Use default (settings.json, no profile)
```

## Profiles Configuration

All built-in and custom profiles live in `~/.cenv/profiles.conf`. **Changes take effect immediately** — just run `cenv <profile>` again, no need to re-source or open a new terminal.

```bash
# Format: name=BASE_URL|DEFAULT|HAIKU|SONNET|OPUS
my-provider=https://api.example.com/anthropic|my-model|my-fast|my-model|my-best

# Shorthand: all tiers use the same model
simple-provider=https://api.example.com/anthropic|model-name
```

Missing model fields fall back to `DEFAULT`. This lets Claude Code's `/model` command (opus/sonnet/haiku) map to the correct model for each provider.

Then set the API key:

```bash
envchain --set my-provider ANTHROPIC_AUTH_TOKEN
```

## Cursor Profile (Special)

The `cursor` profile doesn't use a remote API. Instead it:

1. Starts a local **cursor2api** proxy (`~/.cenv/cursor2api/`)
2. Point `ANTHROPIC_BASE_URL` to `http://localhost:3010`
3. The proxy translates Anthropic Messages API → Cursor's API
4. Launches Claude Code with the proxy as backend

```bash
cenv cursor                 # Start with cursor2api proxy
CURSOR2API_PORT=3010 cenv cursor  # Use custom port (default: 3010)
```

### Cookie Setup (Vercel Bypass)

Cursor.com uses Vercel Bot Protection. You need a valid `_vcrcs` cookie to access the API.

**One-time setup** (cookie lasts ~1 hour, repeat when expired):

1. Open Chrome, go to cursor.com and log in
2. Open DevTools (**F12**) → **Network** tab → refresh the page
3. Click any request, find **Request Headers → Cookie**, copy the entire value
4. Store in macOS Keychain:

```bash
envchain --set cursor CURSOR_COOKIE
# Paste the full cookie value when prompted
```

Or set via env var directly:

```bash
CURSOR_COOKIE="your-cookie" cenv cursor
```

### Requirements

- cursor2api must be built: `cd ~/.cenv/cursor2api && npm install && npm run build`
- Node.js (for cursor2api runtime)

When `cenv cursor` exits, the proxy is automatically stopped.

## Official Profile

Use this when CC Switch has set a non-official provider and you want to temporarily switch to the official Claude API (your OAuth/Pro subscription):

```bash
cenv official           # Override CC Switch, use OAuth login
cenv official --resume  # Resume with official API
```

It works by writing empty strings for all provider-related environment variables via `--settings`, overriding whatever CC Switch has set in `settings.json`. Since no API key is set, Claude Code falls back to your OAuth login (`claude auth login` / Pro subscription).

## How It Works

For `profiles.conf` providers:
1. Reads all profiles from `~/.cenv/profiles.conf` **fresh every execution** — so changes take effect immediately
2. Reads API key from macOS Keychain via `envchain`
3. Creates a temp settings file with provider config + model tier mappings
4. Uses `--settings` flag to override `~/.claude/settings.json` (e.g. CC Switch values)
5. `cenv official` writes empty env vars — Claude Code falls back to OAuth
6. Claude Code's `/model opus|sonnet|haiku` maps to the configured model for each tier
7. Cleans up temp files on exit

For `cenv cc-switch <name>`:
1. Queries `~/.cc-switch/cc-switch.db` (`providers` table, `settings_config` column)
2. Extracts the full `env` JSON object (includes API key, base URL, model tiers)
3. Passes it directly as `--settings` — no `profiles.conf` or `envchain` involved

## Profile Scope

Each `cenv <profile>` creates its own `--settings` file in `/tmp/cenv-settings/`. The `--settings` flag only affects the current `claude` process. Different terminals can use different profiles simultaneously without interference.

## CC Switch Integration

cenv can read providers directly from [CC Switch](https://ccswitch.com/)'s database — no `profiles.conf` or `envchain` setup needed.

```bash
cenv cc-switch list              # List all CC Switch providers
cenv cc-switch "Xiaomi MiMo"     # Launch with a CC Switch provider
cenv cc-switch "DeepSeek"        # Launch with DeepSeek via CC Switch
```

All provider config (base URL, models, API keys) is read from `~/.cc-switch/cc-switch.db` in real time — any changes you make in CC Switch are immediately available.

### Why use this over profiles.conf?

- **Single source of truth** — providers managed in CC Switch, used by cenv
- **No envchain** — API keys are already stored in CC Switch's database
- **Same model tier mapping** — CC Switch's per-provider model config (haiku/sonnet/opus) maps directly to Claude Code's `/model` command

For providers you **don't** have in CC Switch, the regular `cenv <profile>` workflow via `profiles.conf` still works.

## Requirements

- macOS (uses Keychain via `envchain`, or CC Switch DB)
- zsh or bash
- Claude Code installed

## License

MIT
