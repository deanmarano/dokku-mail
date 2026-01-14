# Phase 2: Service Lifecycle

**Estimated tokens:** 4,000

## Overview

Implement core service management commands to create, destroy, start, stop, and inspect SMTP relay containers.

## User Stories

### Story 2.1: Create Mail Service
**As a** dokku administrator
**I want to** create a named mail relay service
**So that** I have an SMTP relay that apps can connect to

**Acceptance Criteria:**
- [ ] `dokku mail:create mymail` creates a new mail service
- [ ] Service data directory created at `$PLUGIN_DATA_ROOT/mymail/`
- [ ] Docker container is created and started
- [ ] Container uses a lightweight SMTP relay image (e.g., Postfix)
- [ ] Service is accessible on dokku's internal network
- [ ] Error if service name already exists

**Tests:**
```bash
@test "mail:create creates service" {
  run dokku mail:create testmail
  assert_success
  assert_output_contains "Mail service testmail created"
  [[ -d "$PLUGIN_DATA_ROOT/testmail" ]]
}

@test "mail:create fails if service exists" {
  dokku mail:create testmail
  run dokku mail:create testmail
  assert_failure
  assert_output_contains "already exists"
}
```

### Story 2.2: Destroy Mail Service
**As a** dokku administrator
**I want to** destroy a mail service I no longer need
**So that** I can clean up unused resources

**Acceptance Criteria:**
- [ ] `dokku mail:destroy mymail` removes the service
- [ ] Prompts for confirmation (unless `--force` flag)
- [ ] Stops and removes Docker container
- [ ] Removes service data directory
- [ ] Fails if apps are still linked to the service

**Tests:**
```bash
@test "mail:destroy removes service" {
  dokku mail:create testmail
  run dokku mail:destroy testmail --force
  assert_success
  [[ ! -d "$PLUGIN_DATA_ROOT/testmail" ]]
}

@test "mail:destroy fails with linked apps" {
  dokku mail:create testmail
  dokku mail:link testmail myapp
  run dokku mail:destroy testmail --force
  assert_failure
  assert_output_contains "still linked"
}
```

### Story 2.3: Start/Stop Service
**As a** dokku administrator
**I want to** start and stop the mail relay
**So that** I can control when the service is running

**Acceptance Criteria:**
- [ ] `dokku mail:stop mymail` stops the container
- [ ] `dokku mail:start mymail` starts a stopped container
- [ ] `dokku mail:restart mymail` restarts the container
- [ ] Commands are idempotent (stopping stopped service is OK)

**Tests:**
```bash
@test "mail:stop stops running service" {
  dokku mail:create testmail
  run dokku mail:stop testmail
  assert_success
  run docker inspect -f '{{.State.Running}}' dokku.mail.testmail
  assert_output "false"
}

@test "mail:start starts stopped service" {
  dokku mail:create testmail
  dokku mail:stop testmail
  run dokku mail:start testmail
  assert_success
  run docker inspect -f '{{.State.Running}}' dokku.mail.testmail
  assert_output "true"
}
```

### Story 2.4: View Service Logs
**As a** dokku administrator
**I want to** view SMTP relay logs
**So that** I can troubleshoot mail delivery issues

**Acceptance Criteria:**
- [ ] `dokku mail:logs mymail` shows container logs
- [ ] `dokku mail:logs mymail --tail 100` limits output
- [ ] `dokku mail:logs mymail --follow` follows log output

**Tests:**
```bash
@test "mail:logs shows container logs" {
  dokku mail:create testmail
  run dokku mail:logs testmail
  assert_success
}
```

### Story 2.5: Service Info
**As a** dokku administrator
**I want to** see information about a mail service
**So that** I can verify its configuration and status

**Acceptance Criteria:**
- [ ] `dokku mail:info mymail` shows service details
- [ ] Output includes: status, container ID, linked apps, provider
- [ ] Output includes internal hostname/port

**Tests:**
```bash
@test "mail:info shows service details" {
  dokku mail:create testmail
  run dokku mail:info testmail
  assert_success
  assert_output_contains "Status:"
  assert_output_contains "Container:"
}
```

### Story 2.6: List Services
**As a** dokku administrator
**I want to** list all mail services
**So that** I can see what services exist

**Acceptance Criteria:**
- [ ] `dokku mail:list` shows all mail services
- [ ] Shows service name and status for each
- [ ] Empty output if no services exist

**Tests:**
```bash
@test "mail:list shows all services" {
  dokku mail:create mail1
  dokku mail:create mail2
  run dokku mail:list
  assert_success
  assert_output_contains "mail1"
  assert_output_contains "mail2"
}
```

## Deliverables

### Files to Create

```
mail/
├── subcommands/
│   ├── create           # Create service
│   ├── destroy          # Destroy service
│   ├── start            # Start service
│   ├── stop             # Stop service
│   ├── restart          # Restart service
│   ├── logs             # View logs
│   ├── info             # Service info
│   └── list             # List services
└── tests/
    └── 02_lifecycle.bats
```

### Docker Image

Need to either:
1. Use existing image (e.g., `boky/postfix` or `namshi/smtp`)
2. Build custom minimal relay image

**Recommend:** Start with `boky/postfix` - well-maintained, configurable via env vars.

### Container Configuration

```bash
docker create \
  --name "dokku.mail.${SERVICE}" \
  --network dokku \
  --restart unless-stopped \
  -e "ALLOWED_SENDER_DOMAINS=*" \
  boky/postfix
```

## Dependencies

- Phase 1 complete
- Docker available on host

## Exit Criteria

- [ ] All lifecycle commands work correctly
- [ ] Containers persist across dokku restarts
- [ ] `make test` passes all unit tests
- [ ] Services visible on dokku internal network
