#!/bin/bash
# cenv installer

set -e

echo "Installing cenv..."

# Check dependencies
if ! command -v envchain &> /dev/null; then
  echo "envchain not found. Installing via Homebrew..."
  if command -v brew &> /dev/null; then
    brew install envchain
  else
    echo "Error: Homebrew not found. Please install envchain manually:"
    echo "  brew install envchain"
    exit 1
  fi
fi

# Create config directory
CENV_CONFIG_DIR="${CENV_CONFIG_DIR:-$HOME/.cenv}"
mkdir -p "$CENV_CONFIG_DIR"

# Copy cenv.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/cenv.sh" "$CENV_CONFIG_DIR/cenv.sh"

# Create default profiles.conf with all built-in profiles
if [[ ! -f "$CENV_CONFIG_DIR/profiles.conf" ]]; then
  cat > "$CENV_CONFIG_DIR/profiles.conf" << 'EOF'
# ──────────────────────────────────────────────────────────────────────
# cenv profiles configuration
# Changes take effect immediately — no re-source needed.
# ──────────────────────────────────────────────────────────────────────
#
# Format: name=BASE_URL|DEFAULT|HAIKU|SONNET|OPUS
# Shorthand: name=BASE_URL|MODEL  (all tiers use MODEL)
#
# Missing model fields fall back to DEFAULT.
#
# After adding a profile, set its API key:
#   envchain --set <name> ANTHROPIC_AUTH_TOKEN
#
# Special profiles (defined in cenv.sh, not here):
#   official  - Official Claude API (uses OAuth login, overrides CC Switch)
#   cursor    - Local cursor2api proxy (Cursor -> Claude Code)
# ──────────────────────────────────────────────────────────────────────

deepseek=https://api.deepseek.com/anthropic|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-pro
minimax=https://api.minimaxi.com/anthropic|MiniMax-M2.7
mimo=https://token-plan-cn.xiaomimimo.com/anthropic|mimo-v2.5-pro|mimo-v2.5|mimo-v2.5|mimo-v2.5-pro
glm=https://open.bigmodel.cn/api/anthropic|glm-5.2
EOF
  echo "Created default profiles.conf"
fi

# Detect shell config file
SHELL_CONFIG=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_CONFIG="$HOME/.bash_profile"
fi

if [[ -z "$SHELL_CONFIG" ]]; then
  echo "Warning: Could not detect shell config file"
  echo "Manually add this to your shell config:"
  echo "  source $CENV_CONFIG_DIR/cenv.sh"
  exit 0
fi

# Check if already installed
if grep -q "source.*cenv.sh" "$SHELL_CONFIG" 2>/dev/null; then
  echo "cenv already configured in $SHELL_CONFIG"
else
  echo "" >> "$SHELL_CONFIG"
  echo "# cenv - Claude Code Environment Switcher" >> "$SHELL_CONFIG"
  echo "source $CENV_CONFIG_DIR/cenv.sh" >> "$SHELL_CONFIG"
  echo "Added to $SHELL_CONFIG"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Reload shell: source $SHELL_CONFIG"
echo "  2. Set API keys:"
echo "     envchain --set deepseek ANTHROPIC_AUTH_TOKEN"
echo "     envchain --set minimax  ANTHROPIC_AUTH_TOKEN"
echo "     envchain --set mimo     ANTHROPIC_AUTH_TOKEN"
echo "     envchain --set glm      ANTHROPIC_AUTH_TOKEN"
echo "  3. Use: cenv deepseek"
echo ""
echo "Edit $CENV_CONFIG_DIR/profiles.conf to add custom providers."
