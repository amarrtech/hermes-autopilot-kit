#!/usr/bin/env bash
set -euo pipefail

APP_NAME="hermes-autopilot"
INSTALL_DIR="${HERMES_AUTOPILOT_HOME:-$HOME/.hermes-autopilot}"
DATA_DIR="$INSTALL_DIR/data"
BRAIN_DIR="$INSTALL_DIR/brain"
RECEIPT_DIR="$BRAIN_DIR/receipts"
BIN_DIR="$INSTALL_DIR/bin"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
ENV_FILE="$INSTALL_DIR/.env"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARN: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

prompt() {
  local name="$1" default="${2:-}" value
  if [ -n "$default" ]; then
    read -r -p "$name [$default]: " value </dev/tty
    printf '%s' "${value:-$default}"
  else
    read -r -p "$name: " value </dev/tty
    printf '%s' "$value"
  fi
}

prompt_secret() {
  local name="$1" value
  read -r -s -p "$name (hidden, leave blank to skip): " value </dev/tty
  printf '\n' >&2
  printf '%s' "$value"
}

ensure_docker() {
  if need_cmd docker; then
    return 0
  fi

  warn "Docker is not installed."
  if [ "$(uname -s)" = "Linux" ] && need_cmd curl; then
    read -r -p "Install Docker using get.docker.com? [y/N]: " yn </dev/tty
    case "$yn" in
      y|Y|yes|YES)
        curl -fsSL https://get.docker.com | sh
        ;;
      *)
        die "Install Docker first, then rerun this installer."
        ;;
    esac
  else
    die "Install Docker Desktop or Docker Engine first, then rerun this installer."
  fi
}

docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif need_cmd docker-compose; then
    docker-compose "$@"
  else
    die "Docker Compose is required."
  fi
}

write_env() {
  say "Collecting minimal configuration"
  local channel model_provider model_name discord_token slack_token github_repo github_token
  channel="$(prompt "Chat platform: discord or slack" "discord")"
  model_provider="$(prompt "Model provider label" "openai")"
  model_name="$(prompt "Default model name" "gpt-5.5")"
  discord_token=""
  slack_token=""
  if [ "$channel" = "discord" ]; then
    discord_token="$(prompt_secret "Discord bot token")"
  elif [ "$channel" = "slack" ]; then
    slack_token="$(prompt_secret "Slack bot token")"
  else
    warn "Unknown chat platform '$channel'. Hermes setup wizard can finish gateway config later."
  fi
  github_repo="$(prompt "GitHub backup repo URL (optional)" "")"
  github_token="$(prompt_secret "GitHub token for backup pushes")"

  umask 077
  cat > "$ENV_FILE" <<EOF
AUTOPILOT_NAME=Hermes Autopilot
AUTOPILOT_CHANNEL=$channel
MODEL_PROVIDER=$model_provider
MODEL_NAME=$model_name
DISCORD_BOT_TOKEN=$discord_token
SLACK_BOT_TOKEN=$slack_token
GITHUB_BACKUP_REPO=$github_repo
GITHUB_TOKEN=$github_token
HERMES_DATA_PATH=$DATA_DIR
BRAIN_REPO_PATH=$BRAIN_DIR
EOF
}

write_compose() {
  cat > "$COMPOSE_FILE" <<EOF
services:
  hermes:
    image: nousresearch/hermes-agent:latest
    container_name: hermes-autopilot
    restart: unless-stopped
    command: gateway run
    ports:
      - "8642:8642"
      - "9119:9119"
    volumes:
      - "$DATA_DIR:/opt/data"
    environment:
      - HERMES_DASHBOARD=1
EOF
}

