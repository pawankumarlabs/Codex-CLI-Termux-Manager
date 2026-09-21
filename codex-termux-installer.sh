#!/data/data/com.termux/files/usr/bin/bash
# Codex CLI Termux Manager
# Install • Update • AgentRouter • Models • Diagnostics • Launch • Uninstall
set -u

APP_NAME="Codex CLI Manager"
INSTALL_URL="https://chatgpt.com/codex/install.sh"
CODEX_HOME="${HOME}/.codex"
CONFIG_FILE="${CODEX_HOME}/config.toml"
AUTH_FILE="${CODEX_HOME}/auth.json"
PROFILE_FILE="${HOME}/.profile"
TERMUX_BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"
AGENTROUTER_URL="${AGENTROUTER_URL:-https://co.agentrouter.org/v1}"

# ─────────────────────────────────────────────────────────────────────────────
# Professional Termux UI
# ─────────────────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ "${NO_COLOR:-0}" != "1" ]; then
  R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
  C=$'\033[38;5;45m'; G=$'\033[38;5;82m'; Y=$'\033[38;5;220m'
  E=$'\033[38;5;203m'; W=$'\033[38;5;255m'; GR=$'\033[38;5;245m'
else
  R=''; B=''; D=''; C=''; G=''; Y=''; E=''; W=''; GR=''
fi

term_width() {
  local w
  w="$(tput cols 2>/dev/null || printf '80')"
  case "$w" in *[!0-9]*|'') w=80;; esac
  [ "$w" -lt 60 ] && w=60
  [ "$w" -gt 96 ] && w=96
  printf '%s' "$w"
}
clear_screen() { clear 2>/dev/null || true; }
line() {
  local w; w="$(term_width)"
  printf '%*s\n' "$w" '' | tr ' ' '─'
}
header() {
  clear_screen
  printf '\n'
  printf '%s╭────────────────────────────────────────────────────────────╮%s\n' "$C" "$R"
  printf '%s│%s  %s%sCODEX CLI MANAGER%s  %s• Termux Edition%s              %s│%s\n' "$C" "$R" "$B" "$W" "$R" "$GR" "$R" "$C" "$R"
  printf '%s│%s  %sInstall • Repair • Configure • Diagnose • Launch%s       %s│%s\n' "$C" "$R" "$GR" "$R" "$C" "$R"
  printf '%s╰────────────────────────────────────────────────────────────╯%s\n\n' "$C" "$R"
}
title() { printf '\n%s%s%s\n' "$B" "$1" "$R"; line; }
ok() { printf '  %s✓%s %s\n' "$G" "$R" "$1"; }
info() { printf '  %s›%s %s\n' "$C" "$R" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$R" "$1"; }
die() { printf '  %s✗%s %s\n' "$E" "$R" "$1"; exit 1; }
pause() { printf '\n%sPress Enter to return...%s' "$D" "$R"; read -r _ || true; }

ask_yes_no() {
  local q="$1" d="${2:-y}" a
  while true; do
    if [ "$d" = "y" ]; then
      printf '\n%s?%s %s %s[Y/n]%s ' "$C" "$R" "$q" "$D" "$R"
    else
      printf '\n%s?%s %s %s[y/N]%s ' "$C" "$R" "$q" "$D" "$R"
    fi
    read -r a || a=""
    a="$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')"
    [ -z "$a" ] && a="$d"
    case "$a" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) warn "Please enter y or n." ;;
    esac
  done
}

run_or_fail() {
  "$@"
  local rc=$?
  [ "$rc" -eq 0 ] || die "Command failed: $*"
}

is_termux() {
  [ -n "${PREFIX:-}" ] &&
  [ -d "${PREFIX}/bin" ] &&
  [ -d "/data/data/com.termux/files" ]
}

ensure_termux() {
  is_termux || die "This manager must be run inside Termux on Android."
  command -v pkg >/dev/null 2>&1 || die "Termux pkg command not found."
}

