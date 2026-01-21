# dokku-mail

SMTP relay service plugin for [Dokku](https://dokku.com/). Provides outbound email capability for your apps through various email providers.

## Features

- **Multiple Providers**: AWS SES, Resend, Mailgun, SendGrid, Generic SMTP, or Mock (MailHog)
- **Simple Linking**: Apps get `SMTP_HOST`, `SMTP_PORT`, and `MAIL_URL` environment variables automatically
- **Unified Interface**: Same commands work across all providers
- **Built-in Diagnostics**: Health checks, status monitoring, and troubleshooting tools
- **Tested**: Comprehensive BATS integration test suite

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
```

When linked, apps receive these environment variables:
- `SMTP_HOST` - Container IP address
- `SMTP_PORT` - SMTP port (usually 25 internally)
- `MAIL_URL` - Full SMTP URL (smtp://host:port)

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

### Config Drift

If `mail:doctor` shows "config drift detected":

```bash
dokku mail:link <service> <app>
```

This updates the app's environment variables to match the current container IP.

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
