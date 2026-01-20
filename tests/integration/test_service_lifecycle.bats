#!/usr/bin/env bats
# Integration tests for mail service lifecycle

load '../test_helper/common'

setup() {
  # Generate unique service name for this test run
  export TEST_SERVICE="test-lifecycle-$$-$RANDOM"
}

teardown() {
  # Clean up test service
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "mail:create creates a new service" {
  run dokku mail:create "$TEST_SERVICE"
  assert_success
  assert_output --partial "Creating mail service"
  assert_service_exists "$TEST_SERVICE"
}

@test "mail:create with existing service shows message" {
  dokku mail:create "$TEST_SERVICE"

  run dokku mail:create "$TEST_SERVICE"
  assert_failure
  assert_output --partial "already exists"
}

@test "mail:create sets default provider to mock" {
  dokku mail:create "$TEST_SERVICE"
  assert_provider_is "$TEST_SERVICE" "mock"
}

@test "mail:list shows created services" {
  dokku mail:create "$TEST_SERVICE"

  run dokku mail:list
  assert_success
  assert_output --partial "$TEST_SERVICE"
}

@test "mail:info shows service details" {
  dokku mail:create "$TEST_SERVICE"

  run dokku mail:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "mail service information"
  assert_output --partial "$TEST_SERVICE"
  assert_output --partial "Status:"
}

@test "mail:destroy removes service" {
  dokku mail:create "$TEST_SERVICE"
  assert_service_exists "$TEST_SERVICE"

  run dokku mail:destroy "$TEST_SERVICE" --force
  assert_success
  refute_service_exists "$TEST_SERVICE"
}

@test "mail:destroy without force prompts for confirmation" {
  dokku mail:create "$TEST_SERVICE"

  # Pipe "n" to reject confirmation
  run bash -c "echo n | dokku mail:destroy $TEST_SERVICE"
  assert_service_exists "$TEST_SERVICE"
}

@test "mail:destroy fails for non-existent service" {
  run dokku mail:destroy "nonexistent-service-$$" --force
  assert_failure
  assert_output --partial "does not exist"
}

@test "mail:destroy fails if apps are linked" {
  skip "Requires test app setup"
  dokku mail:create "$TEST_SERVICE"
  # dokku mail:link "$TEST_SERVICE" "some-app"

  run dokku mail:destroy "$TEST_SERVICE"
  assert_failure
  assert_output --partial "linked"
}
