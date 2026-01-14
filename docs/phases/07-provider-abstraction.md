# Phase 7: Provider Abstraction

**Estimated tokens:** 3,000

## Overview

Extend the provider system to support multiple upstream mail providers, adding generic SMTP and a template for future providers (SendGrid, Mailgun, etc.).

## User Stories

### Story 7.1: List Available Providers
**As a** dokku administrator
**I want to** see which mail providers are supported
**So that** I can choose the right one for my needs

**Acceptance Criteria:**
- [ ] `dokku mail:providers` lists all available providers
- [ ] Shows provider name and brief description
- [ ] Indicates which providers have dependencies installed

**Tests:**
```bash
@test "mail:providers lists available providers" {
  run dokku mail:providers
  assert_success
  assert_output_contains "aws"
  assert_output_contains "Amazon SES"
}
```

### Story 7.2: Provider Auto-Discovery
**As a** plugin developer
**I want** new providers to be discovered automatically
**So that** adding a provider doesn't require modifying core code

**Acceptance Criteria:**
- [ ] Providers are directories under `providers/`
- [ ] Each provider has `config.sh` and `provider.sh`
- [ ] Plugin scans `providers/` directory at runtime
- [ ] Invalid providers are skipped with warning

**Tests:**
```bash
@test "discovers new provider automatically" {
  # Create mock provider
  mkdir -p "$PLUGIN_PATH/providers/mockprovider"
  echo 'PROVIDER_NAME="mockprovider"' > "$PLUGIN_PATH/providers/mockprovider/config.sh"
  echo 'provider_validate_credentials() { return 0; }' > "$PLUGIN_PATH/providers/mockprovider/provider.sh"

  run dokku mail:providers
  assert_success
  assert_output_contains "mockprovider"
}
```

### Story 7.3: Generic SMTP Provider
**As a** dokku administrator
**I want to** configure a generic SMTP upstream
**So that** I can use any SMTP server, not just AWS SES

**Acceptance Criteria:**
- [ ] `dokku mail:provider:set mymail smtp` configures generic SMTP
- [ ] Configurable: host, port, username, password, TLS mode
- [ ] Works with any standard SMTP server

**Tests:**
```bash
@test "generic smtp provider works" {
  dokku mail:create testmail
  dokku mail:provider:set testmail smtp
  dokku mail:provider:config testmail SMTP_HOST=smtp.example.com
  dokku mail:provider:config testmail SMTP_PORT=587
  dokku mail:provider:config testmail SMTP_USERNAME=user
  dokku mail:provider:config testmail SMTP_PASSWORD=pass

  run dokku mail:provider:info testmail
  assert_success
  assert_output_contains "smtp.example.com"
}
```

### Story 7.4: Provider Template
**As a** plugin developer
**I want** a template for creating new providers
**So that** I can easily add support for new mail services

**Acceptance Criteria:**
- [ ] `providers/template/` contains documented example
- [ ] Template includes all required functions
- [ ] Comments explain each function's purpose
- [ ] README explains how to create new provider

**Tests:**
```bash
@test "template provider has required functions" {
  source "$PLUGIN_PATH/providers/template/provider.sh"

  # All required functions exist
  declare -f provider_name > /dev/null
  declare -f provider_validate_credentials > /dev/null
  declare -f provider_get_smtp_config > /dev/null
  declare -f provider_configure_relay > /dev/null
}
```

### Story 7.5: Provider Migration
**As a** dokku administrator
**I want to** switch a service from one provider to another
**So that** I can change mail providers without recreating services

**Acceptance Criteria:**
- [ ] `dokku mail:provider:set mymail newprovider` switches providers
- [ ] Warns about existing configuration being replaced
- [ ] Old provider config removed after switch
- [ ] Service restarts with new provider

**Tests:**
```bash
@test "can switch providers" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  dokku mail:provider:config testmail AWS_REGION=us-east-1

  run dokku mail:provider:set testmail smtp
  assert_success

  # Old config should be gone
  [[ ! -f "$PLUGIN_DATA_ROOT/testmail/provider-config/AWS_REGION" ]]
}
```

## Deliverables

### Files to Create/Modify

```
mail/
├── providers/
│   ├── loader.sh            # Provider discovery & loading (enhance from Phase 4)
│   ├── INTERFACE.md         # Provider interface spec (enhance from Phase 4)
│   ├── smtp/                 # Generic SMTP provider
│   │   ├── config.sh
│   │   ├── provider.sh
│   │   └── README.md
│   └── template/             # Template for new providers
│       ├── config.sh
│       ├── provider.sh
│       └── README.md
├── subcommands/
│   └── providers            # List providers
└── tests/
    └── 07_providers.bats
```

### Provider Interface Specification

```bash
# providers/INTERFACE.md

## Required Functions

### provider_name()
Returns the provider identifier string.
Example: echo "aws"

### provider_display_name()
Returns human-readable name.
Example: echo "Amazon SES"

### provider_required_config()
Returns space-separated list of required config keys.
Example: echo "AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION"

### provider_validate_credentials()
Validates stored credentials with upstream service.
Returns: 0 = valid, 1 = invalid
Output: Human-readable status message

### provider_get_smtp_config()
Returns JSON with SMTP relay configuration.
Output: {"host": "...", "port": 587, "username": "...", "password": "...", "tls": true}

### provider_configure_relay(container_name)
Configures the relay container to use this provider as upstream.
Called after credentials are set.
Returns: 0 = success, 1 = failure

## Optional Functions

### provider_setup()
One-time setup when provider is selected.
Example: Generate derived credentials.

### provider_cleanup()
Called when switching away from this provider.
Example: Revoke generated credentials.
```

### Generic SMTP Provider

```bash
# providers/smtp/config.sh
PROVIDER_NAME="smtp"
PROVIDER_DISPLAY_NAME="Generic SMTP"
PROVIDER_REQUIRED_CONFIG="SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD"

# providers/smtp/provider.sh
provider_validate_credentials() {
  # Try to connect to SMTP server
  local host=$(cat "$CONFIG_DIR/SMTP_HOST")
  local port=$(cat "$CONFIG_DIR/SMTP_PORT")

  nc -z -w5 "$host" "$port" && echo "Connection successful" && return 0
  echo "Cannot connect to $host:$port" && return 1
}

provider_get_smtp_config() {
  jq -n \
    --arg host "$(cat "$CONFIG_DIR/SMTP_HOST")" \
    --arg port "$(cat "$CONFIG_DIR/SMTP_PORT")" \
    --arg user "$(cat "$CONFIG_DIR/SMTP_USERNAME")" \
    --arg pass "$(cat "$CONFIG_DIR/SMTP_PASSWORD")" \
    '{host: $host, port: ($port|tonumber), username: $user, password: $pass, tls: true}'
}
```

## Dependencies

- Phase 1-4 complete (provider interface exists)
- Phase 5-6 optional
- jq installed (for JSON handling)

## Exit Criteria

- [ ] Multiple providers can be listed
- [ ] Generic SMTP provider works
- [ ] New providers auto-discovered
- [ ] Provider template is complete and documented
- [ ] Can switch between providers
- [ ] `make test` passes all unit tests
