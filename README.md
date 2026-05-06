# cenv

Claude Code Environment Switcher - Switch between different API providers per terminal.

## Why?

Claude Code's `settings.json` is global. `cenv` lets you:

- Use different providers in different terminals
- Keep your default settings via CC Switch
- Override per-session with `cenv <provider>`

## Install

```bash
git clone https://github.com/YOUR_USERNAME/cenv.git
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
cenv deepseek           # Start with DeepSeek
cenv mimo               # Start with Mimo
cenv glm --resume       # Resume with GLM
cenv list               # Show available profiles
cenv status             # Show current profile
cenv reset              # Clear temp settings
cenv                    # Use default (settings.json)
```

## Custom Providers

Edit `~/.cenv/profiles.conf`:

```bash
# Format: name=BASE_URL|MODEL
my-provider=https://api.example.com/anthropic|model-name
```

Then set the API key:

```bash
envchain --set my-provider ANTHROPIC_AUTH_TOKEN
```

## How It Works

1. Reads API key from macOS Keychain via `envchain`
2. Creates a temp settings file with provider config
3. Uses `--settings` to override `~/.claude/settings.json`
4. Cleans up on exit

## Requirements

- macOS (uses Keychain via `envchain`)
- zsh or bash
- Claude Code installed

## License

MIT
