#!/usr/bin/env bash
# Generic SMTP provider - relay to any SMTP server

PROVIDER_NAME="smtp"
PROVIDER_DISPLAY_NAME="Generic SMTP"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD"
PROVIDER_OPTIONAL_CONFIG="SMTP_TLS FROM_DOMAIN"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read required config
  local SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null)
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null)
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null)
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null)

  # Read optional config
  local SMTP_TLS FROM_DOMAIN
  SMTP_TLS=$(cat "$CONFIG_DIR/SMTP_TLS" 2>/dev/null || echo "starttls")
  FROM_DOMAIN=$(cat "$CONFIG_DIR/FROM_DOMAIN" 2>/dev/null || echo "*")

  if [[ -z "$SMTP_HOST" ]] || [[ -z "$SMTP_PORT" ]] || [[ -z "$SMTP_USERNAME" ]] || [[ -z "$SMTP_PASSWORD" ]]; then
    echo "!     Missing SMTP configuration. Run:"
    echo "      dokku mail:smtp:setup $SERVICE"
    echo "  or configure manually:"
    echo "      dokku mail:provider:config $SERVICE SMTP_HOST=smtp.example.com"
    echo "      dokku mail:provider:config $SERVICE SMTP_PORT=587"
    echo "      dokku mail:provider:config $SERVICE SMTP_USERNAME=user"
    echo "      dokku mail:provider:config $SERVICE SMTP_PASSWORD=pass"
    return 1
  fi

  # Build environment variables
  local ENV_VARS=(
    -e "RELAYHOST=$SMTP_HOST:$SMTP_PORT"
    -e "RELAYHOST_USERNAME=$SMTP_USERNAME"
    -e "RELAYHOST_PASSWORD=$SMTP_PASSWORD"
    -e "ALLOWED_SENDER_DOMAINS=$FROM_DOMAIN"
    -e "POSTFIX_smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination"
  )

  # Handle TLS mode
  case "$SMTP_TLS" in
    starttls|STARTTLS)
      # Default behavior, nothing extra needed
      ;;
    ssl|SSL|smtps|SMTPS)
      ENV_VARS+=(-e "RELAYHOST_TLS_LEVEL=encrypt")
      ;;
    none|NONE|off|OFF)
      ENV_VARS+=(-e "RELAYHOST_TLS_LEVEL=none")
      ;;
  esac

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    "${ENV_VARS[@]}" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}

provider_get_smtp_port() {
  local SERVICE="$1"
  echo "$PROVIDER_SMTP_PORT"
}

provider_validate_config() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local errors=0

  # Check required config
  for key in $PROVIDER_REQUIRED_CONFIG; do
    if [[ ! -f "$CONFIG_DIR/$key" ]] || [[ -z "$(cat "$CONFIG_DIR/$key" 2>/dev/null)" ]]; then
      echo "!     Missing required config: $key"
      ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "       Run: dokku mail:smtp:setup $SERVICE"
    return 1
  fi

  # Validate SMTP_PORT is a number
  local SMTP_PORT
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null)
  if ! [[ "$SMTP_PORT" =~ ^[0-9]+$ ]]; then
    echo "!     SMTP_PORT must be a number, got: $SMTP_PORT"
    return 1
  fi

  # Validate TLS mode if set
  local SMTP_TLS
  SMTP_TLS=$(cat "$CONFIG_DIR/SMTP_TLS" 2>/dev/null || echo "")
  if [[ -n "$SMTP_TLS" ]]; then
    case "$SMTP_TLS" in
      starttls|STARTTLS|ssl|SSL|smtps|SMTPS|none|NONE|off|OFF) ;;
      *)
        echo "!     Invalid SMTP_TLS value: $SMTP_TLS"
        echo "       Valid values: starttls, ssl, none"
        return 1
        ;;
    esac
  fi

  return 0
}

provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local SMTP_HOST SMTP_PORT
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null)
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null)

  if [[ -z "$SMTP_HOST" ]] || [[ -z "$SMTP_PORT" ]]; then
    echo "!     Missing SMTP configuration"
    return 1
  fi

  echo "       Verifying connection to $SMTP_HOST:$SMTP_PORT..."

  if nc -z -w5 "$SMTP_HOST" "$SMTP_PORT" 2>/dev/null; then
    echo "       ✓ SMTP endpoint reachable"
    echo "       ✓ Credentials configured"
    echo "       Endpoint: $SMTP_HOST:$SMTP_PORT"
    return 0
  else
    echo "!     Cannot connect to $SMTP_HOST:$SMTP_PORT"
    echo "       Check that the host and port are correct"
    return 1
  fi
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_TLS FROM_DOMAIN
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null || echo "(not set)")
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null || echo "(not set)")
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null || echo "(not set)")
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null || echo "(not set)")
  SMTP_TLS=$(cat "$CONFIG_DIR/SMTP_TLS" 2>/dev/null || echo "starttls")
  FROM_DOMAIN=$(cat "$CONFIG_DIR/FROM_DOMAIN" 2>/dev/null || echo "*")

  # Mask password
  if [[ "$SMTP_PASSWORD" != "(not set)" ]] && [[ ${#SMTP_PASSWORD} -gt 10 ]]; then
    SMTP_PASSWORD="${SMTP_PASSWORD:0:4}***${SMTP_PASSWORD: -4}"
  elif [[ "$SMTP_PASSWORD" != "(not set)" ]]; then
    SMTP_PASSWORD="***"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT (internal)"
  echo "       Host: $SMTP_HOST"
  echo "       Port: $SMTP_PORT"
  echo "       Username: $SMTP_USERNAME"
  echo "       Password: $SMTP_PASSWORD"
  echo "       TLS Mode: $SMTP_TLS"
  echo "       From Domain: $FROM_DOMAIN"
}

provider_doctor() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"
  local issues=0

  echo "-----> Checking Generic SMTP configuration..."

  local SMTP_HOST SMTP_PORT SMTP_USERNAME SMTP_PASSWORD
  SMTP_HOST=$(cat "$CONFIG_DIR/SMTP_HOST" 2>/dev/null || echo "")
  SMTP_PORT=$(cat "$CONFIG_DIR/SMTP_PORT" 2>/dev/null || echo "")
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null || echo "")
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null || echo "")

  if [[ -n "$SMTP_HOST" ]]; then
    echo "       ✓ SMTP host: $SMTP_HOST"
  else
    echo "       ✗ SMTP host not configured"
    ((issues++))
  fi

  if [[ -n "$SMTP_PORT" ]]; then
    echo "       ✓ SMTP port: $SMTP_PORT"
  else
    echo "       ✗ SMTP port not configured"
    ((issues++))
  fi

  if [[ -n "$SMTP_USERNAME" ]]; then
    echo "       ✓ SMTP username configured"
  else
    echo "       ✗ SMTP username not configured"
    ((issues++))
  fi

  if [[ -n "$SMTP_PASSWORD" ]]; then
    echo "       ✓ SMTP password configured"
  else
    echo "       ✗ SMTP password not configured"
    ((issues++))
  fi

  # Check SMTP connectivity
  if [[ -n "$SMTP_HOST" ]] && [[ -n "$SMTP_PORT" ]]; then
    echo "-----> Checking SMTP connectivity..."
    if nc -z -w5 "$SMTP_HOST" "$SMTP_PORT" 2>/dev/null; then
      echo "       ✓ Can reach $SMTP_HOST:$SMTP_PORT"
    else
      echo "       ✗ Cannot reach $SMTP_HOST:$SMTP_PORT"
      ((issues++))
    fi
  fi

  return $issues
}
