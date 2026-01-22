#!/usr/bin/env bats
# Unit tests for provider config validation

TEST_HELPER_DIR="$BATS_TEST_DIRNAME/../test_helper"
load "${TEST_HELPER_DIR}/bats-support/load"
load "${TEST_HELPER_DIR}/bats-assert/load"

PLUGIN_BASE_PATH="${BATS_TEST_DIRNAME}/../.."

setup() {
  export PLUGIN_DATA_ROOT=$(mktemp -d)
  export TEST_SERVICE="config-test-$$"
  mkdir -p "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config"
}

teardown() {
  rm -rf "$PLUGIN_DATA_ROOT"
}

# =============================================================================
# AWS Provider Validation
# =============================================================================

@test "aws provider_validate_config fails with missing config" {
  echo "aws" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "aws provider_validate_config fails with invalid region format" {
  echo "aws" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "AKIAEXAMPLE" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "secret123" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"
  echo "invalid-region" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/AWS_REGION"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid AWS_REGION format"
}

@test "aws provider_validate_config passes with valid config" {
  echo "aws" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "AKIAEXAMPLE" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "secret123" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"
  echo "us-east-1" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/AWS_REGION"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}

# =============================================================================
# SMTP Provider Validation
# =============================================================================

@test "smtp provider_validate_config fails with missing config" {
  echo "smtp" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "smtp provider_validate_config fails with non-numeric port" {
  echo "smtp" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "smtp.example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_HOST"
  echo "abc" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PORT"
  echo "user" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "pass" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "SMTP_PORT must be a number"
}

@test "smtp provider_validate_config fails with invalid TLS mode" {
  echo "smtp" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "smtp.example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_HOST"
  echo "587" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PORT"
  echo "user" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "pass" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"
  echo "invalid" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_TLS"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid SMTP_TLS value"
}

@test "smtp provider_validate_config passes with valid config" {
  echo "smtp" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "smtp.example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_HOST"
  echo "587" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PORT"
  echo "user" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "pass" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}

@test "smtp provider_validate_config accepts all TLS modes" {
  echo "smtp" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "smtp.example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_HOST"
  echo "587" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PORT"
  echo "user" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_USERNAME"
  echo "pass" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_PASSWORD"

  for tls_mode in starttls STARTTLS ssl SSL smtps SMTPS none NONE off OFF; do
    echo "$tls_mode" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SMTP_TLS"
    run provider_validate_config "$TEST_SERVICE"
    assert_success
  done
}

# =============================================================================
# SendGrid Provider Validation
# =============================================================================

@test "sendgrid provider_validate_config fails with missing API key" {
  echo "sendgrid" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "sendgrid provider_validate_config fails with invalid API key format" {
  echo "sendgrid" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "invalid-key" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid API key format"
}

@test "sendgrid provider_validate_config passes with valid API key" {
  echo "sendgrid" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "SG.xxxxxxxxxxxxxxxxxxxx" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}

# =============================================================================
# Mailgun Provider Validation
# =============================================================================

@test "mailgun provider_validate_config fails with missing config" {
  echo "mailgun" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "mailgun provider_validate_config fails with invalid region" {
  echo "mailgun" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "key-xxxxx" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"
  echo "example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/DOMAIN"
  echo "invalid" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/REGION"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid REGION value"
}

@test "mailgun provider_validate_config passes with valid config" {
  echo "mailgun" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "key-xxxxx" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"
  echo "example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/DOMAIN"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}

@test "mailgun provider_validate_config accepts both regions" {
  echo "mailgun" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "key-xxxxx" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"
  echo "example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/DOMAIN"

  for region in us US eu EU europe EUROPE; do
    echo "$region" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/REGION"
    run provider_validate_config "$TEST_SERVICE"
    assert_success
  done
}

# =============================================================================
# Resend Provider Validation
# =============================================================================

@test "resend provider_validate_config fails with missing API key" {
  echo "resend" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "resend provider_validate_config fails with invalid API key format" {
  echo "resend" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "invalid-key" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"
  echo "example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SENDER_DOMAIN"

  run provider_validate_config "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid API key format"
}

@test "resend provider_validate_config passes with valid API key" {
  echo "resend" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  echo "re_xxxxxxxxxxxxxxxxxxxx" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/API_KEY"
  echo "example.com" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SENDER_DOMAIN"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}

# =============================================================================
# Mock Provider Validation
# =============================================================================

@test "mock provider_validate_config always passes" {
  echo "mock" > "$PLUGIN_DATA_ROOT/$TEST_SERVICE/PROVIDER"
  source "$PLUGIN_BASE_PATH/providers/loader.sh"
  load_provider "$TEST_SERVICE"

  run provider_validate_config "$TEST_SERVICE"
  assert_success
}
