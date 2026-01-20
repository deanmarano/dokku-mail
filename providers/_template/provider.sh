#!/usr/bin/env bash
# Template provider - copy this to create a new provider
#
# To create a new provider:
# 1. Copy this directory: cp -r providers/_template providers/myprovider
# 2. Edit provider.sh with your provider's configuration
# 3. Create setup command (optional): subcommands/myprovider:setup
# 4. Add to help output in commands file
# 5. Add tests in tests/integration/test_myprovider_provider.bats

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

PROVIDER_NAME="template"
PROVIDER_DISPLAY_NAME="Template Provider"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="SMTP_HOST SMTP_USERNAME SMTP_PASSWORD"

# Optional: Web UI port (for providers like MailHog)
# PROVIDER_WEB_PORT="8025"

# Optional: Config keys that are not required but supported
# PROVIDER_OPTIONAL_CONFIG="TLS_MODE FROM_DOMAIN"

# =============================================================================
# REQUIRED FUNCTIONS
# =============================================================================

# Creates and starts the Docker container for the mail relay
# Arguments: SERVICE - name of the mail service
# Returns: 0 on success, 1 on failure
provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read configuration
  local SMTP_HOST SMTP_USERNAME SMTP_PASSWORD
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null)
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null)
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null)

  # Validation should be done by provider_validate_config, but double-check
  if [[ -z "$SMTP_HOST" ]] || [[ -z "$SMTP_USERNAME" ]] || [[ -z "$SMTP_PASSWORD" ]]; then
    echo "!     Missing required configuration"
    return 1
  fi

  # Create and start container
  # The boky/postfix image is a good choice for relaying - it handles
  # TLS, authentication, and connection pooling automatically
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "RELAYHOST=$SMTP_HOST:587" \
    -e "RELAYHOST_USERNAME=$SMTP_USERNAME" \
    -e "RELAYHOST_PASSWORD=$SMTP_PASSWORD" \
    -e "ALLOWED_SENDER_DOMAINS=*" \
    -e "POSTFIX_smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}

# Returns the SMTP port that apps should connect to
# Arguments: SERVICE - name of the mail service
# Returns: prints port number to stdout
provider_get_smtp_port() {
  local SERVICE="$1"
  echo "$PROVIDER_SMTP_PORT"
}

# Validates configuration before applying
# Arguments: SERVICE - name of the mail service
# Returns: 0 if valid, 1 if invalid
provider_validate_config() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local errors=0

  # Check all required config keys exist and are non-empty
  for key in $PROVIDER_REQUIRED_CONFIG; do
    if [[ ! -f "$CONFIG_DIR/$key" ]] || [[ -z "$(cat "$CONFIG_DIR/$key" 2>/dev/null)" ]]; then
      echo "!     Missing required config: $key"
      ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "       Configure with: dokku mail:provider:config $SERVICE KEY=value"
    return 1
  fi

  # Add provider-specific validation here
  # Example: validate host format, API key format, etc.

  return 0
}

# Verifies that the provider is configured correctly and connectivity works
# Arguments: SERVICE - name of the mail service
# Returns: 0 if verification passes, 1 if it fails
provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local SMTP_HOST
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null)

  if [[ -z "$SMTP_HOST" ]]; then
    echo "!     Missing SMTP host configuration"
    return 1
  fi

  echo "       Verifying connection to $SMTP_HOST..."

  # Test TCP connectivity to SMTP endpoint
  if nc -z -w5 "$SMTP_HOST" 587 2>/dev/null; then
    echo "       ✓ SMTP endpoint reachable"
    echo "       ✓ Credentials configured"
    return 0
  else
    echo "!     Cannot connect to $SMTP_HOST:587"
    return 1
  fi
}

# Displays the current provider configuration
# Arguments: SERVICE - name of the mail service
# Note: Always mask sensitive values (API keys, passwords)
provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local SMTP_HOST SMTP_USERNAME SMTP_PASSWORD
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null || echo "(not set)")
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null || echo "(not set)")
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null || echo "(not set)")

  # Mask sensitive values - show first 6 and last 4 characters
  if [[ "$SMTP_PASSWORD" != "(not set)" ]] && [[ ${#SMTP_PASSWORD} -gt 10 ]]; then
    SMTP_PASSWORD="${SMTP_PASSWORD:0:6}***${SMTP_PASSWORD: -4}"
  elif [[ "$SMTP_PASSWORD" != "(not set)" ]]; then
    SMTP_PASSWORD="***"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Host: $SMTP_HOST"
  echo "       Username: $SMTP_USERNAME"
  echo "       Password: $SMTP_PASSWORD"
}

# =============================================================================
# OPTIONAL FUNCTIONS
# =============================================================================

# Runs provider-specific diagnostic checks
# Arguments: SERVICE - name of the mail service
# Returns: number of issues found (0 = healthy)
# provider_doctor() {
#   local SERVICE="$1"
#   local issues=0
#
#   # Add provider-specific health checks here
#   # Example: verify API key is still valid, check account status, etc.
#
#   return $issues
# }
