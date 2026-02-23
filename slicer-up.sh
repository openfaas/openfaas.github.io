#!/usr/bin/env bash

set -euo pipefail
if [[ "${SLICER_UP_DEBUG:-}" == "1" ]]; then
  set -x
fi

unset SLICER_URL SLICER_TOKEN SLICER_TOKEN_FILE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"
STATE_DIR="$SCRIPT_DIR/slicer"
ORIGINAL_PWD="$PWD"
ORIGINAL_TTY_STATE=""
if [[ -t 0 ]] && [[ -c /dev/tty ]]; then
  ORIGINAL_TTY_STATE="$(stty -g < /dev/tty 2>/dev/null || true)"
fi
mkdir -p "$STATE_DIR"
cd "$WORK_DIR"

_cleanup() {
  if [[ -n "${ORIGINAL_TTY_STATE}" ]] && [[ -e /dev/tty ]]; then
    stty "$ORIGINAL_TTY_STATE" < /dev/tty 2>/dev/null || true
  fi
  cd "$ORIGINAL_PWD" || true
}
trap _cleanup EXIT

HOST_GROUP="ofblog"
CIDR="${SLICER_CIDR:-172.31.240.0/24}"
SOCKET_PATH="./slicer/slicer.sock"
CONFIG_FILE="$STATE_DIR/slicer.yaml"
PID_FILE="$STATE_DIR/slicer.pid"
LOG_FILE="$STATE_DIR/slicer.log"
USERDATA_FILE="$STATE_DIR/userdata.sh"
HOST_PROJECT_DIR="$WORK_DIR"
HOST_PROJECT_NAME="$(basename "$HOST_PROJECT_DIR")"
GUEST_PROJECT_DIR="/home/ubuntu/$HOST_PROJECT_NAME"
SITE_SERVICE="blog.service"
LEGACY_SITE_SERVICE="ofblog-site.service"
SLICER_API_URL="$SOCKET_PATH"
VM_NAME="${HOST_GROUP}-1"
SLICER_WAIT_USERDATA="${SLICER_WAIT_USERDATA:-1}"
SLICER_SITE_URL=""

SLICER_BIN="${SLICER_BIN:-$(command -v slicer || true)}"
SLICER_BASE=(env -u SLICER_URL -u SLICER_TOKEN -u SLICER_TOKEN_FILE sudo -E "$SLICER_BIN")
SLICER_WITH_URL=(env -u SLICER_URL -u SLICER_TOKEN -u SLICER_TOKEN_FILE sudo -E "$SLICER_BIN" --url "$SLICER_API_URL" --token "")

if [[ -z "$SLICER_BIN" ]]; then
  _log "slicer binary not found in PATH"
  exit 1
fi

_usage() {
  cat <<'EOF2'
Usage:
  slicer-up.sh up
  slicer-up.sh sync-in [workspace_dir]
  slicer-up.sh sync-out [workspace_dir]
  slicer-up.sh shell
  slicer-up.sh down
  slicer-up.sh clean
  slicer-up.sh status

Notes:
  - Commands use a unix-socket API and run slicer with sudo.
  - workspace defaults to the script directory.
  - Set SLICER_CIDR to override only network range (default 172.31.240.0/24).
EOF2
}

_host_project_dir() {
  local dir="${1:-$HOST_PROJECT_DIR}"
  (cd "$dir" && pwd)
}

_cleanup_host_stale_artifacts() {
  rm -f "$WORK_DIR/$VM_NAME.img" "$WORK_DIR/vm_agent_secret"
}

_write_userdata() {
  cat <<'EOF' > "$USERDATA_FILE"
#!/usr/bin/env bash
set -euo pipefail

if [[ -f /home/ubuntu/.ofblog-deps-installed ]]; then
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends -y ruby ruby-dev make gcc build-essential libyaml-dev zlib1g-dev libreadline-dev
gem install -N bundler -v 2.2.2
touch /home/ubuntu/.ofblog-deps-installed
EOF
  chmod +x "$USERDATA_FILE"
}

