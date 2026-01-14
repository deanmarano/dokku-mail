# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dokku plugin for unified email delivery using AWS SES. The goal is to provide a "dokku native" way for homelab apps to send email without configuring AWS SES credentials individually on each service.

The plugin should follow standard Dokku plugin architecture patterns as implemented in [dokku-dns](https://github.com/deanmarano/dokku-dns).

## Development Commands

### Testing
- `make lint` - Run shellcheck linting
- `make test` - Run lint + unit tests
- `make unit-tests` - Run BATS unit tests only
- `scripts/test-docker.sh` - Run Docker-based integration tests

### Development Setup
- `make ci-dependencies` - Install shellcheck, bats, and other tools
- `bash tests/setup.sh` - Setup test environment

### Code Generation
- `make generate` - Generate README.md from help documentation

## Architecture

### Core Files (Root Level)
- `plugin.toml` - Plugin metadata (name, version, dependencies)
- `config` - Plugin configuration (PLUGIN_COMMAND_PREFIX="mail", paths, defaults)
- `commands` - Entry point that routes to subcommands via help-functions
- `functions` - Reusable service logic
- `help-functions` - Help system and command routing
- `log-functions` - Fallback logging functions when dokku functions unavailable
- `install` - Installation script (runs on plugin:install)
- `dependencies` - Dependency installer (aws-cli, jq)

### Directory Structure
- `subcommands/` - Individual command implementations
- `providers/` - Provider implementations (AWS SES, potentially others)
- `tests/` - BATS unit tests and integration tests
- `scripts/` - Development and CI scripts
- `docs/` - Extended documentation

### Hook Files
- `post-create` - Initialize mail config when app created
- `post-delete` - Clean up mail resources when app destroyed
- `post-deploy` - Inject mail environment variables into app

### Data Storage
```
/var/lib/dokku/services/mail/
├── {service-name}/          # Per mail service instance
│   ├── CONTAINER_ID         # Docker container ID
│   ├── LINKS                # Linked apps (one per line)
│   ├── PROVIDER             # Upstream provider name (aws, sendgrid, etc.)
│   ├── provider-config/     # Provider-specific credentials
│   │   ├── AWS_ACCESS_KEY_ID
│   │   ├── AWS_SECRET_ACCESS_KEY
│   │   └── AWS_REGION
│   └── config/              # Service configuration
│       ├── FROM_ADDRESS     # Default from address
│       └── REPLY_TO         # Default reply-to
```

## Plugin Design

### Mail Delivery Strategy

The plugin runs a local SMTP relay that forwards mail to upstream providers (AWS SES initially). This approach:
- Decouples apps from specific mail providers
- Simplifies app configuration (no credentials needed per-app)
- Enables future support for other providers (Mailgun, SendGrid, self-hosted)
- Allows mail queuing if upstream is temporarily unavailable

**Architecture:**
```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│  Dokku App  │────▶│  SMTP Relay     │────▶│  AWS SES    │
│             │     │  (mail service) │     │  (or other) │
└─────────────┘     └─────────────────┘     └─────────────┘
      SMTP to              Authenticates
   mail:25                 to upstream
   (no auth)               provider
```

**Environment variables injected into linked apps:**
- `SMTP_HOST` - Internal hostname of mail relay
- `SMTP_PORT` - 25 (no TLS needed for internal traffic)
- `MAIL_URL` - `smtp://mail:25` (for frameworks that use URL format)

Apps use standard SMTP libraries with no authentication required.

### SMTP Relay Implementation

Options for the relay container:
- **Postfix** - Full-featured, well-documented, heavier
- **msmtp** - Lightweight, simple forwarding only
- **Maddy** - Modern Go-based mail server, supports multiple upstreams
- **sSMTP** - Minimal, deprecated but simple

Recommend starting with Postfix or Maddy for reliability and flexibility.

### Expected Commands

```bash
# Service lifecycle
dokku mail:create <name>              # Create mail relay service
dokku mail:destroy <name>             # Destroy mail relay service
dokku mail:start <name>               # Start the relay
dokku mail:stop <name>                # Stop the relay
dokku mail:restart <name>             # Restart the relay
dokku mail:logs <name>                # View relay logs

# Linking apps
dokku mail:link <name> <app>          # Link app to mail service (injects env vars)
dokku mail:unlink <name> <app>        # Unlink app from mail service

# Provider configuration
dokku mail:provider:set <name> <provider>           # Set upstream provider (aws, sendgrid, etc.)
dokku mail:provider:config <name> KEY=val           # Configure provider credentials

# Testing
dokku mail:test <name> <to>           # Send test email through relay

# Status
dokku mail:info <name>                # Show service info
dokku mail:report [name]              # Show status report
dokku mail:list                       # List all mail services
```

## Development Patterns

### Subcommand Structure
Each subcommand file in `subcommands/` follows this pattern:
```bash
#!/usr/bin/env bash
source "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"
source "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/functions"

service-SUBCOMMAND-cmd() {
  #E dokku mail:example myapp
  #A app, app to configure
  #F --flag, description of flag
  declare desc="description of command"
  # implementation
}

service-SUBCOMMAND-cmd "$@"
```

### Help Comment Conventions
- `#E` - Usage example (shown in help)
- `#A` - Argument definition
- `#F` - Flag definition
- `declare desc=` - Command description

### Path Construction
Always use absolute paths:
```bash
PLUGIN_BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PLUGIN_BASE_PATH/config"
```

### Environment Variable Injection
Use dokku's config system to inject variables into apps:
```bash
dokku config:set --no-restart "$APP" SMTP_HOST="$SMTP_HOST"
```

## Provider System

The plugin uses a provider abstraction (similar to dokku-dns) allowing multiple upstream mail services.

### Provider Interface
Each provider in `providers/` implements:
```bash
provider_validate_credentials()       # Check credentials are valid
provider_get_smtp_config()            # Return SMTP host, port, auth details
provider_test_send(to, subject, body) # Send test email
```

### AWS SES Provider

**Required credentials:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (e.g., us-east-1)

**SMTP endpoints by region:**
- `email-smtp.us-east-1.amazonaws.com:587`
- `email-smtp.eu-west-1.amazonaws.com:587`

**Note:** SES SMTP credentials differ from IAM credentials. The provider should generate SMTP credentials from IAM credentials using the documented signing process.

### Future Providers
- **SendGrid** - API key auth, `smtp.sendgrid.net:587`
- **Mailgun** - API key or SMTP, `smtp.mailgun.org:587`
- **Generic SMTP** - Any SMTP server with credentials

## Reference Implementation

Use [dokku-dns](https://github.com/deanmarano/dokku-dns) as the reference for:
- Plugin file structure
- Command routing system
- Help system implementation
- Testing patterns (BATS)
- Multi-provider architecture (if supporting multiple mail backends)
- Hook implementation
