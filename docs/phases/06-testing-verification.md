# Phase 6: Testing & Verification

**Estimated tokens:** 2,500

## Overview

Implement the `mail:test` command and end-to-end verification to ensure mail delivery works correctly.

## User Stories

### Story 6.1: Send Test Email
**As a** dokku administrator
**I want to** send a test email through the relay
**So that** I can verify the entire mail pipeline works

**Acceptance Criteria:**
- [ ] `dokku mail:test mymail recipient@example.com` sends test email
- [ ] Test email sent through relay → upstream provider
- [ ] Shows success/failure status
- [ ] Includes timestamp and service name in test email
- [ ] Option to specify custom subject: `--subject "Test"`

**Tests:**
```bash
@test "mail:test sends email successfully" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws
  # ... configure provider ...

  run dokku mail:test testmail $TEST_EMAIL_RECIPIENT
  assert_success
  assert_output_contains "Test email sent"
}

@test "mail:test fails without provider configured" {
  dokku mail:create testmail
  run dokku mail:test testmail recipient@example.com
  assert_failure
  assert_output_contains "provider not configured"
}
```

### Story 6.2: Test Linked App Configuration
**As a** dokku administrator
**I want to** verify an app's mail configuration works
**So that** I know the app can send emails before deploying

**Acceptance Criteria:**
- [ ] `dokku mail:test-app myapp recipient@example.com` tests app's mail setup
- [ ] Finds which service the app is linked to
- [ ] Sends test email through that service
- [ ] Fails with helpful message if app not linked

**Tests:**
```bash
@test "mail:test-app sends through linked service" {
  dokku apps:create myapp
  dokku mail:create testmail
  # ... configure provider ...
  dokku mail:link testmail myapp

  run dokku mail:test-app myapp $TEST_EMAIL_RECIPIENT
  assert_success
}

@test "mail:test-app fails if not linked" {
  dokku apps:create myapp
  run dokku mail:test-app myapp recipient@example.com
  assert_failure
  assert_output_contains "not linked"
}
```

### Story 6.3: Delivery Status Report
**As a** dokku administrator
**I want to** see mail delivery statistics
**So that** I can monitor the health of mail delivery

**Acceptance Criteria:**
- [ ] `dokku mail:report mymail` shows delivery stats
- [ ] Includes: emails sent (if trackable), queue size, last activity
- [ ] Shows upstream provider status
- [ ] Shows any recent errors

**Tests:**
```bash
@test "mail:report shows service status" {
  dokku mail:create testmail
  dokku mail:provider:set testmail aws

  run dokku mail:report testmail
  assert_success
  assert_output_contains "Provider:"
  assert_output_contains "Status:"
}
```

### Story 6.4: Queue Inspection
**As a** dokku administrator
**I want to** view the mail queue
**So that** I can see if emails are stuck

**Acceptance Criteria:**
- [ ] `dokku mail:queue mymail` shows queued messages
- [ ] Shows recipient, subject, queue time for each
- [ ] `dokku mail:queue:flush mymail` forces retry of queued messages
- [ ] `dokku mail:queue:clear mymail` removes all queued messages (with confirmation)

**Tests:**
```bash
@test "mail:queue shows empty queue" {
  dokku mail:create testmail
  run dokku mail:queue testmail
  assert_success
  assert_output_contains "Queue is empty"
}
```

## Deliverables

### Files to Create

```
mail/
├── subcommands/
│   ├── test             # Send test email
│   ├── test-app         # Test linked app
│   ├── report           # Delivery report
│   ├── queue            # View queue
│   ├── queue:flush      # Retry queued
│   └── queue:clear      # Clear queue
└── tests/
    └── 06_testing.bats
```

### Test Email Template

```
Subject: [dokku-mail] Test email from {service}

This is a test email sent from dokku mail service "{service}".

Timestamp: {timestamp}
Server: {hostname}
Provider: {provider}

If you received this email, mail delivery is working correctly.

--
Sent by dokku-mail plugin
```

### Queue Commands (Postfix)

```bash
# View queue
mailq

# Flush queue (retry all)
postqueue -f

# Clear queue
postsuper -d ALL
```

## Dependencies

- Phase 1-4 complete (can test with mock provider)
- Phase 5 optional (for production provider testing)

## Exit Criteria

- [ ] Test emails can be sent successfully
- [ ] Queue can be inspected and managed
- [ ] Report shows useful status information
- [ ] `make test` passes all unit tests
