# Phase 8: Polish & Documentation

**Estimated tokens:** 2,000

## Overview

Final polish, comprehensive documentation, and CI/CD setup.

## User Stories

### Story 8.1: README Generation
**As a** potential user
**I want** comprehensive documentation
**So that** I can understand and use the plugin

**Acceptance Criteria:**
- [ ] `make generate` creates README.md from code
- [ ] README includes: installation, quick start, all commands, provider setup
- [ ] Help text extracted from subcommand `#E`, `#A`, `#F` comments
- [ ] Examples for common workflows

**Tests:**
```bash
@test "README generation works" {
  run make generate
  assert_success
  [[ -f "README.md" ]]
  grep -q "mail:create" README.md
}
```

### Story 8.2: CI Pipeline
**As a** contributor
**I want** automated testing on every PR
**So that** regressions are caught early

**Acceptance Criteria:**
- [ ] GitHub Actions workflow for CI
- [ ] Runs: shellcheck lint, BATS unit tests
- [ ] Optional: Docker integration tests
- [ ] Status badge in README

**Tests:**
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make ci-dependencies
      - run: make lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make ci-dependencies
      - run: make unit-tests
```

### Story 8.3: Error Messages
**As a** user
**I want** clear error messages
**So that** I can fix problems quickly

**Acceptance Criteria:**
- [ ] All error paths have descriptive messages
- [ ] Suggestions provided where possible ("Did you mean...?")
- [ ] Exit codes are consistent (0=success, 1=error)
- [ ] Verbose mode (`DOKKU_TRACE=1`) shows debug info

**Tests:**
```bash
@test "clear error for missing service" {
  run dokku mail:info nonexistent
  assert_failure
  assert_output_contains "Service 'nonexistent' does not exist"
}

@test "helpful error for unlinked app" {
  dokku apps:create myapp
  run dokku mail:test-app myapp test@example.com
  assert_failure
  assert_output_contains "not linked"
  assert_output_contains "dokku mail:link"
}
```

### Story 8.4: Shell Completion
**As a** user
**I want** tab completion for commands
**So that** I can work faster

**Acceptance Criteria:**
- [ ] Bash completion for `dokku mail:*` commands
- [ ] Completes service names where applicable
- [ ] Completes app names for link/unlink

### Story 8.5: Upgrade Path
**As a** user upgrading the plugin
**I want** automatic data migration
**So that** my services keep working

**Acceptance Criteria:**
- [ ] `post-plugin-update` hook handles migrations
- [ ] Version stored in plugin data
- [ ] Migration scripts for breaking changes
- [ ] Backup created before migration

## Deliverables

### Files to Create

```
mail/
├── .github/
│   └── workflows/
│       └── ci.yml           # CI pipeline
├── bin/
│   └── generate             # README generator
├── completions/
│   └── bash                 # Bash completion
├── post-plugin-update       # Upgrade hook
├── README.md                # Generated docs
├── CHANGELOG.md             # Version history
└── tests/
    └── 08_polish.bats
```

### README Structure

```markdown
# dokku-mail

SMTP relay service for dokku apps.

## Installation

## Quick Start

## Commands

### Service Management
### App Linking
### Provider Configuration
### Testing

## Providers

### AWS SES
### Generic SMTP

## Troubleshooting

## Contributing
```

## Dependencies

- Phase 1-7 complete

## Exit Criteria

- [ ] README is complete and accurate
- [ ] CI pipeline passing
- [ ] All commands have help text
- [ ] Error messages are helpful
- [ ] `make lint` and `make test` pass
