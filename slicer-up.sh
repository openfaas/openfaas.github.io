#!/usr/bin/env bash

set -euo pipefail
if [[ "${SLICER_UP_DEBUG:-}" == "1" ]]; then
  set -x
fi

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

HOST_GROUP="${SLICER_HOST_GROUP:-}"
SOCKET_PATH="./slicer/slicer.sock"
PID_FILE="$STATE_DIR/slicer.pid"
LOG_FILE="$STATE_DIR/slicer.log"
USERDATA_FILE="$STATE_DIR/userdata.sh"
HOST_PROJECT_DIR="$WORK_DIR"
HOST_PROJECT_NAME="$(basename "$HOST_PROJECT_DIR")"
GUEST_PROJECT_DIR="/home/ubuntu/$HOST_PROJECT_NAME"
SITE_SERVICE="blog.service"
LEGACY_SITE_SERVICE="ofblog-site.service"
SLICER_URL="${SLICER_URL:-}"
VM_NAME="${HOST_GROUP}-1"
DEFAULT_HOST_GROUP="ofblog"
MAC_HOST_GROUP="sbox"
SLICER_VM_TAG="${SLICER_VM_TAG:-openfaas-blog}"
SLICER_WAIT_USERDATA="${SLICER_WAIT_USERDATA:-1}"
SLICER_SITE_URL=""
SLICER_CONTEXT_CONFIGURED="0"
SLICER_CREATED_VM_NAME=""
SLICER_TOKEN="${SLICER_TOKEN:-}"
SLICER_TOKEN_FILE="${SLICER_TOKEN_FILE:-}"
SLICER_USE_VM_FORWARD="${SLICER_USE_VM_FORWARD:-0}"
SLICER_VM_FORWARD_HOST="${SLICER_VM_FORWARD_HOST:-127.0.0.1}"
SLICER_VM_FORWARD_PORT="${SLICER_VM_FORWARD_PORT:-4000}"
VM_FORWARD_PID_FILE="$STATE_DIR/slicer-site-forward.pid"
VM_FORWARD_LOG_FILE="$STATE_DIR/slicer-site-forward.log"

SLICER_BIN="${SLICER_BIN:-$(command -v slicer || command -v slicer-mac || true)}"
SLICER_WITH_URL=("$SLICER_BIN")

_configure_slicer_with_url() {
  local cmd=(env -u SLICER_URL "$SLICER_BIN")
  if [[ -n "${SLICER_TOKEN:-}" ]]; then
    cmd+=(--token "$SLICER_TOKEN")
  elif [[ -n "${SLICER_TOKEN_FILE:-}" ]]; then
    cmd+=(--token-file "$SLICER_TOKEN_FILE")
  else
    cmd+=(--token "")
  fi

  SLICER_WITH_URL=("${cmd[@]}")
  if [[ -n "$SLICER_URL" ]]; then
    SLICER_WITH_URL+=(--url "$SLICER_URL")
  fi
}

if [[ -z "$SLICER_BIN" ]]; then
  _log "slicer binary not found in PATH"
  exit 1
fi
_configure_slicer_with_url

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
  - Commands use a unix-socket API.
  - If SLICER_INFO reports Server OS=darwin and arch=arm64, defaults use slicer-mac conventions.
  - If SLICER_URL is unset, defaults are local slicer-mac socket conventions when applicable.
- Set SLICER_TOKEN or SLICER_TOKEN_FILE for remote slicer API access.
- Set SLICER_USE_VM_FORWARD=1 to use forwarded localhost access when VM IP is not reachable.
  - workspace defaults to the script directory.
  - Set SLICER_HOST_GROUP to override VM host group.
  - Set SLICER_VM_TAG to pass a launch tag (default openfaas-blog).
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

_is_running() {
  _api_ready
}

_api_ready() {
  "${SLICER_WITH_URL[@]}" vm list >/dev/null 2>&1
}

_has_vm() {
  local vm_name
  vm_name="$(_get_vm_name)"
  [[ -n "$vm_name" ]]
}

