# Provider Interface Specification

This document defines the interface that all mail providers must implement.

## Overview

Providers are bash scripts located in `providers/<name>/provider.sh` that define how to create and manage SMTP relay containers for different email services.

## Required Variables

Every provider must define these variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `PROVIDER_NAME` | Unique identifier | `smtp`, `aws`, `mailgun` |
| `PROVIDER_DISPLAY_NAME` | Human-readable name | `Generic SMTP`, `AWS SES` |
| `PROVIDER_IMAGE` | Docker image to use | `boky/postfix` |
| `PROVIDER_IMAGE_VERSION` | Image tag | `latest` |
| `PROVIDER_SMTP_PORT` | Port apps connect to | `25` |
| `PROVIDER_REQUIRED_CONFIG` | Space-separated required config keys | `SMTP_HOST SMTP_PORT` |

Optional variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `PROVIDER_WEB_PORT` | Web UI port (if applicable) | `8025` |
| `PROVIDER_OPTIONAL_CONFIG` | Space-separated optional config keys | `SMTP_TLS FROM_DOMAIN` |

## Required Functions

### provider_create_container

Creates and starts the Docker container for the mail relay.

```bash
provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read configuration
  local MY_CONFIG
  MY_CONFIG=$(cat "$CONFIG_DIR/MY_CONFIG" 2>/dev/null)

  # Validate required config exists
  if [[ -z "$MY_CONFIG" ]]; then
    echo "!     Missing required config: MY_CONFIG"
    return 1
  fi

  # Create container
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "SOME_VAR=$MY_CONFIG" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Returns:**
- `0` on success
- `1` on failure (missing config, docker error, etc.)

**Requirements:**
- Container name must be `dokku.mail.$SERVICE`
- Must use `--restart unless-stopped`
- Must connect to `bridge` network

### provider_get_smtp_port

Returns the SMTP port that apps should connect to.

```bash
provider_get_smtp_port() {
  local SERVICE="$1"
  echo "$PROVIDER_SMTP_PORT"
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Returns:**
- Prints port number to stdout

### provider_verify

Verifies that the provider configuration is valid and connectivity works.

```bash
provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Check config exists
  local MY_CONFIG
  MY_CONFIG=$(cat "$CONFIG_DIR/MY_CONFIG" 2>/dev/null)

  if [[ -z "$MY_CONFIG" ]]; then
    echo "!     Missing required config: MY_CONFIG"
    return 1
  fi

  # Test connectivity
  echo "       Verifying connection to smtp.example.com..."
  if nc -z -w5 smtp.example.com 587 2>/dev/null; then
    echo "       ✓ SMTP endpoint reachable"
    return 0
  else
    echo "!     Cannot connect to smtp.example.com:587"
    return 1
  fi
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Returns:**
- `0` if verification passes
- `1` if verification fails

**Output:**
- Print status messages prefixed with `       ` (7 spaces) for info
- Print errors prefixed with `!     ` for errors
- Use `✓` for success indicators

### provider_info

Displays the current provider configuration. Must mask sensitive values.

```bash
provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local MY_CONFIG API_KEY
  MY_CONFIG=$(cat "$CONFIG_DIR/MY_CONFIG" 2>/dev/null || echo "(not set)")
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "(not set)")

  # Mask secrets - show first 6 and last 4 characters
  if [[ "$API_KEY" != "(not set)" ]]; then
    API_KEY="${API_KEY:0:6}***${API_KEY: -4}"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Config: $MY_CONFIG"
  echo "       API Key: $API_KEY"
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Output:**
- Print config values prefixed with `       ` (7 spaces)
- Mask sensitive values (API keys, passwords) showing only first 6 and last 4 chars

## Optional Functions

### provider_validate_config

Validates configuration before applying. Called by `provider:apply`.

```bash
provider_validate_config() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Check required config
  for key in $PROVIDER_REQUIRED_CONFIG; do
    if [[ ! -f "$CONFIG_DIR/$key" ]] || [[ -z "$(cat "$CONFIG_DIR/$key")" ]]; then
      echo "!     Missing required config: $key"
      return 1
    fi
  done

  # Provider-specific validation
  local SMTP_PORT
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null)
  if ! [[ "$SMTP_PORT" =~ ^[0-9]+$ ]]; then
    echo "!     SMTP_PORT must be a number"
    return 1
  fi

  return 0
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Returns:**
- `0` if config is valid
- `1` if config is invalid

**Note:** If not implemented, `provider:apply` will only check that required config keys exist.

### provider_doctor

Runs provider-specific diagnostic checks. Called by `mail:doctor`.

```bash
provider_doctor() {
  local SERVICE="$1"
  local issues=0

  # Provider-specific checks
  echo "-----> Checking provider-specific configuration..."

  # Example: Check API key validity
  local API_KEY
  API_KEY=$(cat "$SERVICE_ROOT/provider-config/API_KEY" 2>/dev/null)

  if ! curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $API_KEY" \
       "https://api.example.com/verify" | grep -q "200"; then
    echo "       ✗ API key is invalid or expired"
    ((issues++))
  else
    echo "       ✓ API key is valid"
  fi

  return $issues
}
```

**Parameters:**
- `SERVICE` - Name of the mail service

**Returns:**
- Number of issues found (0 = healthy)

## Configuration Storage

Provider configuration is stored in individual files under `$SERVICE_ROOT/provider-config/`:

```
/var/lib/dokku/services/mail/{service}/
├── PROVIDER              # Provider name (e.g., "smtp")
├── CONTAINER_NAME        # Docker container name
├── LINKS                 # Linked apps (one per line)
└── provider-config/
    ├── SMTP_HOST         # Each config key is a separate file
    ├── SMTP_PORT
    ├── SMTP_USERNAME
    └── SMTP_PASSWORD
```

## Container Requirements

All provider containers must:

1. Accept SMTP connections on the port specified by `PROVIDER_SMTP_PORT`
2. Relay mail to the upstream provider
3. Not require authentication from linked apps (internal relay)
4. Handle TLS/authentication to upstream transparently

## Example Provider

See `providers/_template/provider.sh` for a complete reference implementation.

## Adding a New Provider

1. Create directory: `providers/<name>/`
2. Create `provider.sh` implementing all required functions
3. Add setup command (optional): `subcommands/<name>:setup`
4. Add to help output in `commands`
5. Add tests in `tests/integration/test_<name>_provider.bats`
6. Document in README.md
