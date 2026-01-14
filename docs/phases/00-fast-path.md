# Phase 0: Fast Path to E2E Testing

**Estimated tokens:** 5,000

## Goal

Get a working end-to-end flow on your local dokku server ASAP:
```bash
dokku plugin:install /path/to/mail
dokku mail:create mymail
dokku mail:link mymail myapp
# App sends email → relay captures it → you see it in logs
```

## Minimal Viable Slice

Skip the full phase structure. Build just enough to:
1. Install the plugin
2. Create a relay container (hardcoded to mock/local delivery)
3. Link an app (inject SMTP_HOST, SMTP_PORT)
4. Send test email and see it captured

## Implementation Order

### Step 1: Plugin Shell (~30 min)

Create minimal files to make `dokku plugin:install` work:

```
mail/
├── plugin.toml
├── commands
├── subcommands/
│   └── help
└── install
```

**Test:** `dokku plugin:install /home/dean/gitlab/mail` succeeds

### Step 2: Create Command + Container (~1 hr)

Add `mail:create` that spins up a Postfix container in local-only mode:

```
mail/
├── config
├── functions
└── subcommands/
    └── create
```

**Container:** Use `boky/postfix` or similar, configured to:
- Accept mail on port 25
- NOT relay externally (local delivery only)
- Store mail in `/var/mail/` inside container

**Test:**
```bash
dokku mail:create testmail
docker ps | grep dokku.mail.testmail  # Container running
```

### Step 3: Link Command (~30 min)

Add `mail:link` that injects env vars into app:

```
mail/
└── subcommands/
    └── link
```

**Test:**
```bash
dokku mail:link testmail myapp
dokku config:get myapp SMTP_HOST  # Returns dokku.mail.testmail
```

### Step 4: Test Email (~30 min)

Add `mail:test` that sends email through relay:

```
mail/
└── subcommands/
    └── test
```

**Test:**
```bash
dokku mail:test testmail you@example.com
dokku mail:logs testmail  # See the email was received
```

## Files to Create (Minimum)

### plugin.toml
```toml
[plugin]
description = "SMTP relay service for dokku apps"
version = "0.1.0"
```

### install
```bash
#!/usr/bin/env bash
set -eo pipefail
echo "Mail plugin installed"
```

### config
```bash
#!/usr/bin/env bash
export PLUGIN_COMMAND_PREFIX="mail"
export PLUGIN_SERVICE="mail"
export PLUGIN_DATA_ROOT="${DOKKU_LIB_ROOT:-/var/lib/dokku}/services/mail"
export PLUGIN_IMAGE="boky/postfix"
export PLUGIN_IMAGE_VERSION="latest"
```

### commands
```bash
#!/usr/bin/env bash
set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"

case "$1" in
  mail:*)
    subcommand="${1#mail:}"
    shift
    if [[ -x "$(dirname "${BASH_SOURCE[0]}")/subcommands/$subcommand" ]]; then
      exec "$(dirname "${BASH_SOURCE[0]}")/subcommands/$subcommand" "$@"
    fi
    ;;
esac
```

### subcommands/create
```bash
#!/usr/bin/env bash
set -eo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

SERVICE="$1"
[[ -z "$SERVICE" ]] && echo "Usage: dokku mail:create <name>" && exit 1

SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
mkdir -p "$SERVICE_ROOT"

# Create container - local delivery only (no relay)
docker run -d \
  --name "dokku.mail.$SERVICE" \
  --restart unless-stopped \
  --network dokku \
  -e "ALLOWED_SENDER_DOMAINS=*" \
  -e "RELAYHOST=" \
  "$PLUGIN_IMAGE:$PLUGIN_IMAGE_VERSION"

echo "$SERVICE" > "$SERVICE_ROOT/CONTAINER_NAME"
echo "-----> Mail service $SERVICE created"
```

### subcommands/link
```bash
#!/usr/bin/env bash
set -eo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

SERVICE="$1"
APP="$2"
[[ -z "$SERVICE" || -z "$APP" ]] && echo "Usage: dokku mail:link <service> <app>" && exit 1

CONTAINER_NAME="dokku.mail.$SERVICE"

# Inject env vars
dokku config:set --no-restart "$APP" \
  SMTP_HOST="$CONTAINER_NAME" \
  SMTP_PORT="25" \
  MAIL_URL="smtp://$CONTAINER_NAME:25"

echo "-----> $APP linked to $SERVICE"
```

### subcommands/test
```bash
#!/usr/bin/env bash
set -eo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

SERVICE="$1"
TO="$2"
[[ -z "$SERVICE" || -z "$TO" ]] && echo "Usage: dokku mail:test <service> <to>" && exit 1

CONTAINER_NAME="dokku.mail.$SERVICE"

# Send test email using container's sendmail
docker exec "$CONTAINER_NAME" sh -c "echo -e 'Subject: Test from dokku-mail\n\nThis is a test email from $SERVICE' | sendmail '$TO'"

echo "-----> Test email sent to $TO"
echo "       Check: dokku mail:logs $SERVICE"
```

### subcommands/logs
```bash
#!/usr/bin/env bash
set -eo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config"

SERVICE="$1"
[[ -z "$SERVICE" ]] && echo "Usage: dokku mail:logs <service>" && exit 1

docker logs "dokku.mail.$SERVICE" "${@:2}"
```

## Testing on Your Dokku Server

```bash
# 1. Install
dokku plugin:install /home/dean/gitlab/mail

# 2. Create relay
dokku mail:create relay1

# 3. Create test app (or use existing)
dokku apps:create testapp || true

# 4. Link
dokku mail:link relay1 testapp

# 5. Verify env vars
dokku config testapp | grep SMTP

# 6. Send test
dokku mail:test relay1 your@email.com

# 7. Check logs
dokku mail:logs relay1

# Cleanup for re-testing
dokku plugin:uninstall mail
docker rm -f dokku.mail.relay1
```

## After This Works

Once you have e2e working, layer in:
1. Proper error handling
2. `mail:destroy`, `mail:unlink`
3. Provider system (to actually relay externally)
4. Help system
5. Tests

## Recommended: Use MailHog for Testing

Instead of `boky/postfix`, use **MailHog** for the fast path - it captures all emails and provides a web UI:

```bash
docker run -d \
  --name "dokku.mail.$SERVICE" \
  --restart unless-stopped \
  --network dokku \
  -p 8025:8025 \
  mailhog/mailhog
```

- SMTP on port 1025 (not 25)
- Web UI on port 8025 - visit `http://your-dokku-server:8025` to see emails
- No config needed - captures everything

Update `subcommands/link` to use port 1025:
```bash
dokku config:set --no-restart "$APP" \
  SMTP_HOST="$CONTAINER_NAME" \
  SMTP_PORT="1025" \
  MAIL_URL="smtp://$CONTAINER_NAME:1025"
```

## Notes

- Container needs to be on `dokku` network to be reachable by apps
- MailHog is for testing only - switch to real relay for production
- The 8025 port mapping lets you access the web UI from your browser