_write_config() {
  mkdir -p "$STATE_DIR"
  _write_userdata
  "${SLICER_BASE[@]}" new "$HOST_GROUP" \
    --cpu 8 \
    --ram 8 \
    --api-bind "$SOCKET_PATH" \
    --api-auth=false \
    --cidr "$CIDR" \
    --storage image \
    --userdata-file "$USERDATA_FILE" \
    --count 1 \
    > "$CONFIG_FILE"
}

_is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if sudo kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  return 1
}

_api_ready() {
  "${SLICER_WITH_URL[@]}" vm list >/dev/null 2>&1
}

_has_vm() {
  local vm_name
  vm_name="$(_get_vm_name)"
  [[ -n "$vm_name" ]]
}

_discover_slicer_pids() {
  sudo pgrep -f "slicer up $CONFIG_FILE" || true
}

_update_pid_file() {
  local pids
  pids="$(_discover_slicer_pids)"
  if [[ -n "$pids" ]]; then
    echo "$pids" | tail -n 1 > "$PID_FILE"
  fi
}

_wait_for_socket() {
  local i=0
  while [[ ! -S "$SOCKET_PATH" ]]; do
    if (( i >= 120 )); then
      _log "timeout waiting for ${SOCKET_PATH}"
      _log "slicer daemon log: ${LOG_FILE}"
      return 1
    fi
    sleep 0.5
    ((i += 1))
  done
}

_wait_for_api() {
  local i=0
  while true; do
    if "${SLICER_WITH_URL[@]}" vm list >/dev/null 2>&1; then
      return 0
    fi

    if (( i >= 120 )); then
      _log "timeout waiting for slicer API on ${SOCKET_PATH}"
      _log "slicer daemon log: ${LOG_FILE}"
      return 1
    fi
    sleep 0.5
    ((i += 1))
  done
}

_get_vm_name() {
  "${SLICER_WITH_URL[@]}" vm list 2>/dev/null \
    | grep -E "^${HOST_GROUP}-[0-9]+[[:space:]]" \
    | awk '{print $1}' \
    | head -n1 \
    || true
}

_get_vm_ip() {
  local vm_name="${1:-$VM_NAME}"
  "${SLICER_WITH_URL[@]}" vm list 2>/dev/null \
    | awk -v vm="$vm_name" '$1 == vm {print $2; exit}' \
    || true
}

_wait_for_vm_ready() {
  local vm_name=""
  local attempts=0
  while [[ -z "$vm_name" && $attempts -lt 120 ]]; do
    vm_name="$(_get_vm_name)"
    if [[ -z "$vm_name" ]]; then
      sleep 0.5
      ((attempts += 1))
    fi
  done

  if [[ -z "$vm_name" ]]; then
    _log "could not find VM for host group: ${HOST_GROUP}"
    return 1
  fi

  VM_NAME="$vm_name"

  if [[ "$SLICER_WAIT_USERDATA" == "1" ]]; then
    _log "waiting for VM ${vm_name}: agent and userdata"
    if ! "${SLICER_WITH_URL[@]}" vm ready "$vm_name" --agent --userdata >/dev/null 2>&1; then
      return 1
    fi
    return
  fi
  _log "waiting for VM ${vm_name}: agent"
  if ! "${SLICER_WITH_URL[@]}" vm ready "$vm_name" --agent >/dev/null 2>&1; then
    return 1
  fi
}

_print_site_url() {
  local vm_name vm_ip url
  vm_name="$(_get_vm_name)"
  if [[ -z "$vm_name" ]]; then
    _log "site URL unavailable: VM not ready yet"
    return 1
  fi

  vm_ip="$(_get_vm_ip "$vm_name")"
  if [[ -z "$vm_ip" ]]; then
    _log "site URL unavailable: no IP for ${vm_name}"
    return 1
  fi

  url="http://$vm_ip:4000"
  SLICER_SITE_URL="$url"
  _log "site URL: $url"
  return 0
}

_check_site_health() {
  local url="${1}"
  local attempts=0
  while (( attempts < 12 )); do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
        _log "site is up and responding"
        return 0
      fi
    else
      _log "curl unavailable, skipping live check"
      return 0
    fi

    ((attempts += 1))
    sleep 1
  done

  _log "site not yet responding at ${url}"
  return 1
}

