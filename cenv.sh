#!/bin/bash
# ──────────────────────────────────────────────────────────────────────
# cenv - Claude Code Environment Switcher
# Switch between different Claude Code API providers per terminal
# ──────────────────────────────────────────────────────────────────────

# Version info (guard against re-source in zsh)
typeset -r CENV_VERSION="1.0.0" 2>/dev/null || true
typeset -r CENV_REPO_URL="https://github.com/wenjiaqi8255/cenv.git" 2>/dev/null || true
typeset -r CENV_REPO_DIR="$HOME/.cenv/repo" 2>/dev/null || true

cenv() {
  local profile="${1:-default}"
  local CENV_STATUS_FILE="/tmp/cenv-active-profile"
  local CENV_SETTINGS_DIR="/tmp/cenv-settings"
  local CENV_CONFIG_DIR="${CENV_CONFIG_DIR:-$HOME/.cenv}"

  local -A profiles

  # Load profiles from profiles.conf (read fresh every execution)
  if [[ -f "$CENV_CONFIG_DIR/profiles.conf" ]]; then
    while IFS='=' read -r name config; do
      [[ -n "$name" && "$name" != \#* ]] && profiles["$name"]="$config"
    done < "$CENV_CONFIG_DIR/profiles.conf"
  fi

  # Fallback defaults for backward compatibility (profiles.conf missing these)
  [[ -z "${profiles[deepseek]}" ]] && profiles[deepseek]="https://api.deepseek.com/anthropic|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-flash|deepseek-v4-pro"
  [[ -z "${profiles[minimax]}" ]] && profiles[minimax]="https://api.minimaxi.com/anthropic|MiniMax-M2.7"
  [[ -z "${profiles[mimo]}" ]] && profiles[mimo]="https://token-plan-cn.xiaomimimo.com/anthropic|mimo-v2.5-pro|mimo-v2.5|mimo-v2.5|mimo-v2.5-pro"
  [[ -z "${profiles[glm]}" ]] && profiles[glm]="https://open.bigmodel.cn/api/anthropic|glm-5.2"

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
        echo "Profiles loaded from: $CENV_CONFIG_DIR/profiles.conf"
      fi
      echo ""
      echo "Special:"
      printf "  %-12s # Official Claude API (uses OAuth login, overrides CC Switch)\n" "official"
      printf "  %-12s # Local cursor2api proxy (Cursor → Claude Code)\n" "cursor"
      echo ""
      echo "CC Switch providers (via cenv cc-switch <name>):"
      if [[ -f "$HOME/.cc-switch/cc-switch.db" ]]; then
        sqlite3 "$HOME/.cc-switch/cc-switch.db" "
          SELECT name FROM providers
          WHERE id != 'default' AND category != 'official'
          ORDER BY sort_index, name
        " | while IFS= read -r name; do
          printf "  %-12s # From CC Switch DB\n" "$name"
        done
      fi
      echo ""
      echo "CURSOR2API_PORT env var sets cursor2api port (default: 3010)"
      return 0
      ;;

    official)
      # ──────────────────────────────────────────────────────────
      # Official Claude profile: clear all CC Switch env overrides
      # Falls back to OAuth login (claude auth login / Pro sub)
      # ──────────────────────────────────────────────────────────
      echo "official" > "$CENV_STATUS_FILE"

      mkdir -p "$CENV_SETTINGS_DIR"
      local temp_settings="$CENV_SETTINGS_DIR/official.json"
      cat > "$temp_settings" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "",
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_API_KEY": "",
    "ANTHROPIC_MODEL": "",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": ""
  }
}
EOF

      claude --settings "$temp_settings" "${@:2}"

      rm -f "$temp_settings" "$CENV_STATUS_FILE" 2>/dev/null
      return 0
      ;;

    cursor)
      # ──────────────────────────────────────────────────────────
      # cursor profile: start cursor2api proxy → Claude Code
      # Uses CURSOR_COOKIE to bypass Vercel JS Challenge:
      #   - Set CURSOR_COOKIE env var, OR
      #   - Store in Keychain via: envchain --set cursor CURSOR_COOKIE
      # ──────────────────────────────────────────────────────────
      local c2api_dir="$CENV_CONFIG_DIR/cursor2api"
      local c2api_port="${CURSOR2API_PORT:-3010}"
      local started_c2api=false

      # Check cursor2api is built
      if [[ ! -f "$c2api_dir/dist/index.js" ]]; then
        echo "Error: cursor2api not built."
        echo "Run: cd $c2api_dir && npm install && npm run build"
        return 1
      fi

      # ── Step 1: Get Cursor cookie (env var > keychain) ──
      if [[ -z "${CURSOR_COOKIE:-}" ]]; then
        local stored_cookie
        stored_cookie=$(envchain cursor printenv CURSOR_COOKIE 2>/dev/null)
        if [[ -n "$stored_cookie" ]]; then
          export CURSOR_COOKIE="$stored_cookie"
        fi
      fi

      # ── Step 2: Start cursor2api with cookie (direct mode) ──
      if ! curl -sf "http://localhost:$c2api_port/health" > /dev/null 2>&1; then
        echo "[cenv] Starting cursor2api on port $c2api_port..."
        cd "$c2api_dir"
        CURSOR_COOKIE="${CURSOR_COOKIE:-}" nohup node dist/index.js > /tmp/cursor2api.log 2>&1 &
        local c2api_pid=$!
        started_c2api=true

        # Wait for ready (up to 15s)
        local waited=0
        while [[ $waited -lt 15 ]]; do
          if curl -sf "http://localhost:$c2api_port/health" > /dev/null 2>&1; then
            echo "[cenv] cursor2api ready! (PID: $c2api_pid)"
            break
          fi
          sleep 1
          ((waited++))
        done

        if [[ $waited -ge 15 ]]; then
          echo "[cenv] Warning: cursor2api not responding after 15s, launching anyway..."
        fi
      else
        echo "[cenv] cursor2api already running on port $c2api_port"
      fi

      # Track active profile
      echo "cursor" > "$CENV_STATUS_FILE"

      # Create temp settings pointing to local cursor2api proxy
      mkdir -p "$CENV_SETTINGS_DIR"
      local temp_settings="$CENV_SETTINGS_DIR/cursor.json"
      cat > "$temp_settings" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:$c2api_port"
  }
}
EOF

      # Launch Claude Code
      claude --settings "$temp_settings" "${@:2}"

      # Cleanup: stop cursor2api if we started it
      if $started_c2api; then
        kill "$c2api_pid" 2>/dev/null && echo "[cenv] Stopped cursor2api (PID: $c2api_pid)"
      fi
      rm -f "$temp_settings" 2>/dev/null
      rm -f "$CENV_STATUS_FILE" 2>/dev/null
      return 0
      ;;
    cc-switch)
      # ──────────────────────────────────────────────────────────
      # CC Switch integration: read providers directly from
      # ~/.cc-switch/cc-switch.db — no profiles.conf or envchain
      # ──────────────────────────────────────────────────────────
      local ccswitch_db="$HOME/.cc-switch/cc-switch.db"

      if [[ ! -f "$ccswitch_db" ]]; then
        echo "Error: CC Switch database not found at $ccswitch_db"
        echo "Is CC Switch installed?"
        return 1
      fi

      local subcmd="${2:-list}"

      case "$subcmd" in
        list)
          echo "CC Switch providers (via: cenv cc-switch <name>):"
          echo "─────────────────────────────────────────────────────────────"
          sqlite3 "$ccswitch_db" "
            SELECT p.name,
                   json_extract(p.settings_config, '$.env.ANTHROPIC_MODEL'),
                   json_extract(p.settings_config, '$.env.ANTHROPIC_DEFAULT_HAIKU_MODEL'),
                   json_extract(p.settings_config, '$.env.ANTHROPIC_DEFAULT_SONNET_MODEL'),
                   json_extract(p.settings_config, '$.env.ANTHROPIC_DEFAULT_OPUS_MODEL')
            FROM providers p
            WHERE p.id != 'default' AND p.category != 'official'
            ORDER BY p.sort_index, p.name
          " | while IFS='|' read -r name d haiku sonnet opus; do
            printf "  %-22s default=%s" "$name" "${d:-"-"}"
            [[ -n "$haiku" && "$haiku" != "$d" ]] && printf "  haiku=%s" "$haiku"
            [[ -n "$sonnet" && "$sonnet" != "$d" ]] && printf "  sonnet=%s" "$sonnet"
            [[ -n "$opus" && "$opus" != "$d" ]] && printf "  opus=%s" "$opus"
            echo ""
          done
          return 0
          ;;
        *)
          local provider_name="$subcmd"
          # Escape single quotes for SQL safety
          local escaped_name="${provider_name//\'/''}"
          local result
          result=$(sqlite3 "$ccswitch_db" "
            SELECT p.name, json_extract(p.settings_config, '$.env')
            FROM providers p
            WHERE LOWER(p.name) = LOWER('$escaped_name')
              AND p.id != 'default' AND p.category != 'official'
            LIMIT 1
          ")

          if [[ -z "$result" ]]; then
            echo "Error: Provider '$provider_name' not found in CC Switch"
            echo "Run 'cenv cc-switch list' to see available providers"
            return 1
          fi

          local display_name env_json
          IFS='|' read -r display_name env_json <<< "$result"

          echo "cc-switch/$display_name" > "$CENV_STATUS_FILE"

          mkdir -p "$CENV_SETTINGS_DIR"
          local temp_settings="$CENV_SETTINGS_DIR/cc-switch.json"
          (umask 077; cat > "$temp_settings" << EOF
{
  "env": $env_json
}
EOF
)

          claude --settings "$temp_settings" "${@:3}"

          rm -f "$temp_settings" "$CENV_STATUS_FILE" 2>/dev/null
          return 0
          ;;
      esac
      ;;
    status)
      if [[ -f "$CENV_STATUS_FILE" ]]; then
        local active_profile=$(cat "$CENV_STATUS_FILE")
        echo "Current profile: $active_profile"
        case "$active_profile" in
          official)
            echo "  (Official Claude — env overrides cleared, uses OAuth login)"
            ;;
          cc-switch/*)
            local cs_name="${active_profile#cc-switch/}"
            echo "  (CC Switch: $cs_name)"
            ;;
          "")
            echo "  (No active profile)"
            ;;
          *)
            if [[ -n "${profiles[$active_profile]}" ]]; then
              local -a f
              IFS='|' read -rA f <<< "${profiles[$active_profile]}"
              local d="${f[2]}" h="${f[3]:-$d}" s="${f[4]:-$d}" o="${f[5]:-$d}"
              echo "  default=$d  haiku=$h  sonnet=$s  opus=$o"
            fi
            ;;
        esac
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
    --version|-V)
      echo "cenv $CENV_VERSION"
      return 0
      ;;
    self-update|update)
      # ── Ensure repo is cloned ──
      if [[ ! -d "$CENV_REPO_DIR" ]]; then
        echo "Cloning cenv repository to $CENV_REPO_DIR ..."
        git clone --quiet "$CENV_REPO_URL" "$CENV_REPO_DIR" 2>/dev/null
      fi

      # ── Fetch latest ──
      echo "Checking for updates..."
      local old_sha
      old_sha=$(git -C "$CENV_REPO_DIR" rev-parse HEAD 2>/dev/null)
      git -C "$CENV_REPO_DIR" pull --ff-only --quiet 2>/dev/null
      local new_sha
      new_sha=$(git -C "$CENV_REPO_DIR" rev-parse HEAD 2>/dev/null)

      if [[ "$old_sha" == "$new_sha" ]]; then
        echo "Already up to date (cenv $CENV_VERSION)."
        return 0
      fi

      # ── Install updated cenv.sh ──
      cp "$CENV_REPO_DIR/cenv.sh" "$CENV_CONFIG_DIR/cenv.sh" && echo "Updated cenv.sh installed."

      # ── Show changelog since last version ──
      echo ""
      echo "Changes:"
      git -C "$CENV_REPO_DIR" log --oneline --no-decorate "$old_sha..$new_sha" 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
      done

      echo ""
      echo "Done! Restart your shell or run: source $CENV_CONFIG_DIR/cenv.sh"
      return 0
      ;;
    help|-h|--help)
      echo "cenv v$CENV_VERSION - Claude Code Environment Switcher"
      echo ""
      echo "Usage: cenv [profile] [-- claude-args...]"
      echo ""
      echo "Commands:"
      echo "  cenv [profile]    Start Claude Code with a profile"
      echo "  cenv list         Show available profiles"
      echo "  cenv cc-switch    Manage CC Switch providers"
      echo "  cenv status       Show current active profile"
      echo "  cenv update       Update cenv to the latest version"
      echo "  cenv --version    Show version"
      echo "  cenv reset        Clear temp settings, return to default"
      echo "  cenv help         Show this help"
      echo ""
      echo "CC Switch:"
      echo "  cenv cc-switch list              # List providers from CC Switch DB"
      echo ""
      echo "Examples:"
      echo "  cenv official          # Override CC Switch, use OAuth login"
      echo "  cenv deepseek           # Start with DeepSeek"
      echo "  cenv mimo --resume      # Resume with Mimo"
      echo "  cenv glm -p 'question'  # One-shot with GLM"
      echo ""
      echo "Custom profiles:"
      echo "  Edit ~/.cenv/profiles.conf"
      echo "  Format: name=BASE_URL|DEFAULT|HAIKU|SONNET|OPUS"
      echo "  Shorthand: name=BASE_URL|MODEL  (all tiers use MODEL)"
      echo ""
      echo "Changes to profiles.conf take effect immediately (no re-source needed)."
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

  (umask 077; cat > "$temp_settings" << EOF
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
)

  # Launch with --settings to override default settings
  claude --settings "$temp_settings" "${@:2}"

  # Cleanup on exit
  rm -f "$temp_settings" 2>/dev/null
  rm -f "$CENV_STATUS_FILE" 2>/dev/null
}
