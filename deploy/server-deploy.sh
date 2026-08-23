#!/bin/bash
set -euo pipefail

cd /opt/pocketpulse/source

exec 9>/run/lock/pocketpulse-deploy.lock
flock -n 9 || exit 0

expo_health() {
  local container_id
  container_id="$(docker compose ps --all --quiet expo)"
  if [[ -z "$container_id" ]]; then
    printf 'missing\n'
    return
  fi

  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id"
}

git fetch --quiet origin main
target_sha="$(git rev-parse origin/main)"
deployed_sha="$(cat .deployed-sha 2>/dev/null || true)"
blocked_sha="$(cat .blocked-sha 2>/dev/null || true)"
current_health="$(expo_health)"

if [[ "$target_sha" == "$deployed_sha" ]]; then
  case "$current_health" in
    healthy | starting)
      exit 0
      ;;
    unhealthy)
      docker compose restart expo
      ;;
    *)
      docker compose up --detach --remove-orphans expo
      ;;
  esac
  exit 0
fi

if [[ "$target_sha" == "$blocked_sha" ]]; then
  printf 'PocketPulse deployment blocked by failed CI: %s\n' "$target_sha"
  exit 0
fi

ci_result="$(python3 - "$target_sha" <<'PY'
import json
import sys
import urllib.request

sha = sys.argv[1]
url = (
    "https://api.github.com/repos/evokedreem/PocketPulse/actions/runs"
    f"?head_sha={sha}&event=push&per_page=10"
)
request = urllib.request.Request(
    url,
    headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "pocketpulse-vps-deployer",
        "X-GitHub-Api-Version": "2022-11-28",
    },
)
with urllib.request.urlopen(request, timeout=15) as response:
    runs = json.load(response).get("workflow_runs", [])

run = next((item for item in runs if item.get("name") == "Expo CI"), None)
if run is None or run.get("status") != "completed":
    print("pending")
else:
    print(run.get("conclusion") or "pending")
PY
)"

case "$ci_result" in
  success)
    ;;
  pending)
    printf 'PocketPulse waiting for CI: %s\n' "$target_sha"
    exit 0
    ;;
  *)
    printf '%s\n' "$target_sha" > .blocked-sha
    printf 'PocketPulse deployment blocked (CI=%s): %s\n' "$ci_result" "$target_sha"
    exit 0
    ;;
esac

restart_required=0
units_changed=0
if [[ -z "$deployed_sha" ]] || ! git cat-file -e "$deployed_sha^{commit}" 2>/dev/null; then
  restart_required=1
  units_changed=1
else
  while IFS= read -r changed_path; do
    case "$changed_path" in
      package.json | package-lock.json | app.json | Dockerfile | docker-compose.yml | deploy/docker-entrypoint.sh)
        restart_required=1
        ;;
      deploy/pocketpulse-deploy.service | deploy/pocketpulse-deploy.timer)
        units_changed=1
        ;;
    esac
  done < <(git diff --name-only "$deployed_sha" "$target_sha")
fi

git reset --hard --quiet "$target_sha"

if [[ "$units_changed" -eq 1 ]]; then
  install -m 0644 deploy/pocketpulse-deploy.service /etc/systemd/system/pocketpulse-deploy.service
  install -m 0644 deploy/pocketpulse-deploy.timer /etc/systemd/system/pocketpulse-deploy.timer
  systemctl daemon-reload
fi

if [[ "$restart_required" -eq 1 ]]; then
  docker compose build --pull expo
  docker compose up --detach --remove-orphans expo
else
  case "$(expo_health)" in
    healthy | starting)
      ;;
    unhealthy)
      docker compose restart expo
      ;;
    *)
      docker compose up --detach --remove-orphans expo
      ;;
  esac
fi

printf '%s\n' "$target_sha" > .deployed-sha
printf 'PocketPulse deployed: %s (restart=%s)\n' "$target_sha" "$restart_required"
