#!/usr/bin/env bats
# Integration tests for generic SMTP provider

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-smtp-$$-$RANDOM"
  dokku mail:create "$TEST_SERVICE"
  dokku mail:provider:set "$TEST_SERVICE" smtp
}

teardown() {
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "smtp provider is set correctly" {
  assert_provider_is "$TEST_SERVICE" "smtp"
}

@test "smtp provider requires configuration" {
  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
  assert_output --partial "SMTP_HOST"
}

@test "smtp provider validates port is numeric" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=notanumber
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=pass

  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_failure
  assert_output --partial "SMTP_PORT must be a number"
}

@test "smtp provider validates TLS mode" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=587
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=pass
  dokku mail:provider:config "$TEST_SERVICE" SMTP_TLS=invalid

  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Invalid SMTP_TLS value"
}

@test "smtp provider:info shows configuration" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=587
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=testuser
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=secretpassword123

  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "Generic SMTP"
  assert_output --partial "Host: smtp.example.com"
  assert_output --partial "Port: 587"
  assert_output --partial "Username: testuser"
  # Password should be masked
  assert_output --partial "Password: secr***d123"
}

@test "smtp provider:info masks short passwords" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=587
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=short

  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  # Short passwords should be fully masked
  assert_output --partial "Password: ***"
}

@test "smtp provider defaults TLS to starttls" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=587
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=pass

  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "TLS Mode: starttls"
}

@test "smtp provider shows configured TLS mode" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=465
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=pass
  dokku mail:provider:config "$TEST_SERVICE" SMTP_TLS=ssl

  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  assert_output --partial "TLS Mode: ssl"
}

@test "smtp provider verify checks connectivity" {
  dokku mail:provider:config "$TEST_SERVICE" SMTP_HOST=smtp.example.com
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PORT=587
  dokku mail:provider:config "$TEST_SERVICE" SMTP_USERNAME=user
  dokku mail:provider:config "$TEST_SERVICE" SMTP_PASSWORD=pass

  # This will fail since smtp.example.com doesn't exist
  run dokku mail:provider:verify "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Cannot connect to"
}

@test "switching to smtp provider clears previous config" {
  # Start with mock, add some config
  dokku mail:provider:set "$TEST_SERVICE" mock

  # Now switch to smtp
  run dokku mail:provider:set "$TEST_SERVICE" smtp
  assert_success

  # Config should be cleared
  run dokku mail:provider:info "$TEST_SERVICE"
  assert_output --partial "Host: (not set)"
}
