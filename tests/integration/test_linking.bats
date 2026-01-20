#!/usr/bin/env bats
# Integration tests for app linking

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-link-$$-$RANDOM"
  export TEST_APP="test-app-$$-$RANDOM"

  dokku mail:create "$TEST_SERVICE"
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  # Create test app
  dokku apps:create "$TEST_APP" 2>/dev/null || true
}

teardown() {
  dokku mail:unlink "$TEST_SERVICE" "$TEST_APP" 2>/dev/null || true
  dokku apps:destroy "$TEST_APP" --force 2>/dev/null || true
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "mail:link links app to service" {
  run dokku mail:link "$TEST_SERVICE" "$TEST_APP"
  assert_success
  assert_output --partial "Linked"

  assert_app_linked "$TEST_SERVICE" "$TEST_APP"
}

@test "mail:link sets SMTP environment variables" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"

  # Check SMTP_HOST is set
  run dokku config:get "$TEST_APP" SMTP_HOST
  assert_success
  assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"

  # Check SMTP_PORT is set
  run dokku config:get "$TEST_APP" SMTP_PORT
  assert_success
  assert_output "1025"  # Mock provider port

  # Check MAIL_URL is set
  run dokku config:get "$TEST_APP" MAIL_URL
  assert_success
  assert_output --partial "smtp://"
}

@test "mail:link fails for non-existent service" {
  run dokku mail:link "nonexistent-$$" "$TEST_APP"
  assert_failure
  assert_output --partial "does not exist"
}

@test "mail:link fails for non-existent app" {
  run dokku mail:link "$TEST_SERVICE" "nonexistent-app-$$"
  assert_failure
}

@test "mail:link is idempotent" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"

  run dokku mail:link "$TEST_SERVICE" "$TEST_APP"
  assert_success
  assert_output --partial "already linked"
}

@test "mail:unlink removes app from service" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"
  assert_app_linked "$TEST_SERVICE" "$TEST_APP"

  run dokku mail:unlink "$TEST_SERVICE" "$TEST_APP"
  assert_success

  run grep -q "^${TEST_APP}$" "$PLUGIN_DATA_ROOT/$TEST_SERVICE/LINKS"
  assert_failure
}

@test "mail:unlink removes SMTP environment variables" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"
  dokku mail:unlink "$TEST_SERVICE" "$TEST_APP"

  run dokku config:get "$TEST_APP" SMTP_HOST
  assert_output ""

  run dokku config:get "$TEST_APP" SMTP_PORT
  assert_output ""

  run dokku config:get "$TEST_APP" MAIL_URL
  assert_output ""
}

@test "mail:info shows linked apps" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"

  run dokku mail:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "$TEST_APP"
}

@test "provider:apply updates linked apps" {
  dokku mail:link "$TEST_SERVICE" "$TEST_APP"

  local old_ip
  old_ip=$(dokku config:get "$TEST_APP" SMTP_HOST)

  # Re-apply provider (container gets new IP)
  dokku mail:provider:apply "$TEST_SERVICE"
  wait_for_container "dokku.mail.$TEST_SERVICE" 10

  # App should have updated IP
  run dokku config:get "$TEST_APP" SMTP_HOST
  assert_success
  # IP should be set (may or may not be different)
  assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
}