ensure_packages() {
  local missing=""
  command -v curl >/dev/null 2>&1 || missing="$missing curl"
  command -v node >/dev/null 2>&1 || missing="$missing nodejs"
  command -v npm >/dev/null 2>&1 || missing="$missing nodejs"

  if [ -n "$missing" ]; then
    warn "Missing:$missing"
    if ask_yes_no "Install required packages now?" y; then
      run_or_fail pkg update -y
      run_or_fail pkg install -y curl nodejs
    else
      die "Required packages are missing."
    fi
  else
    ok "curl / node / npm ready"
  fi
}

codex_installed() {
  command -v codex >/dev/null 2>&1
}

codex_version() {
  codex --version 2>/dev/null | head -n 1 || printf 'not installed'
}

# ─────────────────────────────────────────────────────────────────────────────
# Codex installation
# ─────────────────────────────────────────────────────────────────────────────
install_npm_codex() {
  info "Installing/updating @openai/codex..."
  run_or_fail npm install -g @openai/codex@latest
}

install_native_fix() {
  local version arch native_alias native_target

  version="$(npm view @openai/codex version 2>/dev/null | tail -n 1)"
  [ -n "$version" ] || {
    warn "Could not read latest @openai/codex version."
    return 1
  }

  arch="$(uname -m 2>/dev/null || true)"

  case "$arch" in
    aarch64|arm64)
      native_alias="@openai/codex-linux-arm64"
      native_target="@openai/codex@${version}-linux-arm64"
      ;;
    x86_64|amd64)
      native_alias="@openai/codex-linux-x64"
      native_target="@openai/codex@${version}-linux-x64"
      ;;
    *)
      warn "Unsupported CPU architecture: $arch"
      return 1
      ;;
  esac

  info "Applying native Linux package fix for $arch..."
  npm install -g --force "${native_alias}@npm:${native_target}"
}

install_codex() {
  title "Install / Repair Codex"
  ensure_packages

  if ask_yes_no "Run the official Codex installer first?" y; then
    curl -fsSL "$INSTALL_URL" | sh ||
      warn "Official installer failed; continuing with npm installation."
  fi

  install_npm_codex

  export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
  hash -r 2>/dev/null || true

  if codex_installed && codex --version >/dev/null 2>&1; then
    ok "Codex is working: $(codex_version)"
    return 0
  fi

  warn "Codex did not start correctly. Trying native package repair..."
  install_native_fix || true

  export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
  hash -r 2>/dev/null || true

  if codex_installed && codex --version >/dev/null 2>&1; then
    ok "Native repair successful: $(codex_version)"
  else
    die "Codex could not be repaired."
  fi
}

update_codex() {
  title "Update Codex"
  ensure_packages
  install_npm_codex

  export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
  hash -r 2>/dev/null || true

  if codex_installed; then
    ok "Updated: $(codex_version)"
  else
    die "Codex command not found after update."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# AgentRouter
# ─────────────────────────────────────────────────────────────────────────────
fetch_models() {
  local key="${AGENT_ROUTER_TOKEN:-}"

  [ -n "$key" ] || return 2
  command -v curl >/dev/null 2>&1 || return 3

  curl -fsS --max-time 20 \
    -H "Authorization: Bearer $key" \
    -H "Accept: application/json" \
    "${AGENTROUTER_URL}/models" 2>/dev/null
}

json_model_ids() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    for item in data.get("data", []):
        if isinstance(item, dict) and item.get("id"):
            print(item["id"])
except Exception:
    pass
' 2>/dev/null
    return
  fi

  # Lightweight fallback when Python is unavailable.
  printf '%s\n' "$1" |
    sed 's/[{},]/\n/g' |
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    awk '!seen[$0]++'
}

