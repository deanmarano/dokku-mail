#!/usr/bin/env bats
# Integration tests for mail:doctor command

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-doctor-$$-$RANDOM"
  dokku mail:create "$TEST_SERVICE"
}

teardown() {
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "doctor passes for healthy service" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:doctor "$TEST_SERVICE"
  assert_success
  assert_output --partial "All checks passed"
}

@test "doctor checks service exists" {
  run dokku mail:doctor "nonexistent-service-xyz"
  assert_failure
  assert_output --partial "Service directory not found"
}

@test "doctor checks container is running" {
  skip "Requires docker permissions to stop containers"
}

@test "doctor checks provider is configured" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:doctor "$TEST_SERVICE"
  assert_success
  assert_output --partial "Provider: mock"
}

@test "doctor shows container IP" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:doctor "$TEST_SERVICE"
  assert_success
  assert_output --partial "Container IP:"
}

@test "doctor verbose mode shows extra details" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:doctor "$TEST_SERVICE" --verbose
  assert_success
  assert_output --partial "[verbose]"
  assert_output --partial "Image:"
}

@test "doctor detects linked app config drift" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  # Create and link a test app
  local test_app="test-app-doctor-$$-$RANDOM"
  dokku apps:create "$test_app" 2>/dev/null || true
  dokku mail:link "$TEST_SERVICE" "$test_app"

  # Manually corrupt the SMTP_HOST to simulate drift
  dokku config:set --no-restart "$test_app" SMTP_HOST=wrong-ip

  run dokku mail:doctor "$TEST_SERVICE"
  assert_output --partial "config drift detected"

  # Cleanup
  dokku apps:destroy "$test_app" --force 2>/dev/null || true
}

@test "doctor calls provider_doctor when available" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:doctor "$TEST_SERVICE"
  assert_success
  # Mock provider doctor should run - check for provider-specific output
  assert_output --partial "Checking mock provider"
}

@test "doctor returns exit code 1 on errors" {
  skip "Requires docker permissions to stop containers"
}
