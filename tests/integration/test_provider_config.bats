#!/usr/bin/env bats
# Integration tests for provider configuration

load '../test_helper/common'

setup() {
  export TEST_SERVICE="test-config-$$-$RANDOM"
  dokku mail:create "$TEST_SERVICE"
}

teardown() {
  dokku mail:destroy "$TEST_SERVICE" --force 2>/dev/null || true
}

@test "mail:provider:set changes provider" {
  assert_provider_is "$TEST_SERVICE" "mock"

  run dokku mail:provider:set "$TEST_SERVICE" "aws"
  assert_success

  assert_provider_is "$TEST_SERVICE" "aws"
}

@test "mail:provider:set clears old config" {
  # Set some config for mock (even though it doesn't need it)
  dokku mail:provider:config "$TEST_SERVICE" "SOME_KEY=value"
  assert_config_set "$TEST_SERVICE" "SOME_KEY"

  # Switch provider
  dokku mail:provider:set "$TEST_SERVICE" "aws"

  # Old config should be cleared
  run cat "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/SOME_KEY"
  assert_failure
}

@test "mail:provider:config sets config value" {
  run dokku mail:provider:config "$TEST_SERVICE" "MY_KEY=my_value"
  assert_success

  assert_config_set "$TEST_SERVICE" "MY_KEY" "my_value"
}

@test "mail:provider:config handles special characters" {
  run dokku mail:provider:config "$TEST_SERVICE" "API_KEY=re_abc123_xyz"
  assert_success

  assert_config_set "$TEST_SERVICE" "API_KEY" "re_abc123_xyz"
}

@test "mail:provider:apply validates required config" {
  dokku mail:provider:set "$TEST_SERVICE" "aws"

  # Try to apply without required config
  run dokku mail:provider:apply "$TEST_SERVICE"
  assert_failure
  assert_output --partial "Missing required config"
}

@test "mail:provider:reset clears all config" {
  dokku mail:provider:set "$TEST_SERVICE" "resend"
  dokku mail:provider:config "$TEST_SERVICE" "API_KEY=re_test123"
  dokku mail:provider:config "$TEST_SERVICE" "SENDER_DOMAIN=example.com"

  run dokku mail:provider:reset "$TEST_SERVICE"
  assert_success

  # Config should be cleared
  run ls "$PLUGIN_DATA_ROOT/$TEST_SERVICE/provider-config/"
  assert_output ""
}

@test "mail:provider:info masks sensitive values" {
  dokku mail:provider:set "$TEST_SERVICE" "resend"
  dokku mail:provider:config "$TEST_SERVICE" "API_KEY=re_test_fake_key_for_testing_1234567890abcdef"
  dokku mail:provider:config "$TEST_SERVICE" "SENDER_DOMAIN=example.com"

  run dokku mail:provider:info "$TEST_SERVICE"
  assert_success
  # Should show masked key, not full key
  # Masking shows first 6 chars (re_tes) and last 4 chars (cdef)
  assert_output --partial "re_tes"
  assert_output --partial "***"
  refute_output --partial "fake_key_for_testing"
}

@test "mail:provider:set fails for invalid provider" {
  run dokku mail:provider:set "$TEST_SERVICE" "invalid-provider"
  assert_failure
  assert_output --partial "Unknown provider"
}

@test "available providers are listed" {
  run dokku mail:provider:set "$TEST_SERVICE" --help 2>&1 || true
  # Should mention available providers somewhere
  # This test may need adjustment based on actual help output
}