choose_model() {
  local models="$1"
  local count=0 choice id i
  local -a ids=()

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    ids+=("$id")
  done <<< "$models"

  count="${#ids[@]}"

  printf '\n%s%sAvailable models%s\n' "$B" "$W" "$R"
  line

  if [ "$count" -gt 0 ]; then
    i=0
    while [ "$i" -lt "$count" ]; do
      printf '  %s%2d%s  %s\n' "$C" "$((i+1))" "$R" "${ids[$i]}"
      i=$((i+1))
    done

    printf '  %sM%s   Manual model ID\n' "$C" "$R"
    printf '  %sR%s   Refresh model list\n' "$C" "$R"

    while true; do
      printf '\n%s?%s Select model [1-%s/M/R]: ' "$C" "$R" "$count"
      read -r choice || choice=""

      case "$choice" in
        m|M)
          printf '  Model ID: '
          read -r choice || choice=""
          if [ -n "$choice" ]; then
            SELECTED_MODEL="$choice"
            return 0
          fi
          warn "Model ID cannot be empty."
          ;;
        r|R)
          return 2
          ;;
        ''|*[!0-9]*)
          warn "Choose a number, M, or R."
          ;;
        *)
          if [ "$choice" -ge 1 ] 2>/dev/null &&
             [ "$choice" -le "$count" ]; then
            SELECTED_MODEL="${ids[$((choice-1))]}"
            return 0
          fi
          warn "Invalid selection."
          ;;
      esac
    done
  fi

  warn "No models were returned."
  printf '  %sM%s  Enter model ID manually\n' "$C" "$R"

  while true; do
    printf '\n%s?%s Model ID: ' "$C" "$R"
    read -r choice || choice=""
    [ -n "$choice" ] && {
      SELECTED_MODEL="$choice"
      return 0
    }
    warn "Model ID cannot be empty."
  done
}

read_agentrouter_token() {
  local token=""

  if [ -n "${AGENT_ROUTER_TOKEN:-}" ]; then
    printf '%sAPI key%s\n' "$B" "$R"
    info "Using AGENT_ROUTER_TOKEN already present in the environment."
    printf '\n'
    AGENT_ROUTER_TOKEN="$AGENT_ROUTER_TOKEN"
    return 0
  fi

  if grep -q '^export AGENT_ROUTER_TOKEN=' "$PROFILE_FILE" 2>/dev/null; then
    # Load only the user's existing profile value.
    # shellcheck disable=SC1090
    . "$PROFILE_FILE" 2>/dev/null || true
    if [ -n "${AGENT_ROUTER_TOKEN:-}" ]; then
      info "Existing AgentRouter token found in ~/.profile."
      return 0
    fi
  fi

  printf '%sAPI key%s\n' "$B" "$R"
  printf '  Paste token: '
  stty -echo 2>/dev/null || true
  read -r token || token=""
  stty echo 2>/dev/null || true
  printf '\n'

  [ -n "$token" ] || return 1
  export AGENT_ROUTER_TOKEN="$token"
  return 0
}

save_token() {
  local token="$1"
  local tmp="${TMPDIR:-$HOME}/codex-profile-$$.tmp"

  touch "$PROFILE_FILE"

  grep -v '^export AGENT_ROUTER_TOKEN=' "$PROFILE_FILE" 2>/dev/null > "$tmp" || true
  grep -v '^# AgentRouter for Codex$' "$tmp" 2>/dev/null > "${tmp}.2" ||
    cp "$tmp" "${tmp}.2"

  mv "${tmp}.2" "$tmp"

  printf '\n# AgentRouter for Codex\nexport AGENT_ROUTER_TOKEN=%s\n' \
    "$(printf '%s' "$token" | sed "s/'/'\\\\''/g; s/.*/'&'/")" >> "$tmp"

  mv "$tmp" "$PROFILE_FILE"
  export AGENT_ROUTER_TOKEN="$token"
}

