#!/usr/bin/env bats
# Unit tests for provider loader

TEST_HELPER_DIR="$BATS_TEST_DIRNAME/../test_helper"
load "${TEST_HELPER_DIR}/bats-support/load"
load "${TEST_HELPER_DIR}/bats-assert/load"

PLUGIN_BASE_PATH="${BATS_TEST_DIRNAME}/../.."

setup() {
  # Create a temporary service root for testing
  export PLUGIN_DATA_ROOT=$(mktemp -d)
  export TEST_SERVICE="loader-test-$$"
  mkdir -p "$PLUGIN_DATA_ROOT/$TEST_SERVICE"
}

teardown() {
  rm -rf "$PLUGIN_DATA_ROOT"
}

@test "list_providers returns all available providers" {
  source "$PLUGIN_BASE_PATH/providers/loader.sh"

  run list_providers
  assert_success
  assert_line "mock"
  assert_line "aws"
  assert_line "smtp"
  assert_line "mailgun"
  assert_line "sendgrid"
  assert_line "resend"
}

@test "list_providers excludes _template" {
  source "$PLUGIN_BASE_PATH/providers/loader.sh"

  run list_providers
  assert_success
  refute_line "_template"
}

@test "load_provider defaults to mock when no PROVIDER file" {
  source "$PLUGIN_BASE_PATH/providers/loader.sh"

  # No PROVIDER file exists
  load_provider "$TEST_SERVICE"

  # Should have loaded mock provider variables
  assert_equal "$PROVIDER_NAME" "mock"
}

@test "load_provider reads from PROVIDER file" {
  echo "aws" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"

  load_provider "$TEST_SERVICE"

  assert_equal "$PROVIDER_NAME" "aws"
  assert_equal "$PROVIDER_DISPLAY_NAME" "AWS SES"
}

@test "load_provider fails for unknown provider" {
  echo "nonexistent" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"

  run load_provider "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Unknown provider"
}

@test "all providers define required variables" {
  local required_vars=(
    PROVIDER_NAME
    PROVIDER_DISPLAY_NAME
    PROVIDER_IMAGE
    PROVIDER_IMAGE_VERSION
    PROVIDER_SMTP_PORT
  )

  for provider in mock aws smtp mailgun sendgrid resend; do
    echo "$provider" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
    source "$PLUGIN_BASE_PATH/providers/loader.sh"
    load_provider "$TEST_SERVICE"

    for var in "${required_vars[@]}"; do
      [[ -n "${!var}" ]] || fail "Provider $provider missing $var"
    done
  done
}

@test "all providers define required functions" {
  local required_funcs=(
    provider_create_container
    provider_get_smtp_port
    provider_info
  )

  for provider in mock aws smtp mailgun sendgrid resend; do
    echo "$provider" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
    source "$PLUGIN_BASE_PATH/providers/loader.sh"
    load_provider "$TEST_SERVICE"

    for func in "${required_funcs[@]}"; do
      type "$func" &>/dev/null || fail "Provider $provider missing function $func"
    done
  done
}

@test "provider_get_smtp_port returns expected port" {
  for provider in mock aws smtp mailgun sendgrid resend; do
    echo "$provider" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
    source "$PLUGIN_BASE_PATH/providers/loader.sh"
    load_provider "$TEST_SERVICE"

    local port
    port=$(provider_get_smtp_port "$TEST_SERVICE")

    # All providers should use port 25 for internal SMTP
    assert_equal "$port" "25"
  done
}
