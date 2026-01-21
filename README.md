# dokku-mail

SMTP relay service plugin for [Dokku](https://dokku.com/). Provides outbound email capability for your apps through various email providers.

## Features

- **Multiple Providers**: AWS SES, Resend, Mailgun, SendGrid, Generic SMTP, or Mock (MailHog)
- **Simple Linking**: Apps get `SMTP_HOST`, `SMTP_PORT`, and `MAIL_URL` environment variables automatically
- **Network-based**: Uses Docker networks for stable connections that survive reboots
- **Custom Vars**: Configurable env var mappings with built-in templates
- **Unified Interface**: Same commands work across all providers
- **Built-in Diagnostics**: Health checks, status monitoring, and troubleshooting tools

## Quick Start

```bash
# Install the plugin
dokku plugin:install https://github.com/deanmarano/dokku-mail.git mail

# Create a mail service (uses mock provider by default)
dokku mail:create default

# Start the container
dokku mail:provider:apply default

# Link to your app
dokku mail:link default myapp

# Send a test email
dokku mail:test default you@example.com
```

## Provider Comparison

| Provider | Best For | DNS Setup | API Validation |
|----------|----------|-----------|----------------|
| **Mock** | Development, testing | None required | No |
| **AWS SES** | High volume, AWS users | Automated (via dokku-dns) | Yes (via AWS CLI) |
| **Resend** | Simple API, good DX | Automated (via dokku-dns) | Yes |
| **Mailgun** | Established service | Manual | Yes |
| **SendGrid** | Popular, reliable | Manual | Yes |
| **SMTP** | Existing SMTP server | N/A | No |

## Installation

```bash
dokku plugin:install https://github.com/deanmarano/dokku-mail.git mail
```

### Required: dokku-dns for DNS Automation

The provider setup commands (`aws:setup`, `resend:setup`, etc.) require [dokku-dns](https://github.com/deanmarano/dokku-dns) for automated DNS record creation (DKIM, SPF, DMARC):

```bash
dokku plugin:install https://github.com/deanmarano/dokku-dns.git dns
```

Configure dokku-dns with your DNS provider (AWS Route53, Cloudflare, DigitalOcean, etc.) before running provider setup commands.

## Usage

### Service Lifecycle

```bash
# Create a mail service
dokku mail:create <service>

# List all mail services
dokku mail:list

# Show service information
dokku mail:info <service>

# View container logs
dokku mail:logs <service> [-t|--tail]

# Delete a service
dokku mail:destroy <service> [-f|--force]
```

### App Linking

```bash
# Link an app to the mail service
dokku mail:link <service> <app>

# Unlink an app
dokku mail:unlink <service> <app>

# Re-run link to refresh config (idempotent)
dokku mail:link <service> <app>
```

When linked, apps receive these environment variables:
- `SMTP_HOST` - Container name (resolved via Docker DNS)
- `SMTP_PORT` - SMTP port (25 for all providers)
- `MAIL_URL` - Full SMTP URL (smtp://host:port)

**Network-based linking**: Apps are attached to the mail service's Docker network and use the container name for SMTP_HOST. This means the connection survives container restarts and IP changes - no need to re-link after reboots.

**Idempotent**: Running `mail:link` on an already-linked app refreshes its config. Use this after changing providers or custom vars.

### Custom Environment Variables

Different apps expect different environment variable names. Use `mail:vars:set` to customize:

```bash
# Set custom vars with placeholders
dokku mail:vars:set myapp MAILER_HOST=%HOST% MAILER_PORT=%PORT%

# Use a built-in template
dokku mail:vars:set myapp --template=lldap

# Clear custom vars (use defaults only)
dokku mail:vars:set myapp --template=none

# View current custom vars
dokku mail:vars:list myapp

# Remove a specific var
dokku mail:vars:unset myapp MAILER_HOST
```

**Available placeholders:**
- `%HOST%` - SMTP container name
- `%PORT%` - SMTP port
- `%DOMAIN%` - Sender domain (if configured)
- `%APP%` - App name

**Built-in templates:** `lldap`, `authelia`, `nextcloud`, `gitea`, `gitlab`, `rails`

**Auto-refresh**: If the app is already linked, `vars:set` automatically refreshes the link to apply changes immediately.

### Provider Configuration

```bash
# Switch provider
dokku mail:provider:set <service> <provider>

# Set configuration
dokku mail:provider:config <service> KEY=value

# Show configuration
dokku mail:provider:info <service>

# Apply changes (restarts container)
dokku mail:provider:apply <service>

# Verify credentials
dokku mail:provider:verify <service>

# Reset for reconfiguration
dokku mail:provider:reset <service>
```

### Diagnostics

```bash
# Run comprehensive diagnostics
dokku mail:doctor <service> [-v|--verbose]

# Quick health check (for scripts)
dokku mail:status <service> [-q|--quiet]
# Exit codes: 0=healthy, 1=degraded, 2=down

# Send test email
dokku mail:test <service> <to-address>
```

## Provider Setup

### Mock (Default)

No configuration needed. Emails are captured locally and viewable at `http://localhost:8025`.

```bash
dokku mail:create myservice
dokku mail:provider:apply myservice
```

### AWS SES

Requires AWS CLI configured with appropriate permissions.

```bash
dokku mail:provider:set myservice aws
dokku mail:aws:setup myservice yourdomain.com us-east-1
dokku mail:provider:apply myservice
```

The setup command:
- Creates an IAM user with SES permissions
- Generates SMTP credentials
- Configures DNS records (if using Route53)
- Requests production access (manual approval required)

### Resend

```bash
dokku mail:provider:set myservice resend
dokku mail:resend:setup myservice yourdomain.com re_your_api_key
dokku mail:provider:apply myservice
```

### Mailgun

```bash
dokku mail:provider:set myservice mailgun
dokku mail:mailgun:setup myservice yourdomain.com your_api_key
dokku mail:provider:apply myservice
```

For EU region:
```bash
dokku mail:provider:config myservice REGION=eu
```

### SendGrid

```bash
dokku mail:provider:set myservice sendgrid
dokku mail:sendgrid:setup myservice SG.your_api_key
dokku mail:provider:apply myservice
```

### Generic SMTP

```bash
dokku mail:provider:set myservice smtp
dokku mail:smtp:setup myservice
# Follow prompts for host, port, username, password

# Or configure manually:
dokku mail:provider:config myservice SMTP_HOST=smtp.example.com
dokku mail:provider:config myservice SMTP_PORT=587
dokku mail:provider:config myservice SMTP_USERNAME=user
dokku mail:provider:config myservice SMTP_PASSWORD=pass
dokku mail:provider:config myservice SMTP_TLS=starttls  # starttls, ssl, or none

dokku mail:provider:apply myservice
```

## Troubleshooting

### Connection Refused

If your app can't connect to the mail service:

1. Check the service is running: `dokku mail:status <service>`
2. Run diagnostics: `dokku mail:doctor <service> --verbose`
3. Verify the app has correct config: `dokku config:show <app> | grep SMTP`
4. Re-link if needed: `dokku mail:link <service> <app>`

### Emails Not Delivered

1. Check container logs: `dokku mail:logs <service> -t`
2. Verify provider credentials: `dokku mail:provider:verify <service>`
3. For AWS SES: Check sandbox mode and domain verification
4. For other providers: Check domain/sender verification in provider dashboard

### Refreshing App Config

If you change providers, update custom vars, or need to refresh an app's mail configuration:

```bash
dokku mail:link <service> <app>
```

This re-applies all environment variables with current values. The link command is idempotent - safe to run multiple times.

## Development

### Running Tests

```bash
# Install BATS
npm install -g bats

# Run all tests
make test
```

### Adding a New Provider

1. Copy `providers/_template/provider.sh` to `providers/yourprovider/`
2. Implement required functions (see `docs/PROVIDER_INTERFACE.md`)
3. Add setup command in `subcommands/yourprovider:setup`
4. Update help in `commands`
5. Add tests in `tests/integration/`

## License

MIT