write_config() {
  local model="$1"

  mkdir -p "$CODEX_HOME"

  cat > "$CONFIG_FILE" <<CONFIG
model = "$model"
model_provider = "agentrouter"
preferred_auth_method = "apikey"

[model_providers.agentrouter]
name = "AgentRouter"
base_url = "$AGENTROUTER_URL"
env_key = "AGENT_ROUTER_TOKEN"
wire_api = "responses"
query_params = {}
stream_idle_timeout_ms = 300000
CONFIG

  [ -f "$AUTH_FILE" ] || printf '{}\n' > "$AUTH_FILE"
}

configure_agentrouter() {
  title "AgentRouter Configuration"

  local response=""
  local models=""

  SELECTED_MODEL=""

  if ! read_agentrouter_token; then
    warn "No API key entered. Configuration cancelled."
    return 0
  fi

  info "Checking API key and fetching available models..."
  response="$(fetch_models || true)"

  if printf '%s' "$response" | grep -q '"data"'; then
    models="$(printf '%s' "$response" | json_model_ids "$response")"
    ok "AgentRouter API responded."
  else
    warn "Could not fetch models automatically."
    info "Manual model entry is still available."
  fi

  while true; do
    if [ -n "$models" ]; then
      choose_model "$models"
      case "$?" in
        0) break ;;
        2)
          info "Refreshing model list..."
          response="$(fetch_models || true)"
          models="$(printf '%s' "$response" | json_model_ids "$response")"
          ;;
      esac
    else
      choose_model ""
      break
    fi
  done

  printf '\n%s%sConfiguration%s\n' "$B" "$W" "$R"
  line
  printf '  Provider : AgentRouter\n'
  printf '  Model    : %s\n' "$SELECTED_MODEL"
  printf '  Endpoint : %s\n' "$AGENTROUTER_URL"
  printf '  API key  : ********\n'
  line

  if ask_yes_no "Save this configuration?" y; then
    save_token "$AGENT_ROUTER_TOKEN"
    write_config "$SELECTED_MODEL"
    ok "AgentRouter configuration saved."
    info "Config: $CONFIG_FILE"
  else
    warn "Configuration not saved."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Diagnostics
