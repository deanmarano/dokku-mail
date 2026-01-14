# Phase 3: App Linking

**Estimated tokens:** 3,000

## Overview

Implement app linking functionality so dokku apps can use the mail relay service. Linking injects SMTP environment variables into the app.

## User Stories

### Story 3.1: Link App to Mail Service
**As a** dokku administrator
**I want to** link an app to a mail service
**So that** the app can send emails through the relay

**Acceptance Criteria:**
- [ ] `dokku mail:link mymail myapp` links the app
- [ ] App receives SMTP environment variables on next deploy
- [ ] Environment variables injected:
  - `SMTP_HOST` - relay hostname (e.g., `dokku.mail.mymail`)
  - `SMTP_PORT` - relay port (25)
  - `MAIL_URL` - combined URL (`smtp://dokku.mail.mymail:25`)
- [ ] Link recorded in service's LINKS file
- [ ] Fails if app doesn't exist
- [ ] Fails if service doesn't exist
- [ ] Fails if already linked (unless `--force`)

**Tests:**
```bash
@test "mail:link links app to service" {
  dokku apps:create myapp
  dokku mail:create testmail
  run dokku mail:link testmail myapp
  assert_success

  # Verify env vars set
  run dokku config:get myapp SMTP_HOST
  assert_output "dokku.mail.testmail"
}

@test "mail:link fails for non-existent app" {
  dokku mail:create testmail
  run dokku mail:link testmail nonexistent
  assert_failure
}

@test "mail:link fails if already linked" {
  dokku apps:create myapp
  dokku mail:create testmail
  dokku mail:link testmail myapp
  run dokku mail:link testmail myapp
  assert_failure
  assert_output_contains "already linked"
}
```

### Story 3.2: Unlink App from Mail Service
**As a** dokku administrator
**I want to** unlink an app from a mail service
**So that** the app no longer uses the relay

**Acceptance Criteria:**
- [ ] `dokku mail:unlink mymail myapp` unlinks the app
- [ ] SMTP environment variables removed from app
- [ ] Link removed from service's LINKS file
- [ ] Fails if not currently linked

**Tests:**
```bash
@test "mail:unlink removes link" {
  dokku apps:create myapp
  dokku mail:create testmail
  dokku mail:link testmail myapp

  run dokku mail:unlink testmail myapp
  assert_success

  # Verify env vars removed
  run dokku config:get myapp SMTP_HOST
  assert_output ""
}

@test "mail:unlink fails if not linked" {
  dokku apps:create myapp
  dokku mail:create testmail
  run dokku mail:unlink testmail myapp
  assert_failure
}
```

### Story 3.3: View Linked Apps
**As a** dokku administrator
**I want to** see which apps are linked to a mail service
**So that** I know what depends on the service

**Acceptance Criteria:**
- [ ] `dokku mail:links mymail` shows linked apps
- [ ] `dokku mail:info mymail` includes linked apps section
- [ ] Empty output if no apps linked

**Tests:**
```bash
@test "mail:links shows linked apps" {
  dokku apps:create app1
  dokku apps:create app2
  dokku mail:create testmail
  dokku mail:link testmail app1
  dokku mail:link testmail app2

  run dokku mail:links testmail
  assert_success
  assert_output_contains "app1"
  assert_output_contains "app2"
}
```

### Story 3.4: Custom Environment Variable Alias
**As a** dokku administrator
**I want to** specify a custom env var prefix when linking
**So that** I can match what my app expects (e.g., `MAILER_HOST` instead of `SMTP_HOST`)

**Acceptance Criteria:**
- [ ] `dokku mail:link mymail myapp --alias MAILER` uses custom prefix
- [ ] Sets `MAILER_HOST`, `MAILER_PORT`, `MAILER_URL` instead
- [ ] Default alias is `SMTP` if not specified

**Tests:**
```bash
@test "mail:link with custom alias" {
  dokku apps:create myapp
  dokku mail:create testmail
  run dokku mail:link testmail myapp --alias MAILER
  assert_success

  run dokku config:get myapp MAILER_HOST
  assert_output "dokku.mail.testmail"

  # Default should not be set
  run dokku config:get myapp SMTP_HOST
  assert_output ""
}
```

## Deliverables

### Files to Create

```
mail/
├── subcommands/
│   ├── link             # Link app to service
│   ├── unlink           # Unlink app from service
│   └── links            # List linked apps
└── tests/
    └── 03_linking.bats
```

### Functions to Add (functions file)

```bash
service_link() {
  # Add app to LINKS file
  # Set config vars on app
}

service_unlink() {
  # Remove app from LINKS file
  # Unset config vars on app
}

is_app_linked() {
  # Check if app is in LINKS file
}

get_linked_apps() {
  # Read LINKS file
}
```

### Environment Variables Injected

| Variable | Example Value | Description |
|----------|---------------|-------------|
| `SMTP_HOST` | `dokku.mail.mymail` | Relay hostname |
| `SMTP_PORT` | `25` | Relay port |
| `MAIL_URL` | `smtp://dokku.mail.mymail:25` | Combined URL |

## Dependencies

- Phase 1 complete (plugin structure)
- Phase 2 complete (service exists to link to)

## Exit Criteria

- [ ] Apps can be linked/unlinked from services
- [ ] Environment variables correctly injected
- [ ] Link state persisted across restarts
- [ ] `make test` passes all unit tests
