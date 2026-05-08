#!/bin/bash
# ──────────────────────────────────────────────────────────────────────
# cenv - Claude Code Environment Switcher
# Switch between different Claude Code API providers per terminal
# ──────────────────────────────────────────────────────────────────────

cenv() {
  local profile="${1:-default}"
  local CENV_STATUS_FILE="/tmp/cenv-active-profile"
  local CENV_SETTINGS_DIR="/tmp/cenv-settings"
  local CENV_CONFIG_DIR="${CENV_CONFIG_DIR:-$HOME/.cenv}"

  # Built-in profiles: BASE_URL|DEFAULT_MODEL|HAIKU|SONNET|OPUS
  # Missing model fields fall back to DEFAULT_MODEL at parse time
  local -A profiles
  profiles[deepseek]="https://api.deepseek.com/anthropic|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-pro[1m]"
  profiles[minimax]="https://api.minimaxi.com/anthropic|MiniMax-M2.7"
  profiles[mimo]="https://token-plan-cn.xiaomimimo.com/anthropic|mimo-v2.5-pro|mimo-v2.5|mimo-v2.5|mimo-v2.5-pro"
  profiles[glm]="https://open.bigmodel.cn/api/anthropic|glm-5.1"

  # Load user custom profiles
  if [[ -f "$CENV_CONFIG_DIR/profiles.conf" ]]; then
    while IFS='=' read -r name config; do
      [[ -n "$name" && "$name" != \#* ]] && profiles["$name"]="$config"
    done < "$CENV_CONFIG_DIR/profiles.conf"
  fi

  case "$profile" in
    list)
      echo "Available profiles:"
      for name in "${(@k)profiles}"; do
        local -a f
        IFS='|' read -rA f <<< "${profiles[$name]}"
        local d="${f[2]}" h="${f[3]:-$d}" s="${f[4]:-$d}" o="${f[5]:-$d}"
        printf "  %-12s default=%s" "$name" "$d"
        [[ "$h" != "$d" || "$s" != "$d" || "$o" != "$d" ]] && printf "  haiku=%s sonnet=%s opus=%s" "$h" "$s" "$o"
        echo ""
      done
      if [[ -f "$CENV_CONFIG_DIR/profiles.conf" ]]; then
        echo ""
        echo "Custom profiles loaded from: $CENV_CONFIG_DIR/profiles.conf"
      fi
      return 0
      ;;
    status)
      if [[ -f "$CENV_STATUS_FILE" ]]; then
        local active_profile=$(cat "$CENV_STATUS_FILE")
        echo "Current profile: $active_profile"
        if [[ -n "${profiles[$active_profile]}" ]]; then
          local -a f
          IFS='|' read -rA f <<< "${profiles[$active_profile]}"
          local d="${f[2]}" h="${f[3]:-$d}" s="${f[4]:-$d}" o="${f[5]:-$d}"
          echo "  default=$d  haiku=$h  sonnet=$s  opus=$o"
        fi
      else
        echo "No active profile (using Claude Code default)"
      fi
      return 0
      ;;
    reset)
      rm -rf "$CENV_SETTINGS_DIR" "$CENV_STATUS_FILE" 2>/dev/null
      echo "Reset complete. Next 'claude' will use default settings."
      return 0
      ;;
    help|-h|--help)
      echo "cenv - Claude Code Environment Switcher"
      echo ""
      echo "Usage: cenv [profile] [-- claude-args...]"
      echo ""
      echo "Commands:"
      echo "  cenv              Start with default profile"
      echo "  cenv <profile>    Start with specified profile"
      echo "  cenv list         Show available profiles"
      echo "  cenv status       Show current active profile"
      echo "  cenv reset        Clear temp settings, return to default"
      echo "  cenv help         Show this help"
      echo ""
      echo "Examples:"
      echo "  cenv deepseek           # Start with DeepSeek"
      echo "  cenv mimo --resume      # Resume with Mimo"
      echo "  cenv glm -p 'question'  # One-shot with GLM"
      echo ""
      echo "Custom profiles:"
      echo "  Add to ~/.cenv/profiles.conf"
      echo "  Format: name=BASE_URL|DEFAULT|HAIKU|SONNET|OPUS"
      echo "  Shorthand: name=BASE_URL|MODEL  (all tiers use MODEL)"
      return 0
      ;;
    default)
      # Use Claude Code default (settings.json)
      rm -rf "$CENV_SETTINGS_DIR" "$CENV_STATUS_FILE" 2>/dev/null
      claude "${@:2}"
      return 0
      ;;
    *)
      # Check if profile exists
      if [[ -z "${profiles[$profile]}" ]]; then
        echo "Unknown profile: $profile"
        echo "Run 'cenv list' to see available profiles"
        return 1
      fi
      ;;
  esac

  # Parse profile config: BASE_URL|DEFAULT|HAIKU|SONNET|OPUS
  # Missing fields fall back to DEFAULT
  local config="${profiles[$profile]}"
  local -a fields
  IFS='|' read -rA fields <<< "$config"
  local base_url="${fields[1]}"
  local default_model="${fields[2]}"
  local haiku_model="${fields[3]:-$default_model}"
  local sonnet_model="${fields[4]:-$default_model}"
  local opus_model="${fields[5]:-$default_model}"

  # Track active profile
  echo "$profile" > "$CENV_STATUS_FILE"

  # Get API key from Keychain via envchain
  local auth_token
  auth_token=$(envchain "$profile" printenv ANTHROPIC_AUTH_TOKEN 2>/dev/null)
  if [[ -z "$auth_token" ]]; then
    echo "Error: No API key found for '$profile'"
    echo "Run: envchain --set $profile ANTHROPIC_AUTH_TOKEN"
    return 1
  fi

  # Create temp settings file to override ~/.claude/settings.json
  mkdir -p "$CENV_SETTINGS_DIR"
  local temp_settings="$CENV_SETTINGS_DIR/$profile.json"

  cat > "$temp_settings" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$auth_token",
    "ANTHROPIC_BASE_URL": "$base_url",
    "ANTHROPIC_MODEL": "$default_model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$haiku_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$sonnet_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$opus_model"
  }
}
EOF

  # Launch with --settings to override default settings
  claude --settings "$temp_settings" "${@:2}"

  # Cleanup on exit
  rm -f "$temp_settings" 2>/dev/null
  rm -f "$CENV_STATUS_FILE" 2>/dev/null
}
