# Changelog

## 1.0.0 (2026-07-11)

### Added
- `cenv cc-switch list` — List providers from CC Switch database
- `cenv cc-switch <name>` — Launch Claude Code with a CC Switch provider
- `cenv official` — Clear all env overrides, fall back to OAuth login
- `cenv cursor` — Start with local cursor2api proxy
- `cenv update` — Self-update to the latest version via git
- `cenv --version` — Show current version
- Profiles in `~/.cenv/profiles.conf` with multi-tier model mapping (haiku/sonnet/opus)
- Built-in profiles: deepseek, minimax, mimo, glm (with fallback

### Changed
- Built-in profiles moved from hardcoded array to `profiles.conf` with fallback defaults
- Temp settings files now use restrictive permissions (`umask 077`)
- `cenv list` shows all available providers including CC Switch ones
- `cenv status` recognizes `cc-switch/<name>` and `official` profiles

### Security
- Temp files containing API keys now created with `umask 077`
