# Phase 5: AWS SES Provider

**Estimated tokens:** 4,500

## Overview

Implement the AWS SES provider so the mail relay can forward emails to Amazon SES. This builds on the provider interface established in Phase 4 (Mock Provider).

## User Stories

### Story 5.1: Configure AWS SES Provider
**As a** dokku administrator
**I want to** configure a mail service to use AWS SES
**So that** emails are delivered through my AWS account

**Acceptance Criteria:**
- [ ] `dokku mail:provider:set mymail aws` sets the provider
- [ ] `dokku mail:provider:config mymail AWS_ACCESS_KEY_ID=xxx` sets credentials
- [ ] `dokku mail:provider:config mymail AWS_SECRET_ACCESS_KEY=xxx` sets secret
- [ ] `dokku mail:provider:config mymail AWS_REGION=us-east-1` sets region
- [ ] Credentials stored securely in service directory
- [ ] Relay container reconfigured to use SES as upstream

**Tests:**
```bash
@test "mail:provider:set configures aws provider" {
  dokku mail:create testmail
  run dokku mail:provider:set testmail aws
  assert_success

  [[ "$(cat $PLUGIN_DATA_ROOT/testmail/PROVIDER)" == "aws" ]]
}

@test "mail:provider:config stores credentials" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  run dokku mail:provider:config testmail AWS_ACCESS_KEY_ID=AKIATEST
  assert_success

  [[ -f "$PLUGIN_DATA_ROOT/testmail/provider-config/AWS_ACCESS_KEY_ID" ]]
}
```

### Story 5.2: Verify AWS Credentials
**As a** dokku administrator
**I want to** verify my AWS SES credentials work
**So that** I know mail delivery will succeed before linking apps

**Acceptance Criteria:**
- [ ] `dokku mail:provider:verify mymail` tests credentials
- [ ] Calls SES GetSendQuota API to verify access
- [ ] Shows success message with quota info
- [ ] Shows clear error if credentials invalid
- [ ] Shows warning if SES is in sandbox mode

**Tests:**
```bash
@test "mail:provider:verify succeeds with valid credentials" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  dokku mail:provider:config testmail AWS_ACCESS_KEY_ID=$TEST_AWS_KEY
  dokku mail:provider:config testmail AWS_SECRET_ACCESS_KEY=$TEST_AWS_SECRET
  dokku mail:provider:config testmail AWS_REGION=us-east-1

  run dokku mail:provider:verify testmail
  assert_success
  assert_output_contains "credentials valid"
}

@test "mail:provider:verify fails with invalid credentials" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  dokku mail:provider:config testmail AWS_ACCESS_KEY_ID=invalid
  dokku mail:provider:config testmail AWS_SECRET_ACCESS_KEY=invalid
  dokku mail:provider:config testmail AWS_REGION=us-east-1

  run dokku mail:provider:verify testmail
  assert_failure
  assert_output_contains "invalid"
}
```

### Story 5.3: View Provider Configuration
**As a** dokku administrator
**I want to** see the current provider configuration
**So that** I can verify settings are correct

**Acceptance Criteria:**
- [ ] `dokku mail:provider:info mymail` shows provider details
- [ ] Shows provider name, region, configured settings
- [ ] Masks sensitive values (shows `***` for secrets)

**Tests:**
```bash
@test "mail:provider:info shows configuration" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  dokku mail:provider:config testmail AWS_ACCESS_KEY_ID=AKIATEST
  dokku mail:provider:config testmail AWS_REGION=us-east-1

  run dokku mail:provider:info testmail
  assert_success
  assert_output_contains "Provider: aws"
  assert_output_contains "Region: us-east-1"
  assert_output_contains "Access Key: AKIA***"
}
```

### Story 5.4: SES SMTP Credential Generation
**As a** dokku administrator
**I want** the plugin to generate SES SMTP credentials from IAM credentials
**So that** I don't have to manually create SMTP credentials in AWS console

**Acceptance Criteria:**
- [ ] Plugin generates SMTP password from IAM secret key
- [ ] Uses AWS documented signing algorithm
- [ ] Generated credentials work with SES SMTP endpoint
- [ ] Credentials regenerated if IAM credentials change

**Tests:**
```bash
@test "generates valid SMTP credentials from IAM" {
  # This requires the credential generation function
  run generate_ses_smtp_password "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" "us-east-1"
  assert_success
  # Output should be base64-encoded SMTP password
  [[ ${#output} -gt 20 ]]
}
```

## Deliverables

### Files to Create

```
mail/
├── providers/
│   └── aws/
│       ├── config.sh    # AWS provider metadata
│       ├── provider.sh  # AWS SES implementation
│       └── README.md    # AWS-specific docs
└── tests/
    └── 05_aws_provider.bats
```

Note: Provider interface (`INTERFACE.md`), loader (`loader.sh`), and provider subcommands are created in Phase 4.

### Provider Interface (providers/INTERFACE.md)

```bash
# Required functions each provider must implement:

provider_name()
# Returns: provider identifier (e.g., "aws")

provider_validate_credentials()
# Returns: 0 if valid, 1 if invalid
# Output: validation message

provider_get_smtp_config()
# Returns: 0 on success
# Output: JSON with host, port, username, password

provider_configure_relay(container_name)
# Configures the relay container with upstream settings
# Returns: 0 on success
```

### AWS SES SMTP Password Generation

AWS SES requires SMTP credentials derived from IAM credentials using a specific algorithm:

```bash
generate_ses_smtp_password() {
  local secret_key="$1"
  local region="$2"

  # AWS documented algorithm:
  # 1. Create signature with HMAC-SHA256
  # 2. Prepend version byte (0x04)
  # 3. Base64 encode

  local date="11111111"
  local service="ses"
  local terminal="aws4_request"
  local message="SendRawEmail"
  local version=$'\x04'

  # HMAC chain
  local kDate=$(echo -n "$date" | openssl dgst -sha256 -hmac "AWS4${secret_key}" -binary)
  local kRegion=$(echo -n "$region" | openssl dgst -sha256 -hmac "$kDate" -binary)
  local kService=$(echo -n "$service" | openssl dgst -sha256 -hmac "$kRegion" -binary)
  local kTerminal=$(echo -n "$terminal" | openssl dgst -sha256 -hmac "$kService" -binary)
  local kMessage=$(echo -n "$message" | openssl dgst -sha256 -hmac "$kTerminal" -binary)

  echo -n "${version}${kMessage}" | base64
}
```

### Relay Configuration

The relay container needs these environment variables for SES:
```bash
RELAYHOST=email-smtp.${AWS_REGION}.amazonaws.com:587
RELAYHOST_USERNAME=${AWS_ACCESS_KEY_ID}
RELAYHOST_PASSWORD=${SMTP_PASSWORD}  # Generated from secret key
```

## Dependencies

- Phase 1-4 complete (provider interface from Phase 4)
- AWS CLI available (for verification)
- Valid AWS account with SES access

## Exit Criteria

- [ ] AWS SES provider can be configured
- [ ] Credentials can be verified
- [ ] SMTP credentials correctly generated from IAM
- [ ] Relay container forwards mail to SES
- [ ] `make test` passes all unit tests
