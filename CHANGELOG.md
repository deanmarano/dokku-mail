# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-21

### Added

#### Core Features
- Service lifecycle management (create, destroy, list, info)
- App linking with automatic SMTP environment variable configuration
- Multiple email provider support with unified interface
- Container logs access with tail support
- Test email sending capability

#### Providers
- **Mock (MailHog)** - Local email capture for development/testing
- **AWS SES** - Amazon Simple Email Service with IAM and DNS automation
- **Resend** - Modern transactional email API
- **Generic SMTP** - Connect to any SMTP server
- **Mailgun** - Transactional email service with US/EU regions
- **SendGrid** - Popular transactional email service

#### Provider Configuration
- `mail:provider:set` - Switch between providers
- `mail:provider:config` - Set provider-specific configuration
- `mail:provider:info` - Display provider configuration (masks sensitive values)
- `mail:provider:apply` - Apply configuration and start container
- `mail:provider:verify` - Verify provider credentials and connectivity
- `mail:provider:reset` - Reset provider for reconfiguration

#### Provider Setup Helpers
- `mail:aws:setup` - Automated AWS SES setup with IAM user and DNS
- `mail:aws:add-domain` - Add additional sender domains to AWS SES
- `mail:resend:setup` - Resend setup with DNS configuration
- `mail:mailgun:setup` - Mailgun setup with API validation
- `mail:sendgrid:setup` - SendGrid setup with API key validation
- `mail:smtp:setup` - Generic SMTP configuration

#### Diagnostics
- `mail:doctor` - Comprehensive diagnostic checks for service health
  - Service existence and container status
  - Provider-specific configuration validation
  - Linked app configuration drift detection
  - Verbose mode (`-v/--verbose`) for detailed output
- `mail:status` - Quick health check with scripting-friendly exit codes
  - Exit 0: healthy
  - Exit 1: degraded
  - Exit 2: down
  - Quiet mode (`-q/--quiet`) for minimal output

#### Testing
- BATS integration test suite with 34 tests
- Test helpers for service lifecycle and container management
- CI-ready Makefile with test target

#### Documentation
- Provider interface specification (docs/PROVIDER_INTERFACE.md)
- Provider template for creating new providers

### Technical Details
- All providers use the boky/postfix Docker image for SMTP relay
- Automatic container IP assignment to linked apps
- Config files stored in /var/lib/dokku/services/mail/<service>/
- Sensitive values (passwords, API keys) masked in info output