_ensure_site_service() {
  local cmd
  local has_project=1
  if _project_has_synced_content; then
    has_project=0
  fi
  cmd="cat >/etc/systemd/system/${SITE_SERVICE} <<'EOF'
[Unit]
Description=OpenFaaS website (Jekyll)
After=network-online.target
ConditionPathExists=${GUEST_PROJECT_DIR}/Gemfile

[Service]
Type=simple
User=ubuntu
Group=ubuntu
Environment=HOME=/home/ubuntu
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=${GUEST_PROJECT_DIR}
ExecStartPre=/usr/bin/mkdir -p ${GUEST_PROJECT_DIR}
ExecStartPre=/usr/bin/bash -lc 'cd ${GUEST_PROJECT_DIR} && (command -v bundle >/dev/null 2>&1 || gem install -N bundler -v 2.2.2) && (bundle check >/dev/null 2>&1 || bundle install --jobs 4 --retry 3)'
ExecStart=/bin/bash -lc 'cd ${GUEST_PROJECT_DIR} && bundle exec jekyll serve --force_polling --host 0.0.0.0 --port 4000'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${SITE_SERVICE} >/dev/null 2>&1 || true
"
  _log "ensuring systemd unit: ${SITE_SERVICE}"
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "$cmd" >/dev/null 2>&1 || true
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- \
    "systemctl stop ${LEGACY_SITE_SERVICE} >/dev/null 2>&1 || true; systemctl disable ${LEGACY_SITE_SERVICE} >/dev/null 2>&1 || true; systemctl reset-failed ${LEGACY_SITE_SERVICE} >/dev/null 2>&1 || true; rm -f /etc/systemd/system/${LEGACY_SITE_SERVICE}; systemctl daemon-reload" >/dev/null 2>&1 || true
  if (( has_project == 0 )); then
    "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- systemctl restart ${SITE_SERVICE} >/dev/null 2>&1 || true
  else
    _log "workspace not yet synced to VM; skipping service start"
  fi
}

_ensure_project_synced() {
  if _project_has_synced_content; then
    return 0
  fi

  _log "workspace not yet synced; syncing now"
  if ! _sync_project_to_vm "$HOST_PROJECT_DIR"; then
    _log "sync-in failed"
    return 1
  fi
  return 0
}

_project_has_synced_content() {
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- \
    "test -f ${GUEST_PROJECT_DIR}/Gemfile" >/dev/null 2>&1
}

_vm_cp_supports_exclude() {
  "${SLICER_WITH_URL[@]}" vm cp --help 2>/dev/null | grep -q -- "--exclude"
}

