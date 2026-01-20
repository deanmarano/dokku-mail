#!/usr/bin/env bash
# Common test utilities for dokku-mail BATS tests

# Load bats helpers
load 'bats-support/load'
load 'bats-assert/load'

# Test configuration
export TEST_SERVICE_PREFIX="test-mail-$$"
export TEST_APP_PREFIX="test-app-$$"
export PLUGIN_PATH="${BATS_TEST_DIRNAME}/../.."
export PLUGIN_DATA_ROOT="${PLUGIN_DATA_ROOT:-/var/lib/dokku/services/mail}"

# Track created resources for cleanup
declare -a CREATED_SERVICES=()
declare -a CREATED_APPS=()

# =============================================================================
# SETUP/TEARDOWN HELPERS
# =============================================================================

# Create an isolated test service
# Usage: setup_test_service [name]
setup_test_service() {
  local name="${1:-${TEST_SERVICE_PREFIX}-$(date +%s)}"
  CREATED_SERVICES+=("$name")

  dokku mail:create "$name"
  echo "$name"
}

# Teardown a test service
# Usage: teardown_test_service <name>
teardown_test_service() {
  local name="$1"
  dokku mail:destroy "$name" --force 2>/dev/null || true
}

# Cleanup all test services created during test
cleanup_test_services() {
  for service in "${CREATED_SERVICES[@]}"; do
    teardown_test_service "$service"
  done
  CREATED_SERVICES=()
}

# Create a test app (stub)
# Usage: setup_test_app [name]
setup_test_app() {
  local name="${1:-${TEST_APP_PREFIX}-$(date +%s)}"
  CREATED_APPS+=("$name")

  # Create minimal app structure
  dokku apps:create "$name" 2>/dev/null || true
  echo "$name"
}

# Cleanup all test apps
cleanup_test_apps() {
  for app in "${CREATED_APPS[@]}"; do
    dokku apps:destroy "$app" --force 2>/dev/null || true
  done
  CREATED_APPS=()
}

# Full cleanup
cleanup_all() {
  cleanup_test_services
  cleanup_test_apps
}

# =============================================================================
# CONTAINER HELPERS
# =============================================================================

# Wait for a container to be running
# Usage: wait_for_container <container_name> [timeout_seconds]
wait_for_container() {
  local container="$1"
  local timeout="${2:-30}"
  local elapsed=0

  while [[ $elapsed -lt $timeout ]]; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      return 0
    fi
    sleep 1
    ((elapsed++))
  done

  return 1
}

# Check if container is running
# Usage: container_is_running <container_name>
container_is_running() {
  local container="$1"
  docker ps --format '{{.Names}}' | grep -q "^${container}$"
}

# Get container IP address
# Usage: get_container_ip <container_name>
get_container_ip() {
  local container="$1"
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null
}

# =============================================================================
# SMTP HELPERS
# =============================================================================

# Send a test email via SMTP
# Usage: send_test_email <host> <port> <from> <to> [subject] [body]
send_test_email() {
  local host="$1"
  local port="$2"
  local from="$3"
  local to="$4"
  local subject="${5:-Test Email}"
  local body="${6:-This is a test email}"

  # Use swaks if available, fall back to nc
  if command -v swaks &>/dev/null; then
    swaks --to "$to" --from "$from" \
          --server "$host" --port "$port" \
          --header "Subject: $subject" \
          --body "$body" \
          --timeout 10 2>&1
  else
    # Basic SMTP via nc
    {
      echo "HELO test"
      sleep 0.5
      echo "MAIL FROM:<$from>"
      sleep 0.5
      echo "RCPT TO:<$to>"
      sleep 0.5
      echo "DATA"
      sleep 0.5
      echo "Subject: $subject"
      echo "From: $from"
      echo "To: $to"
      echo ""
      echo "$body"
      echo "."
      sleep 0.5
      echo "QUIT"
    } | nc -w 10 "$host" "$port" 2>&1
  fi
}

# Check if SMTP port is accepting connections
# Usage: smtp_port_open <host> <port>
smtp_port_open() {
  local host="$1"
  local port="$2"
  nc -z -w5 "$host" "$port" 2>/dev/null
}

# =============================================================================
# ASSERTION HELPERS
# =============================================================================

# Assert service exists
# Usage: assert_service_exists <service_name>
assert_service_exists() {
  local service="$1"
  [[ -d "$PLUGIN_DATA_ROOT/$service" ]]
}

# Assert service does not exist
# Usage: refute_service_exists <service_name>
refute_service_exists() {
  local service="$1"
  [[ ! -d "$PLUGIN_DATA_ROOT/$service" ]]
}

# Assert provider is set
# Usage: assert_provider_is <service_name> <provider>
assert_provider_is() {
  local service="$1"
  local expected="$2"
  local actual
  actual=$(cat "$PLUGIN_DATA_ROOT/$service/PROVIDER" 2>/dev/null)
  [[ "$actual" == "$expected" ]]
}

# Assert app is linked to service
# Usage: assert_app_linked <service_name> <app_name>
assert_app_linked() {
  local service="$1"
  local app="$2"
  grep -q "^${app}$" "$PLUGIN_DATA_ROOT/$service/LINKS" 2>/dev/null
}

# Assert config value is set
# Usage: assert_config_set <service_name> <key> [expected_value]
assert_config_set() {
  local service="$1"
  local key="$2"
  local expected="${3:-}"
  local config_file="$PLUGIN_DATA_ROOT/$service/provider-config/$key"

  [[ -f "$config_file" ]] || return 1

  if [[ -n "$expected" ]]; then
    local actual
    actual=$(cat "$config_file")
    [[ "$actual" == "$expected" ]]
  fi
}

# =============================================================================
# OUTPUT HELPERS
# =============================================================================

# Print test debug info
debug() {
  echo "# DEBUG: $*" >&3
}

# Print separator for readability
print_separator() {
  echo "# ========================================" >&3
}
