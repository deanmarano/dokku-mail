# Phase 4: Mock Provider

**Estimated tokens:** 2,500

## Overview

Implement a mock provider that accepts all mail and logs it locally. This enables testing the entire plugin without external services and establishes the provider interface.

## User Stories

### Story 4.1: Configure Mock Provider
**As a** dokku administrator
**I want to** configure a mail service with a mock provider
**So that** I can test the plugin without real mail delivery

**Acceptance Criteria:**
- [ ] `dokku mail:provider:set mymail mock` sets the mock provider
- [ ] No credentials required
- [ ] Relay accepts all mail and logs to container
- [ ] Emails viewable via `dokku mail:logs`

**Tests:**
```bash
@test "mail:provider:set configures mock provider" {
  dokku mail:create testmail
  run dokku mail:provider:set testmail mock
  assert_success

  [[ "$(cat $PLUGIN_DATA_ROOT/testmail/PROVIDER)" == "mock" ]]
}

@test "mock provider requires no credentials" {
  dokku mail:create testmail
  run dokku mail:provider:set testmail mock
  assert_success
  # Should be ready immediately
  run dokku mail:provider:verify testmail
  assert_success
}
```

### Story 4.2: Mock Provider Verification
**As a** dokku administrator
**I want to** verify the mock provider is working
**So that** I can confirm the relay is accepting mail

**Acceptance Criteria:**
- [ ] `dokku mail:provider:verify mymail` always succeeds for mock
- [ ] Shows message indicating mock mode
- [ ] Warns that emails won't be delivered externally

**Tests:**
```bash
@test "mail:provider:verify succeeds for mock" {
  dokku mail:create testmail
  dokku mail:provider:set testmail mock

  run dokku mail:provider:verify testmail
  assert_success
  assert_output_contains "mock"
  assert_output_contains "not delivered"
}
```

### Story 4.3: View Mock Mail Log
**As a** dokku administrator
**I want to** see emails sent through the mock provider
**So that** I can verify apps are sending mail correctly

**Acceptance Criteria:**
- [ ] `dokku mail:mock:log mymail` shows captured emails
- [ ] Shows: timestamp, from, to, subject for each
- [ ] `dokku mail:mock:log mymail --full` shows full email content
- [ ] `dokku mail:mock:clear mymail` clears the log

**Tests:**
```bash
@test "mail:mock:log shows captured emails" {
  dokku mail:create testmail
  dokku mail:provider:set testmail mock
  dokku mail:test testmail test@example.com

  run dokku mail:mock:log testmail
  assert_success
  assert_output_contains "test@example.com"
}
```

### Story 4.4: Provider Interface Definition
**As a** plugin developer
**I want** a clear provider interface
**So that** I can implement new providers consistently

**Acceptance Criteria:**
- [ ] `providers/INTERFACE.md` documents all required functions
- [ ] Mock provider implements all required functions
- [ ] Provider loader validates implementations

**Tests:**
```bash
@test "mock provider implements full interface" {
  source "$PLUGIN_PATH/providers/mock/provider.sh"

  # All required functions exist
  declare -f provider_name > /dev/null
  declare -f provider_display_name > /dev/null
  declare -f provider_validate_credentials > /dev/null
  declare -f provider_get_smtp_config > /dev/null
  declare -f provider_configure_relay > /dev/null
}
```

## Deliverables

### Files to Create

```
mail/
├── providers/
│   ├── loader.sh            # Provider discovery & loading
│   ├── INTERFACE.md         # Provider interface specification
│   └── mock/
│       ├── config.sh        # Mock provider metadata
│       ├── provider.sh      # Mock implementation
│       └── README.md        # Mock provider docs
├── subcommands/
│   ├── provider:set         # Set provider
│   ├── provider:verify      # Verify provider
│   ├── provider:info        # Show provider info
│   ├── mock:log             # View mock email log
│   └── mock:clear           # Clear mock log
└── tests/
    └── 04_mock_provider.bats
```

### Provider Interface

```bash
# providers/INTERFACE.md

## Required Functions

provider_name()           # Returns identifier (e.g., "mock")
provider_display_name()   # Returns human name (e.g., "Mock Provider")
provider_required_config() # Returns required config keys (space-separated)
provider_validate_credentials() # Returns 0 if valid
provider_get_smtp_config()      # Returns JSON with SMTP config
provider_configure_relay()      # Configures relay container
```

### Mock Provider Implementation

```bash
# providers/mock/config.sh
PROVIDER_NAME="mock"
PROVIDER_DISPLAY_NAME="Mock Provider (Testing)"
PROVIDER_REQUIRED_CONFIG=""  # No config needed

# providers/mock/provider.sh
provider_name() {
  echo "mock"
}

provider_display_name() {
  echo "Mock Provider (Testing)"
}

provider_required_config() {
  echo ""  # No credentials required
}

provider_validate_credentials() {
  echo "Mock provider is always valid"
  echo "WARNING: Emails will NOT be delivered externally"
  return 0
}

provider_get_smtp_config() {
  # Mock doesn't need upstream SMTP
  jq -n '{host: "localhost", port: 25, username: "", password: "", tls: false, mock: true}'
}

provider_configure_relay() {
  local container_name="$1"
  # Configure relay to accept all mail and log locally
  # No external relay host
  docker exec "$container_name" postconf -e "relayhost="
  docker exec "$container_name" postconf -e "default_transport=local"
}
```

### Mock Email Storage

Mock provider stores emails in container at `/var/mail/mock/`:
- One file per email with timestamp filename
- Contains full email source (headers + body)

```bash
# View captured emails
docker exec dokku.mail.${SERVICE} ls /var/mail/mock/
docker exec dokku.mail.${SERVICE} cat /var/mail/mock/${FILENAME}
```

## Dependencies

- Phase 1-3 complete

## Exit Criteria

- [ ] Mock provider can be configured
- [ ] Relay accepts mail without external service
- [ ] Captured emails can be viewed
- [ ] Provider interface documented
- [ ] `make test` passes all unit tests
- [ ] Integration tests can run without external credentials