_sync_cp_excludes() {
  cat <<'EOF_EXCLUDES'
**/slicer/**
**/.git/**
**/.bundle/**
**/.Bundle/**
**/_Site/**
**/out/**
**/build/**
**/tmp/**
**/node_modules/**
**/.sass-cache/**
**/.jekyll-cache/**
**/_site/**
*.img
*.iso
vm_agent_secret
ofblog-1.img
EOF_EXCLUDES
}

_copy_project_to_vm() {
  local host_dir="$1"

  if _vm_cp_supports_exclude; then
    local excludes=( )
    while IFS= read -r pattern; do
      [[ -n "$pattern" ]] && excludes+=("--exclude" "$pattern")
    done < <(_sync_cp_excludes)

    _log "sync-in to ${VM_NAME}:${GUEST_PROJECT_DIR} using --exclude patterns"
    "${SLICER_WITH_URL[@]}" vm cp --quiet --mode=tar --uid 1000 --gid 1000 "${excludes[@]}" \
      "$host_dir/" "${VM_NAME}:${GUEST_PROJECT_DIR}/" || return 1
  else
    _log "sync-in to ${VM_NAME}:${GUEST_PROJECT_DIR} without exclusions"
    "${SLICER_WITH_URL[@]}" vm cp --quiet --mode=tar --uid 1000 --gid 1000 \
      "$host_dir/" "${VM_NAME}:${GUEST_PROJECT_DIR}/" || return 1
  fi

  return 0
}

_sync_project_to_vm() {
  local host_dir
  host_dir="$1"
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- \
    rm -rf "$GUEST_PROJECT_DIR/.git" "$GUEST_PROJECT_DIR/.bundle" "$GUEST_PROJECT_DIR/node_modules" "$GUEST_PROJECT_DIR/.sass-cache" "$GUEST_PROJECT_DIR/.jekyll-cache" "$GUEST_PROJECT_DIR/_site" >/dev/null 2>&1
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "mkdir -p ${GUEST_PROJECT_DIR}" >/dev/null 2>&1
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- \
    "rm -f ${GUEST_PROJECT_DIR}/*.img ${GUEST_PROJECT_DIR}/vm_agent_secret" >/dev/null 2>&1

  if ! _copy_project_to_vm "$host_dir"; then
    _log "sync-in failed"
    return 1
  fi

  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- chown -R 1000:1000 "${GUEST_PROJECT_DIR}" >/dev/null 2>&1
  return 0
}

_sync_in() {
  local host_dir
  host_dir="$(_host_project_dir "$1")"
  up || true
  _log "sync-in from ${host_dir} to ${VM_NAME}:${GUEST_PROJECT_DIR}"
  if ! _sync_project_to_vm "$host_dir"; then
    _log "sync-in failed"
    return 1
  fi
  _log "sync-in completed"
  _ensure_site_service
}

_sync_out() {
  local host_dir
  host_dir="$(_host_project_dir "$1")"
  _log "sync-out from ${VM_NAME}:${GUEST_PROJECT_DIR} to ${host_dir}"
  up || true

  rm -rf "$host_dir"/*
  rm -rf "$host_dir"/.[!.]* "$host_dir"/..?*

  if _vm_cp_supports_exclude; then
    _log "sync-out using --exclude patterns"
    local excludes=( )
    while IFS= read -r pattern; do
      [[ -n "$pattern" ]] && excludes+=("--exclude" "$pattern")
    done < <(_sync_cp_excludes)
    "${SLICER_WITH_URL[@]}" vm cp --quiet --mode=tar --uid 1000 --gid 1000 "${excludes[@]}" \
      "${VM_NAME}:${GUEST_PROJECT_DIR}/" "$host_dir/" || {
        _log "sync-out failed"
        return 1
      }
  else
    _log "sync-out without exclusions"
    "${SLICER_WITH_URL[@]}" vm cp --quiet --mode=tar --uid 1000 --gid 1000 \
      "${VM_NAME}:${GUEST_PROJECT_DIR}/" "$host_dir/" || {
        _log "sync-out failed"
        return 1
      }
  fi

  _log "sync-out completed"
  _ensure_site_service
}

_wait_for_exec_ready() {
  local attempts=0
  while (( attempts < 120 )); do
    if "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- uptime >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    ((attempts += 1))
  done
  return 1
}

_log() {
  printf '\r%s [slicer-up] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

up() {
  _log "starting up slicer stack"
  local vm_url
  local launcher_pid
  local running_pid=""
  _cleanup_host_stale_artifacts
  if _is_running; then
    running_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    _log "slicer already running"
    vm_url=""
    _print_site_url || true
    vm_url="${SLICER_SITE_URL:-}"
    if ! _wait_for_exec_ready; then
      _log "vm exec not stable yet; continuing"
    fi
    _ensure_project_synced || true
    _ensure_site_service
    if [[ -n "$vm_url" ]] && ! _check_site_health "$vm_url"; then
      :
    fi
    return 0
  fi
  if _api_ready; then
    if _has_vm; then
      _update_pid_file
      _wait_for_vm_ready
      if ! _wait_for_exec_ready; then
        _log "vm exec not stable yet; continuing"
      fi
      _print_site_url || true
      vm_url="${SLICER_SITE_URL:-}"
      _ensure_project_synced || true
      _ensure_site_service
      if [[ -n "$vm_url" ]] && ! _check_site_health "$vm_url"; then
        :
      fi
      _log "slicer API already active and ${VM_NAME} is ready"
      return 0
    fi
    _log "slicer API already active, but ${VM_NAME} not present; restarting"
  fi

  _write_config
  _log "starting slicer daemon"
  nohup "${SLICER_BASE[@]}" up "$CONFIG_FILE" >"$LOG_FILE" 2>&1 &
  launcher_pid=$!

  _log "waiting for socket"
  _wait_for_socket
  _log "waiting for API"
  _wait_for_api
  _log "waiting for VM ready"
  _wait_for_vm_ready
  if ! _wait_for_exec_ready; then
    _log "vm exec not stable yet; continuing"
  fi
  _print_site_url || true
  vm_url="${SLICER_SITE_URL:-}"
  _ensure_project_synced || true
  _ensure_site_service
  if [[ -n "$vm_url" ]] && ! _check_site_health "$vm_url"; then
    :
  fi
  _update_pid_file
  if ! _is_running; then
    echo "$launcher_pid" > "$PID_FILE"
  fi
  running_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  _log "slicer running: pid=$running_pid, log=$LOG_FILE"
}

_down() {
  if ! _is_running && ! _api_ready; then
    _log "slicer not running"
    return 0
  fi

  local pidfile_pid
  local daemon_pids
  if _has_vm; then
    "${SLICER_WITH_URL[@]}" vm shutdown "$VM_NAME" >/dev/null 2>&1 || true
    "${SLICER_WITH_URL[@]}" vm delete "$VM_NAME" >/dev/null 2>&1 || true
  fi
  if _is_running; then
    pidfile_pid="$(cat "$PID_FILE")"
    sudo kill -INT "$pidfile_pid" || true
  fi
  daemon_pids="$(_discover_slicer_pids)"
  if [[ -n "${daemon_pids}" ]]; then
    sudo kill -INT $daemon_pids || true
    sleep 1
    daemon_pids="$(_discover_slicer_pids)"
    if [[ -n "${daemon_pids}" ]]; then
      sudo kill -9 $daemon_pids || true
    fi
  fi

  sleep 2
  if [[ -n "${pidfile_pid:-}" ]] && sudo kill -0 "$pidfile_pid" 2>/dev/null; then
    sudo kill -9 "$pidfile_pid" || true
  fi
  rm -f "$PID_FILE"
  rm -f "$SOCKET_PATH"
  rm -f "$STATE_DIR/$VM_NAME.img"
  rm -f "$WORK_DIR/$VM_NAME.img" "$WORK_DIR/vm_agent_secret"
  _log "stopped slicer"
}

clean() {
  if [[ -z "${STATE_DIR:-}" ]]; then
    _log "refusing to clean with empty STATE_DIR"
    return 1
  fi

  _down
  rm -f "$STATE_DIR"/slicer.pid "$STATE_DIR"/slicer.yaml "$STATE_DIR"/slicer.log "$STATE_DIR"/"$VM_NAME".img "$STATE_DIR"/vm_agent_secret "$WORK_DIR"/"$VM_NAME".img "$WORK_DIR"/vm_agent_secret "$STATE_DIR"/userdata.sh "$USERDATA_FILE"
  rm -rf "$STATE_DIR"
  _cleanup_host_stale_artifacts
  _log "cleaned slicer artifacts from ${STATE_DIR}"
}

status() {
  if _is_running; then
    local running_pid=""
    running_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    _log "slicer running: pid=$running_pid"
    "${SLICER_WITH_URL[@]}" vm list
  elif _api_ready; then
    _log "slicer API active, pid file missing"
    "${SLICER_WITH_URL[@]}" vm list
  else
    _log "slicer not running"
  fi
}

shell() {
  up
  "${SLICER_WITH_URL[@]}" vm shell "$VM_NAME" --cwd "$GUEST_PROJECT_DIR"
}

main() {
  case "${1:-}" in
    up)
      up
      ;;
    sync-in)
      _sync_in "${2:-}"
      ;;
    sync-out)
      _sync_out "${2:-}"
      ;;
    shell)
      shell
      ;;
    clean)
      clean
      ;;
    down)
      _down
      ;;
    status)
      status
      ;;
    -h|--help|"")
      _usage
      ;;
    *)
      _usage
      return 1
      ;;
  esac
}

main "$@"