# ─────────────────────────────────────────────────────────────────────────────
test_codex() {
  title "Diagnostics"

  if ! codex_installed; then
    warn "Codex is not installed."
    return 1
  fi

  local doctor_dir="${HOME}/.cache/codex-termux-manager"
  local doctor_log="${doctor_dir}/doctor-$$.log"
  local version
  local doctor_rc=1

  version="$(codex_version)"

  printf '%s%sSystematic check%s\n' "$B" "$W" "$R"
  printf '  Codex : %s\n' "$version"
  printf '  Arch  : %s\n' "$(uname -m 2>/dev/null || printf 'unknown')"
  printf '  Home  : %s\n' "$CODEX_HOME"
  printf '\n'

  mkdir -p "$doctor_dir" 2>/dev/null || true

  if [ -d "$doctor_dir" ]; then
    codex doctor >"$doctor_log" 2>&1
    doctor_rc=$?
  fi

  if [ ! -f "$doctor_log" ]; then
    warn "Could not create diagnostics log."
    info "Running Codex Doctor directly:"
    line
    codex doctor 2>&1 | sed -n '1,100p' || true
    line
    return 0
  fi

  local auth_line reach_line ws_line terminal_line update_line

  auth_line="$(grep -m1 -E '^[[:space:]]*[✗!]?[[:space:]]*auth[[:space:]]' "$doctor_log" || true)"
  reach_line="$(grep -m1 -E '^[[:space:]]*[✗!]?[[:space:]]*reachability[[:space:]]' "$doctor_log" || true)"
  ws_line="$(grep -m1 -E '^[[:space:]]*[✗!]?[[:space:]]*websocket[[:space:]]' "$doctor_log" || true)"
  terminal_line="$(grep -m1 -E '^[[:space:]]*[✗!]?[[:space:]]*terminal[[:space:]]' "$doctor_log" || true)"
  update_line="$(grep -m1 -E '^[[:space:]]*[✗!]?[[:space:]]*updates?[[:space:]]' "$doctor_log" || true)"

  printf '%s%s1. Codex installation%s\n' "$B" "$C" "$R"
  if codex --version >/dev/null 2>&1; then
    ok "Codex executable is working"
    printf '   Version : %s\n' "$version"
  else
    warn "Codex executable returned an error"
  fi
  printf '\n'

  printf '%s%s2. Authentication%s\n' "$B" "$C" "$R"
  if [ -n "${AGENT_ROUTER_TOKEN:-}" ] ||
     grep -q '^export AGENT_ROUTER_TOKEN=' "$PROFILE_FILE" 2>/dev/null; then
    ok "AgentRouter token is configured"
    printf '   Note    : Native Codex login status is separate from AgentRouter.\n'
  elif [ -n "$auth_line" ]; then
    warn "Native Codex credentials are not configured"
    printf '   Action  : use Codex login or a supported auth environment variable.\n'
  else
    info "No native Codex auth warning detected"
  fi
  printf '\n'

  printf '%s%s3. AgentRouter configuration%s\n' "$B" "$C" "$R"
  if [ -f "$CONFIG_FILE" ]; then
    local configured_model configured_url
    configured_model="$(sed -n 's/^model = "\(.*\)"/\1/p' "$CONFIG_FILE" | head -n1)"
    configured_url="$(sed -n 's/^base_url = "\(.*\)"/\1/p' "$CONFIG_FILE" | head -n1)"

    ok "AgentRouter config exists"
    printf '   Model   : %s\n' "${configured_model:-not set}"
    printf '   URL     : %s\n' "${configured_url:-not set}"
  else
    info "AgentRouter is not configured"
  fi
  printf '\n'

  printf '%s%s4. Network checks%s\n' "$B" "$C" "$R"
  if [ -n "$reach_line" ]; then
    warn "Provider reachability issue reported"
    printf '   %s\n' "$(printf '%s' "$reach_line" | sed 's/^[[:space:]]*//')"
    printf '   Action  : check DNS, VPN/proxy, firewall, CA, and endpoint access.\n'
  else
    ok "No provider reachability error reported"
  fi

  if [ -n "$ws_line" ]; then
    warn "WebSocket issue reported"
    printf '   %s\n' "$(printf '%s' "$ws_line" | sed 's/^[[:space:]]*//')"
    printf '   Action  : HTTPS fallback may work; check proxy/VPN/firewall if needed.\n'
  else
    ok "No WebSocket error reported"
  fi
  printf '\n'

  printf '%s%s5. Terminal / environment%s\n' "$B" "$C" "$R"
  if [ -n "$terminal_line" ]; then
    warn "Terminal width may be too small"
    printf '   %s\n' "$(printf '%s' "$terminal_line" | sed 's/^[[:space:]]*//')"
    printf '   Action  : use an 80+ column terminal when possible.\n'
  else
    ok "Terminal environment looks suitable"
  fi

  if [ -n "$update_line" ]; then
    info "Update check: $(printf '%s' "$update_line" | sed 's/^[[:space:]]*//')"
  fi

  printf '\n%s%s6. Raw Codex Doctor output%s\n' "$B" "$GR" "$R"
  line
  sed -n '1,120p' "$doctor_log"
  line

  rm -f "$doctor_log"

  printf '\n'
  if [ "$doctor_rc" -eq 0 ]; then
    ok "Diagnostics completed."
  else
    warn "Diagnostics completed with reported issues."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Fixes / status / launch
# ─────────────────────────────────────────────────────────────────────────────
fix_common() {
  title "Common Fixes"

  printf '  %s1%s  Reload ~/.profile\n' "$C" "$R"
  printf '  %s2%s  Repair Codex installation\n' "$C" "$R"
  printf '  %s3%s  Reconfigure AgentRouter\n' "$C" "$R"
  printf '  %sb%s  Back\n' "$C" "$R"
  printf '\n%s?%s Select [1-3/b]: ' "$C" "$R"

  local choice
  read -r choice || choice="b"

  case "$choice" in
    1)
      if [ -f "$PROFILE_FILE" ]; then
        # shellcheck disable=SC1090
        . "$PROFILE_FILE" 2>/dev/null || true
        export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
        hash -r 2>/dev/null || true
        ok "Profile reloaded for this manager session."
      else
        info "~/.profile does not exist."
      fi
      ;;
    2) install_codex ;;
    3) configure_agentrouter ;;
    b|B) return 0 ;;
    *) warn "Invalid choice." ;;
  esac
}

