#!/usr/bin/env bats
# Integration tests for mock provider (MailHog)

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-mock-$$-$RANDOM"
  dokku mail:create "$TEST_SERVICE"
}

teardown() {
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "mock provider is set by default" {
  assert_provider_is "$TEST_SERVICE" "mock"
}

@test "mail:provider:apply starts mock container" {
  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_success
  assert_output --partial "Starting container"

  # Wait for container
  wait_for_container "dokku.mail.$TEST_SERVICE" 10
  assert container_is_running "dokku.mail.$TEST_SERVICE"
}

@test "mock provider exposes SMTP on port 1025" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  local container_ip
  container_ip=$(get_container_ip "dokku.mail.$TEST_SERVICE")

  # Check SMTP port is open
  run smtp_port_open "$container_ip" 1025
  assert_success
}

@test "mail:provider:verify succeeds for mock" {
  dokku mail:provider:apply "$TEST_SERVICE"

  run dokku mail:provider:verify "$TEST_SERVICE"
  assert_success
  assert_output --partial "Mock provider is always ready"
}

@test "mail:provider:info shows mock configuration" {
  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "Mock (MailHog)"
  assert_output --partial "1025"
}

@test "mock provider validates config (no-op)" {
  # Mock has no required config, so validation should always pass
  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_success
  refute_output --partial "Missing required config"
}

@test "mock container accepts email" {
  skip "Requires email sending setup"
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  local container_ip
  container_ip=$(get_container_ip "dokku.mail.$TEST_SERVICE")

  run send_test_email "$container_ip" 1025 "test@example.com" "recipient@example.com"
  assert_success
}