write_scripts() {
  mkdir -p "$BIN_DIR" "$RECEIPT_DIR" "$BRAIN_DIR/scorecards" "$BRAIN_DIR/synthesis" "$BRAIN_DIR/inbox"

  cat > "$BIN_DIR/write-receipt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
brain="${BRAIN_REPO_PATH:-$HOME/.hermes-autopilot/brain}"
job="${1:-manual}"
status="${2:-ok}"
day="$(date -u +%F)"
dir="$brain/receipts/$day"
mkdir -p "$dir"
file="$dir/$job-$(date -u +%H%M%S).md"
cat > "$file" <<EOR
---
type: receipt
job_id: $job
status: $status
created_utc: "$(date -u +%FT%TZ)"
---

# $job Receipt

- Trigger: manual or scheduled
- Inputs: see job logs
- Files changed: unknown
- Checks passed: pending
- Checks failed: pending
- User attention needed: none recorded
- Next run: see scheduler
EOR
echo "$file"
EOF

  cat > "$BIN_DIR/gateway-health" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
compose_dir="${HERMES_AUTOPILOT_HOME:-$HOME/.hermes-autopilot}"
export BRAIN_REPO_PATH="${BRAIN_REPO_PATH:-$compose_dir/brain}"
if docker ps --format '{{.Names}}' | grep -qx hermes-autopilot; then
  "$compose_dir/bin/write-receipt" gateway-health ok >/dev/null
  echo "gateway ok"
else
  "$compose_dir/bin/write-receipt" gateway-health failed >/dev/null
  echo "gateway failed"
  exit 1
fi
EOF

  cat > "$BIN_DIR/weekly-scorecard" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
brain="${BRAIN_REPO_PATH:-$HOME/.hermes-autopilot/brain}"
mkdir -p "$brain/scorecards"
week="$(date -u +%G-W%V)"
file="$brain/scorecards/$week.md"
failed="$(find "$brain/receipts" -type f -name '*.md' -print0 2>/dev/null | xargs -0 grep -l 'status: failed' 2>/dev/null | wc -l | tr -d ' ')"
cat > "$file" <<EOF2
---
type: scorecard
slug: scorecards/$week
created_utc: "$(date -u +%FT%TZ)"
---

# Hermes Autopilot Scorecard $week

- repeat_mistakes: 0
- failed_jobs: $failed
- noisy_alerts: 0
- skills_changed: 0
- brain_pages_added: $(find "$brain" -type f -name '*.md' | wc -l | tr -d ' ')
- contradiction_candidates: 0
- backup_status: unknown

## Next Actions

- Review failed receipts.
- Add or refine checks for repeated failures.
- Keep deterministic checks no-agent by default.
EOF2
echo "$file"
EOF

  chmod +x "$BIN_DIR/write-receipt" "$BIN_DIR/gateway-health" "$BIN_DIR/weekly-scorecard"
}

init_brain_repo() {
  if [ ! -d "$BRAIN_DIR/.git" ]; then
    git init "$BRAIN_DIR" >/dev/null
    cat > "$BRAIN_DIR/README.md" <<'EOF'
# BrainCache

Markdown-first memory for Hermes Autopilot.

Important folders:

- `receipts/` — run receipts
- `scorecards/` — weekly self-improvement reports
- `synthesis/` — contradiction scans and topic synthesis
- `inbox/` — raw captures waiting for cleanup
EOF
    git -C "$BRAIN_DIR" add README.md
    git -C "$BRAIN_DIR" commit -m "init BrainCache" >/dev/null || true
  fi
}

install_cron() {
  if ! need_cmd crontab; then
    warn "crontab not found; skipping local scheduled jobs."
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  crontab -l 2>/dev/null | grep -v "hermes-autopilot" > "$tmp" || true
  cat >> "$tmp" <<EOF
*/15 * * * * HERMES_AUTOPILOT_HOME="$INSTALL_DIR" BRAIN_REPO_PATH="$BRAIN_DIR" "$BIN_DIR/gateway-health" >> "$INSTALL_DIR/gateway-health.log" 2>&1 # hermes-autopilot
10 8 * * 0 HERMES_AUTOPILOT_HOME="$INSTALL_DIR" BRAIN_REPO_PATH="$BRAIN_DIR" "$BIN_DIR/weekly-scorecard" >> "$INSTALL_DIR/weekly-scorecard.log" 2>&1 # hermes-autopilot
EOF
  crontab "$tmp"
  rm -f "$tmp"
}

print_next_steps() {
  cat <<EOF

Hermes Autopilot files are ready:

  $INSTALL_DIR

Next:

1. Re-run Hermes setup any time:

   docker run -it --rm -v "$DATA_DIR:/opt/data" nousresearch/hermes-agent setup

2. Restart gateway:

   cd "$INSTALL_DIR"
   docker compose up -d

3. Verify:

   docker exec -it hermes-autopilot hermes doctor
   docker exec -it hermes-autopilot hermes gateway status
   "$BIN_DIR/gateway-health"
   "$BIN_DIR/weekly-scorecard"

Manual steps still required:

- Create Discord or Slack app/token.
- Provide model provider auth.
- Create GitHub backup repo/token if you want automated pushes.

EOF
}

main() {
  say "Hermes Autopilot Kit installer"
  ensure_docker
  need_cmd git || die "git is required."
  mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$BRAIN_DIR" "$BIN_DIR"
  if [ ! -f "$ENV_FILE" ]; then
    write_env
  else
    say "Using existing $ENV_FILE"
  fi
  write_compose
  write_scripts
  init_brain_repo
  install_cron
  say "Pulling Hermes image"
  docker pull nousresearch/hermes-agent:latest
  if [ ! -f "$DATA_DIR/config.yaml" ]; then
    say "Launching Hermes setup wizard"
    docker run -it --rm -v "$DATA_DIR:/opt/data" nousresearch/hermes-agent setup </dev/tty >/dev/tty
  else
    say "Hermes config already exists; skipping setup wizard"
  fi
  say "Starting Hermes gateway container"
  docker_compose -f "$COMPOSE_FILE" up -d
  "$BIN_DIR/write-receipt" install ok >/dev/null
  print_next_steps
}

main "$@"
