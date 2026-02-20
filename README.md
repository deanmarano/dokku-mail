# dokku-mail

SMTP relay service plugin for [Dokku](https://dokku.com). Provides outbound email capability for your apps through various email providers.

## Prerequisites

- [Dokku](https://dokku.com) 0.34+
- [dokku-dns](https://github.com/deanmarano/dokku-dns) (for automated DNS record creation with provider setup commands)

## Installation

```bash
dokku plugin:install https://github.com/deanmarano/dokku-mail.git mail
```

## Quick Start

```bash
# Create a mail service (uses mock provider by default)
dokku mail:create default

# Start the container
dokku mail:provider:apply default

# Link to your app
dokku mail:link default myapp

# Send a test email
dokku mail:test default you@example.com
```

## Commands

| Command | Description |
|---|---|
| `mail:create <service>` | Create a mail service |
| `mail:destroy <service> [-f]` | Delete a mail service |
| `mail:list` | List all mail services |
| `mail:info <service>` | Show service information |
| `mail:logs <service> [-t]` | View container logs |
| `mail:status <service> [-q]` | Health check (exit: 0=healthy, 1=degraded, 2=down) |
| `mail:doctor <service> [-v]` | Run comprehensive diagnostics |
| `mail:test <service> <to-address>` | Send test email |
| `mail:link <service> <app>` | Link app to mail service |
| `mail:unlink <service> <app>` | Unlink app |
| `mail:vars:set <app> KEY=%VALUE%` | Set custom env var mappings |
| `mail:vars:list <app>` | View current custom vars |
| `mail:vars:unset <app> <key>` | Remove a custom var |
| `mail:provider:set <service> <provider>` | Switch provider |
| `mail:provider:config <service> KEY=value` | Set provider configuration |
| `mail:provider:info <service>` | Show provider configuration |
| `mail:provider:apply <service>` | Apply changes (restarts container) |
| `mail:provider:verify <service>` | Verify credentials |
| `mail:provider:reset <service>` | Reset for reconfiguration |

## App Environment Variables

When linked, apps receive:

```
SMTP_HOST=<container-name>
SMTP_PORT=25
MAIL_URL=smtp://host:port
```

### Custom Variables

Different apps expect different env var names. Use templates or set them manually:

```bash
dokku mail:vars:set myapp --template=lldap
dokku mail:vars:set myapp MAILER_HOST=%HOST% MAILER_PORT=%PORT%
```

Available placeholders: `%HOST%`, `%PORT%`, `%DOMAIN%`, `%APP%`

Built-in templates: `lldap`, `authelia`, `nextcloud`, `gitea`, `gitlab`, `rails`

## Provider Comparison

| Provider | Best For | DNS Setup | API Validation |
|---|---|---|---|
| **Mock** (default) | Development, testing | None required | No |
| **AWS SES** | High volume, AWS users | Automated (via dokku-dns) | Yes |
| **Resend** | Simple API, good DX | Automated (via dokku-dns) | Yes |
| **Mailgun** | Established service | Automated (via dokku-dns) | Yes |
| **SendGrid** | Popular, reliable | Automated (via dokku-dns) | Yes |
| **SMTP** | Existing SMTP server | N/A | No |

## Provider Setup

### Mock (Default)

No configuration needed. Emails are captured locally.

```bash
dokku mail:create myservice
dokku mail:provider:apply myservice
```

### AWS SES

```bash
dokku mail:provider:set myservice aws
dokku mail:aws:setup myservice yourdomain.com us-east-1
dokku mail:provider:apply myservice
```

### Resend

```bash
dokku mail:provider:set myservice resend
dokku mail:resend:setup myservice yourdomain.com re_your_api_key
dokku mail:provider:apply myservice
```

### Mailgun

```bash
dokku mail:provider:set myservice mailgun
dokku mail:mailgun:setup myservice mg.yourdomain.com your_api_key
dokku mail:provider:apply myservice
```

### SendGrid

```bash
dokku mail:provider:set myservice sendgrid
dokku mail:sendgrid:setup myservice SG.your_api_key yourdomain.com
dokku mail:provider:apply myservice
```

### Generic SMTP

```bash
dokku mail:provider:set myservice smtp
dokku mail:provider:config myservice SMTP_HOST=smtp.example.com
dokku mail:provider:config myservice SMTP_PORT=587
dokku mail:provider:config myservice SMTP_USERNAME=user
dokku mail:provider:config myservice SMTP_PASSWORD=pass
dokku mail:provider:apply myservice
```

## Development

```bash
npm install -g bats
make test
```

## License

MIT
