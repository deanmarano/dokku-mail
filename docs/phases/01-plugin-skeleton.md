# Phase 1: Plugin Skeleton

**Estimated tokens:** 2,500

## Overview

Establish the basic dokku plugin structure with command routing, help system, and installation scripts.

## User Stories

### Story 1.1: Plugin Installation
**As a** dokku administrator
**I want to** install the mail plugin using `dokku plugin:install`
**So that** the mail commands become available on my server

**Acceptance Criteria:**
- [ ] `dokku plugin:install <repo-url>` completes without errors
- [ ] `dokku help` shows mail commands in the list
- [ ] `dokku mail:help` displays available subcommands
- [ ] Plugin files are installed to `/var/lib/dokku/plugins/available/mail/`
- [ ] Symlink created in `/var/lib/dokku/plugins/enabled/mail/`

**Tests:**
```bash
@test "plugin installs successfully" {
  run dokku plugin:install /path/to/mail
  assert_success
}

@test "mail:help shows available commands" {
  run dokku mail:help
  assert_success
  assert_output_contains "mail:create"
  assert_output_contains "mail:link"
}
```

### Story 1.2: Plugin Version
**As a** dokku administrator
**I want to** check the installed plugin version
**So that** I can verify I'm running the expected version

**Acceptance Criteria:**
- [ ] `dokku mail:version` outputs the current version
- [ ] Version matches `plugin.toml` version field

**Tests:**
```bash
@test "mail:version shows version" {
  run dokku mail:version
  assert_success
  assert_output_contains "0.1.0"
}
```

## Deliverables

### Files to Create

```
mail/
├── plugin.toml          # Plugin metadata
├── config               # Plugin configuration variables
├── commands             # Command router entry point
├── help-functions       # Help system
├── log-functions        # Logging fallbacks
├── functions            # Shared utility functions
├── install              # Installation script
├── dependencies         # Dependency installer
├── Makefile             # Build/test commands
├── subcommands/
│   ├── help             # Help command
│   └── version          # Version command
└── tests/
    ├── test_helper.bash # Test utilities
    └── 01_plugin.bats   # Plugin installation tests
```

### Key Configuration

**plugin.toml:**
```toml
[plugin]
description = "SMTP relay service for dokku apps"
version = "0.1.0"

[plugin.dependencies]
jq = "JSON processing"
```

**config:**
```bash
export PLUGIN_COMMAND_PREFIX="mail"
export PLUGIN_SERVICE="mail"
export PLUGIN_DATA_ROOT="${DOKKU_LIB_ROOT:-/var/lib/dokku}/services/mail"
```

## Dependencies

- None (first phase)

## Exit Criteria

- [ ] `make lint` passes with no shellcheck errors
- [ ] `make test` passes all unit tests
- [ ] Plugin can be installed and uninstalled cleanly
- [ ] Help system displays all implemented commands