_wait_for_socket() {
  if [[ "$SLICER_URL" != /* && "$SLICER_URL" != unix://* ]]; then
    return 0
  fi
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

_query_slicer_info() {
  "${SLICER_WITH_URL[@]}" info 2>/dev/null || true
}

_configure_runtime_from_slicer_info() {
  if [[ "$SLICER_CONTEXT_CONFIGURED" == "1" ]]; then
    return 0
  fi

  local info server_os server_arch tagged_vm
  info="$(_query_slicer_info)"
  tagged_vm="$("${SLICER_WITH_URL[@]}" vm list 2>/dev/null | awk -v tag="${SLICER_VM_TAG:-}" '$NF == tag && tag != "" {print $1; exit}')"
  if [[ -n "$info" ]]; then
    server_os="$(printf '%s\n' "$info" | awk -F: '/^Server OS:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print tolower($2)}' | head -n1)"
    server_arch="$(printf '%s\n' "$info" | awk -F: '/^Server arch:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print tolower($2)}' | head -n1)"

    if [[ -z "${SLICER_HOST_GROUP:-}" ]]; then
      if [[ -n "$tagged_vm" ]]; then
        HOST_GROUP="${tagged_vm%%-*}"
        VM_NAME="$tagged_vm"
      elif [[ "$server_os" == "darwin" && "$server_arch" == "arm64" ]]; then
        HOST_GROUP="$MAC_HOST_GROUP"
        VM_NAME="${HOST_GROUP}-1"
      else
        HOST_GROUP="$DEFAULT_HOST_GROUP"
        VM_NAME="${HOST_GROUP}-1"
      fi
    fi

    if [[ -z "${SLICER_URL}" && "$server_os" == "darwin" && "$server_arch" == "arm64" ]]; then
      SLICER_URL="/Users/alex/slicer-mac/slicer.sock"
      SOCKET_PATH="$SLICER_URL"
    fi
  elif [[ -z "${SLICER_HOST_GROUP:-}" ]]; then
    HOST_GROUP="$DEFAULT_HOST_GROUP"
    VM_NAME="${HOST_GROUP}-1"
  fi

  if [[ -z "$SLICER_URL" ]]; then
    SLICER_URL="$SOCKET_PATH"
  fi

  _configure_slicer_with_url
  SLICER_CONTEXT_CONFIGURED="1"
}

_cleanup_vm() {
  local vm_name="${1:-}"
  if [[ -z "$vm_name" ]]; then
    return 0
  fi

  "${SLICER_WITH_URL[@]}" vm shutdown "$vm_name" >/dev/null 2>&1 || true
  "${SLICER_WITH_URL[@]}" vm delete "$vm_name" >/dev/null 2>&1 || true
}

_cleanup_created_vm() {
  if [[ -n "$SLICER_CREATED_VM_NAME" ]]; then
    _cleanup_vm "$SLICER_CREATED_VM_NAME"
    SLICER_CREATED_VM_NAME=""
  fi
}

_launch_vm() {
  local launch_cmd=( "${SLICER_WITH_URL[@]}" vm launch "$HOST_GROUP" --userdata-file "$USERDATA_FILE" )
  _write_userdata
  if [[ -n "$SLICER_VM_TAG" ]]; then
    launch_cmd+=(--tag "$SLICER_VM_TAG")
  fi

  _log "launching vm via ${HOST_GROUP} with tag ${SLICER_VM_TAG}"
  if ! "${launch_cmd[@]}" >/dev/null 2>&1; then
    _log "failed to launch vm"
    return 1
  fi
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
  local vm_name=""
  if [[ -n "${SLICER_VM_TAG:-}" ]]; then
    vm_name="$(
      "${SLICER_WITH_URL[@]}" vm list 2>/dev/null \
        | awk -v tag="${SLICER_VM_TAG}" '$NF == tag {print $1}' \
        | head -n1 \
        || true
    )"
  else
    vm_name="$(
      "${SLICER_WITH_URL[@]}" vm list 2>/dev/null \
        | awk -v host="${HOST_GROUP}" '$1 ~ "^" host "-[0-9]+$" {print $1}' \
        | head -n1 \
        || true
    )"
  fi
  echo "$vm_name"
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
  if [[ -z "${SLICER_CREATED_VM_NAME:-}" ]]; then
    SLICER_CREATED_VM_NAME="$vm_name"
  fi

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

_predict_next_vm_name() {
  local host="${HOST_GROUP}"
  local vm max_index=0 index

  while IFS= read -r vm; do
    index="${vm#${host}-}"
    if [[ "${index}" =~ ^[0-9]+$ ]] && (( index > max_index )); then
      max_index="$index"
    fi
  done < <(
    "${SLICER_WITH_URL[@]}" vm list 2>/dev/null \
      | awk -v host="${host}" '$1 ~ "^" host "-[0-9]+$" {print $1}' \
      || true
  )

  echo "${host}-$((max_index + 1))"
}

_print_site_url() {
  local vm_name vm_ip url
  vm_name="$(_get_vm_name)"
  if [[ -z "$vm_name" ]]; then
    _log "site URL unavailable: VM not ready yet"
    return 1
  fi

  if [[ "$SLICER_USE_VM_FORWARD" == "1" ]]; then
    if _ensure_vm_forward; then
      url="http://${SLICER_VM_FORWARD_HOST}:${SLICER_VM_FORWARD_PORT}"
      SLICER_SITE_URL="$url"
      _log "site URL: $url (via vm forward)"
      return 0
    fi
    _log "vm forward unavailable; falling back to direct VM ip"
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

_ensure_vm_forward() {
  local pid port_busy forward_pid

  if _forward_port_listening; then
    _log "site-forward port ${SLICER_VM_FORWARD_PORT} already in use; cannot start vm forward"
    return 1
  fi

  if [[ -f "$VM_FORWARD_PID_FILE" ]]; then
    pid="$(cat "$VM_FORWARD_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      if _forward_port_listening; then
        return 0
      fi
      _stop_vm_forward || true
    fi
    rm -f "$VM_FORWARD_PID_FILE"
  fi

  mkdir -p "$STATE_DIR"
  nohup "${SLICER_WITH_URL[@]}" vm forward "$VM_NAME" -L "${SLICER_VM_FORWARD_HOST}:${SLICER_VM_FORWARD_PORT}:127.0.0.1:4000" \
    >> "$VM_FORWARD_LOG_FILE" 2>&1 </dev/null &
  forward_pid=$!
  disown "$forward_pid" >/dev/null 2>&1 || true
  echo "$forward_pid" > "$VM_FORWARD_PID_FILE"

  if _wait_for_forward "$forward_pid"; then
    return 0
  fi

  if kill -0 "$forward_pid" 2>/dev/null; then
    kill "$forward_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$VM_FORWARD_PID_FILE"
  return 1
}

_wait_for_forward() {
  local attempts=0
  while (( attempts < 12 )); do
    if _forward_port_listening; then
      return 0
    fi
    sleep 0.25
    ((attempts += 1))
  done
  return 1
}

_forward_port_listening() {
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$SLICER_VM_FORWARD_PORT" >/dev/null 2>&1
    return $?
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP -P -n -sTCP:LISTEN 2>/dev/null | grep -qE "(^|[[:space:]])127\\.0\\.0\\.1:${SLICER_VM_FORWARD_PORT}([[:space:]]|$)"
    return $?
  fi

  return 1
}

_stop_vm_forward() {
  if [[ ! -f "$VM_FORWARD_PID_FILE" ]]; then
    return 0
  fi

  local pid
  pid="$(cat "$VM_FORWARD_PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -f "$VM_FORWARD_PID_FILE"
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

_blog_service_running_jekyll() {
  "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "pgrep -af 'bundle exec jekyll serve' >/dev/null 2>&1"
}

_blog_service_running_expected() {
  local main_pid cmdline
  main_pid="$("${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "systemctl show -p MainPID --value ${SITE_SERVICE} 2>/dev/null || true")"
  [[ -n "$main_pid" ]] || return 1
  if [[ "$main_pid" == "0" ]]; then
    return 1
  fi
  cmdline="$("${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "cat /proc/${main_pid}/cmdline 2>/dev/null | tr '\\0' ' ' || true")"
  [[ -n "$cmdline" ]] || return 1

  if [[ "$cmdline" == *"python3 -m http.server 4000 --bind 0.0.0.0"* ]]; then
    return 1
  fi

  # Primary safety check: this VM is serving Jekyll.
  [[ "$cmdline" == *"bundle exec jekyll serve"* ]] && return 0
}

_blog_service_active() {
  local state
  state="$("${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "systemctl is-active ${SITE_SERVICE} 2>/dev/null || true")"
  [[ "$state" == "active" ]]
}

_blog_service_has_expected_exec() {
  local service_exec
  service_exec="$("${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- "systemctl show -p ExecStart --value ${SITE_SERVICE}")"
  [[ -n "$service_exec" ]] || return 1
  [[ "$service_exec" == *"bundle exec jekyll serve --force_polling --host 0.0.0.0 --port 4000"* ]] && \
    [[ "$service_exec" != *"|| (cd ${GUEST_PROJECT_DIR}/_site && python3 -m http.server 4000 --bind 0.0.0.0)"* ]]
}

_ensure_site_service() {
  local skip_restart_if_active=0
  local cmd
  if [[ "${1:-0}" == "1" ]]; then
    skip_restart_if_active=1
  fi
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
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/ubuntu/.local/share/gem/ruby/3.2.0/bin
Environment=BUNDLE_PATH=/home/ubuntu/.bundle
Environment=JEKYLL_ENV=production
Environment=PAGES_REPO_NWO=openfaas/openfaas.github.io
WorkingDirectory=${GUEST_PROJECT_DIR}
ExecStartPre=/usr/bin/mkdir -p ${GUEST_PROJECT_DIR}
ExecStartPre=/usr/bin/bash -lc 'cd ${GUEST_PROJECT_DIR} && (command -v bundle >/dev/null 2>&1 || (mkdir -p /home/ubuntu/.local/share/gem && gem install -N bundler -v 2.2.2 --user-install)) && (bundle check >/dev/null 2>&1 || bundle install --jobs 4 --retry 3)'
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
    if _blog_service_active; then
      if _blog_service_running_jekyll; then
        _log "blog service already running expected jekyll on ${VM_NAME}; skipping restart"
      elif [[ "$skip_restart_if_active" == "1" ]]; then
        _log "blog service active but command not expected on ${VM_NAME}; skipping restart by request"
      else
        _log "blog service active but command not expected on ${VM_NAME}; restarting"
        "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- systemctl restart ${SITE_SERVICE} >/dev/null 2>&1 || true
      fi
    else
      _log "starting blog.service on ${VM_NAME}"
      "${SLICER_WITH_URL[@]}" vm exec "$VM_NAME" --uid 0 -- systemctl restart ${SITE_SERVICE} >/dev/null 2>&1 || true
    fi
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
**/vendor/**
**/.git/**
**/.bundle/**
**/.Bundle/**
**/_site/**
**/_Site/**
**/out/**
**/build/**
**/tmp/**
**/node_modules/**
**/.sass-cache/**
**/.jekyll-cache/**
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
    rm -rf "$GUEST_PROJECT_DIR/.git" "$GUEST_PROJECT_DIR/.bundle" "$GUEST_PROJECT_DIR/vendor" "$GUEST_PROJECT_DIR/node_modules" "$GUEST_PROJECT_DIR/.sass-cache" "$GUEST_PROJECT_DIR/_site" >/dev/null 2>&1
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
  _ensure_site_service 1
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
  _ensure_site_service 1
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
  local vm_created=0
  _configure_runtime_from_slicer_info
  _cleanup_host_stale_artifacts
  SLICER_CREATED_VM_NAME=""
  if ! _api_ready; then
    _log "slicer API is not reachable at ${SLICER_URL}"
    return 1
  fi

  if _has_vm; then
    _log "found existing vm for ${HOST_GROUP}"
    _wait_for_vm_ready
  else
    _log "no existing vm found; launching"
    SLICER_CREATED_VM_NAME="$(_predict_next_vm_name)"
    if ! _launch_vm; then
      _cleanup_created_vm
      return 1
    fi
    vm_created=1
    if ! _wait_for_vm_ready; then
      _cleanup_created_vm
      return 1
    fi
    SLICER_CREATED_VM_NAME="$VM_NAME"
  fi
  if ! _wait_for_socket; then
    if (( vm_created == 1 )); then
      _cleanup_created_vm
    fi
    return 1
  fi
  if ! _wait_for_api; then
    if (( vm_created == 1 )); then
      _cleanup_created_vm
    fi
    return 1
  fi
  if ! _wait_for_exec_ready; then
    _log "vm exec not stable yet; continuing"
  fi
  _print_site_url || true
  vm_url="${SLICER_SITE_URL:-}"
  if ! _ensure_project_synced; then
    if (( vm_created == 1 )); then
      _cleanup_created_vm
    fi
    return 1
  fi
  _ensure_site_service
  if [[ -n "$vm_url" ]] && ! _check_site_health "$vm_url"; then
    :
  fi
  return 0
}

_down() {
  _configure_runtime_from_slicer_info
  if ! _is_running; then
    _log "slicer not running"
    return 0
  fi

  local pidfile_pid
  if _has_vm; then
    "${SLICER_WITH_URL[@]}" vm shutdown "$VM_NAME" >/dev/null 2>&1 || true
    "${SLICER_WITH_URL[@]}" vm delete "$VM_NAME" >/dev/null 2>&1 || true
  fi
  if [[ -f "$PID_FILE" ]]; then
    pidfile_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pidfile_pid" ]] && sudo kill -0 "$pidfile_pid" 2>/dev/null; then
      sudo kill -INT "$pidfile_pid" || true
      sleep 1
      sudo kill -9 "$pidfile_pid" || true
    fi
  fi

  sleep 2
  rm -f "$PID_FILE"
  if [[ "$SOCKET_PATH" == "$WORK_DIR/"* ]] && [[ -f "$SOCKET_PATH" ]]; then
    rm -f "$SOCKET_PATH"
  fi
  rm -f "$STATE_DIR/$VM_NAME.img"
  rm -f "$WORK_DIR/$VM_NAME.img" "$WORK_DIR/vm_agent_secret"
  _stop_vm_forward || true
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
  _configure_runtime_from_slicer_info
  if _is_running; then
    _log "slicer running"
    "${SLICER_WITH_URL[@]}" vm list
  elif _api_ready; then
    _log "slicer running, pid file missing"
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