show_status() {
  title "Status"

  if codex_installed; then
    ok "Codex: $(codex_version)"
  else
    warn "Codex: not installed"
  fi

  if [ -f "$CONFIG_FILE" ]; then
    ok "AgentRouter config: configured"
    printf '   Model    : %s\n' \
      "$(sed -n 's/^model = "\(.*\)"/\1/p' "$CONFIG_FILE" | head -n1)"
    printf '   Endpoint : %s\n' \
      "$(sed -n 's/^base_url = "\(.*\)"/\1/p' "$CONFIG_FILE" | head -n1)"
    printf '   Config   : %s\n' "$CONFIG_FILE"
  else
    info "AgentRouter config: not configured"
  fi

  if [ -n "${AGENT_ROUTER_TOKEN:-}" ] ||
     grep -q '^export AGENT_ROUTER_TOKEN=' "$PROFILE_FILE" 2>/dev/null; then
    ok "AgentRouter token: configured"
  else
    info "AgentRouter token: not configured"
  fi
}

launch_codex() {
  title "Launch Codex"

  export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
  hash -r 2>/dev/null || true

  if ! command -v codex >/dev/null 2>&1; then
    warn "Codex command is not installed."
    info "Use option 1 to install or repair Codex."
    return 1
  fi

  ok "Command: codex"
  printf '%sLaunching Codex CLI...%s\n\n' "$B" "$R"
  exec codex
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────────────────────────────────
remove_profile_entries() {
  [ -f "$PROFILE_FILE" ] || return 0

  local tmp="${TMPDIR:-$HOME}/codex-profile-remove-$$.tmp"

  grep -v '^export AGENT_ROUTER_TOKEN=' "$PROFILE_FILE" 2>/dev/null |
    grep -v '^# AgentRouter for Codex$' > "$tmp" || true

  mv "$tmp" "$PROFILE_FILE"
}

uninstall_codex() {
  title "Uninstall Codex"

  warn "Your projects and normal Termux files will not be removed."

  if ask_yes_no "Remove Codex npm packages?" y; then
    npm uninstall -g \
      @openai/codex \
      @openai/codex-linux-arm64 \
      @openai/codex-linux-x64 >/dev/null 2>&1 || true
    ok "Codex npm packages removed."
  fi

  if ask_yes_no "Remove AgentRouter token from ~/.profile?" y; then
    remove_profile_entries
    ok "AgentRouter token entry removed."
  fi

  if ask_yes_no "Remove ~/.codex configuration and state?" n; then
    rm -rf "$CODEX_HOME"
    ok "~/.codex removed."
  else
    info "~/.codex kept."
  fi

  ok "Uninstall finished."
}

# ─────────────────────────────────────────────────────────────────────────────
# Main menu
# ─────────────────────────────────────────────────────────────────────────────
main_menu() {
  ensure_termux

  while true; do
    export PATH="$TERMUX_BIN:$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true
    header

    printf '%s%sSTATUS%s\n' "$B" "$W" "$R"
    if codex_installed; then
      printf '  Codex       : %s%s%s\n' "$G" "$(codex_version)" "$R"
    else
      printf '  Codex       : %sNot installed%s\n' "$Y" "$R"
    fi

    if [ -f "$CONFIG_FILE" ]; then
      local current_model
      current_model="$(sed -n 's/^model = "\(.*\)"/\1/p' "$CONFIG_FILE" | head -n1)"
      printf '  AgentRouter : %s%s%s\n' "$G" "${current_model:-Configured}" "$R"
    else
      printf '  AgentRouter : %sNot configured%s\n' "$GR" "$R"
    fi

    printf '  Platform    : Android / Termux / %s\n' "$(uname -m 2>/dev/null || printf 'unknown')"
    printf '\n'

    title "MAIN MENU"
    printf '  %s1%s  Install / Repair Codex\n' "$C" "$R"
    printf '  %s2%s  Update Codex\n' "$C" "$R"
    printf '  %s3%s  AgentRouter & Models\n' "$C" "$R"
    printf '  %s4%s  Diagnostics\n' "$C" "$R"
    printf '  %s5%s  Common Fixes\n' "$C" "$R"
    printf '  %s6%s  Status & Configuration\n' "$C" "$R"
    printf '  %s7%s  Launch Codex\n' "$C" "$R"
    printf '  %s8%s  Uninstall Codex\n' "$C" "$R"
    printf '  %s9%s  Help / Commands\n' "$C" "$R"
    printf '  %sq%s  Quit\n' "$C" "$R"
    printf '\n%s?%s Select [1-9/q]: ' "$C" "$R"

    local choice
    read -r choice || choice="q"
    case "$choice" in
      1) install_codex; pause ;;
      2) update_codex; pause ;;
      3) configure_agentrouter; pause ;;
      4) test_codex; pause ;;
      5) fix_common; pause ;;
      6) show_status; pause ;;
      7) launch_codex ;;
      8) uninstall_codex; pause ;;
      9)
        title "HELP / COMMANDS"
        printf '  %sinstall%s       Install / repair Codex\n' "$C" "$R"
        printf '  %supdate%s        Update Codex\n' "$C" "$R"
        printf '  %sagentrouter%s   Configure API key + discover models\n' "$C" "$R"
        printf '  %sdoctor%s        Run diagnostics\n' "$C" "$R"
        printf '  %slaunch%s        Launch the %scodex%s command\n' "$C" "$R" "$B" "$R"
        printf '  %suninstall%s     Remove Codex\n' "$C" "$R"
        printf '\n  Codex itself: %scodex --help%s\n' "$B" "$R"
        pause
        ;;
      q|Q) clear_screen; exit 0 ;;
      *) warn "Invalid choice. Select 1-9 or q."; sleep 1 ;;
    esac
  done
}
# ─────────────────────────────────────────────────────────────────────────────
# CLI commands
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --install|install)
    ensure_termux
    install_codex
    ;;

  --update|update)
    ensure_termux
    update_codex
    ;;

  --agentrouter|agentrouter|--configure)
    ensure_termux
    configure_agentrouter
    ;;

  --doctor|doctor|--test)
    ensure_termux
    test_codex
    ;;

  --launch|launch|codex)
    ensure_termux
    launch_codex
    ;;

  --uninstall|uninstall)
    ensure_termux
    uninstall_codex
    ;;

  --help|-h|help)
    printf '\n%s%sCodex CLI Manager%s\n\n' "$B" "$C" "$R"
    printf 'Usage: bash %s [command]\n\n' "$0"
    printf '  install       Install / repair Codex\n'
    printf '  update        Update Codex\n'
    printf '  agentrouter   Configure API key + model\n'
    printf '  doctor        Run systematic diagnostics\n'
    printf '  launch        Launch Codex CLI\n'
    printf '  uninstall     Remove Codex\n'
    printf '  (no command)  Open interactive manager\n\n'
    ;;

  "")
    main_menu
    ;;

  *)
    die "Unknown command: $1. Use --help."
    ;;
esac
