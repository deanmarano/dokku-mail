#!/usr/bin/env bats
# Integration tests for mail:status command

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-status-$$-$RANDOM"
  dokku mail:create "$TEST_SERVICE"
}

teardown() {
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "status reports 'down' for nonexistent service" {
  run dokku mail:status "nonexistent-service-xyz"
  assert_failure
  assert_equal "$status" 2  # EXIT_DOWN
  assert_output --partial "down"
}

@test "status reports 'down' when container not running" {
  skip "Requires docker permissions to stop containers"
}

@test "status reports 'healthy' for running container" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:status "$TEST_SERVICE"
  assert_success
  assert_equal "$status" 0  # EXIT_HEALTHY
  assert_output --partial "healthy"
}

@test "status shows service name and provider" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:status "$TEST_SERVICE"
  assert_success
  assert_output --partial "service=$TEST_SERVICE"
  assert_output --partial "provider=mock"
}

@test "status shows container details when running" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:status "$TEST_SERVICE"
  assert_success
  assert_output --partial "container_ip="
  assert_output --partial "smtp_port=25"
  assert_output --partial "linked_apps="
}

@test "status quiet mode only outputs status word" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  run dokku mail:status "$TEST_SERVICE" --quiet
  assert_success
  assert_output "healthy"
}

@test "status quiet mode works for down services" {
  skip "Requires docker permissions to stop containers"
}

@test "status counts linked apps" {
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  # Create and link test apps
  local app1="test-app-status-1-$$-$RANDOM"
  local app2="test-app-status-2-$$-$RANDOM"

  dokku apps:create "$app1" 2>/dev/null || true
  dokku apps:create "$app2" 2>/dev/null || true
  dokku mail:link "$TEST_SERVICE" "$app1"
  dokku mail:link "$TEST_SERVICE" "$app2"

  run dokku mail:status "$TEST_SERVICE"
  assert_success
  assert_output --partial "linked_apps=2"

  # Cleanup
  dokku apps:destroy "$app1" --force 2>/dev/null || true
  dokku apps:destroy "$app2" --force 2>/dev/null || true
}

@test "status exit codes can be used in scripts" {
  # Test exit code 0 (healthy)
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  if dokku mail:status "$TEST_SERVICE" --quiet >/dev/null; then
    healthy=true
  else
    healthy=false
  fi
  assert_equal "$healthy" "true"

  # Test exit code 2 (down) - destroy and check
  dokku mail:destroy "$TEST_SERVICE" --force

  if dokku mail:status "$TEST_SERVICE" --quiet >/dev/null 2>&1; then
    down=false
  else
    down=true
  fi
  assert_equal "$down" "true"

  # Recreate for teardown
  dokku mail:create "$TEST_SERVICE"
}
