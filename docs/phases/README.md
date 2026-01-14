# Development Phases

This directory contains the phased delivery plan for the dokku-mail plugin.

## Recommended: Start with Fast Path

**[Phase 0: Fast Path](00-fast-path.md)** (~3 hrs) gets you to a working e2e test on your local dokku server:
```bash
dokku plugin:install /path/to/mail
dokku mail:create relay1
dokku mail:link relay1 myapp
dokku mail:test relay1 test@example.com
dokku mail:logs relay1  # See captured email
```

Build the full phases after you have something working.

---

## Phase Summary

| Phase | Name | Tokens | Description |
|-------|------|--------|-------------|
| 1 | [Plugin Skeleton](01-plugin-skeleton.md) | 2,500 | Basic plugin structure, command routing, help system |
| 2 | [Service Lifecycle](02-service-lifecycle.md) | 4,000 | Create/destroy/start/stop relay containers |
| 3 | [App Linking](03-app-linking.md) | 3,000 | Link apps to services, inject SMTP env vars |
| 4 | [Mock Provider](04-mock-provider.md) | 2,500 | First provider (testing), provider interface |
| 5 | [AWS SES Provider](05-aws-ses-provider.md) | 4,500 | Production provider for AWS |
| 6 | [Testing & Verification](06-testing-verification.md) | 2,500 | mail:test command, queue management |
| 7 | [Provider Abstraction](07-provider-abstraction.md) | 3,000 | Multi-provider support, generic SMTP |
| 8 | [Polish & Documentation](08-polish-documentation.md) | 2,000 | CI, README generation, error handling |

**Total estimated tokens: 24,000**

## Dependency Graph

```
Phase 1 (Skeleton)
    │
    ▼
Phase 2 (Lifecycle)
    │
    ▼
Phase 3 (Linking)
    │
    ▼
Phase 4 (Mock Provider)
    │
    ├───────────────┐
    ▼               ▼
Phase 5         Phase 6
(AWS SES)       (Testing)
    │               │
    └───────┬───────┘
            ▼
        Phase 7
       (Providers)
            │
            ▼
        Phase 8
        (Polish)
```

## Milestones

### Testable (Phases 1-4)
- Working plugin with service lifecycle
- Apps can link and send mail
- Mock provider for testing without external services

### MVP (Phases 1-6)
- AWS SES as production provider
- Test commands for verification
- Queue management

### Feature Complete (Phases 1-7)
- Multiple provider support
- Generic SMTP backend

### Production Ready (Phases 1-8)
- Full documentation
- CI pipeline
- Error handling polish
- Upgrade path

## Document Structure

Each phase document contains:
- **Overview**: What the phase delivers
- **User Stories**: Requirements in user story format
- **Acceptance Criteria**: Checkboxes for done definition
- **Tests**: BATS test examples
- **Deliverables**: Files to create
- **Dependencies**: Required prior phases
- **Exit Criteria**: Definition of done for the phase
