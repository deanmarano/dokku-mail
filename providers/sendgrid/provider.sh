#!/usr/bin/env bash
# SendGrid provider - relay emails through SendGrid SMTP

PROVIDER_NAME="sendgrid"
PROVIDER_DISPLAY_NAME="SendGrid"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="API_KEY"
PROVIDER_OPTIONAL_CONFIG="FROM_DOMAIN"

SENDGRID_SMTP="smtp.sendgrid.net"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read config
  local API_KEY FROM_DOMAIN
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)
  FROM_DOMAIN=$(cat "$CONFIG_DIR/FROM_DOMAIN" 2>/dev/null || echo "*")

  if [[ -z "$API_KEY" ]]; then
    echo "!     Missing SendGrid API key. Run:"
    echo "      dokku mail:sendgrid:setup $SERVICE"
    return 1
  fi

  # SendGrid SMTP auth: username is literally "apikey", password is the API key
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "RELAYHOST=$SENDGRID_SMTP:587" \
    -e "RELAYHOST_USERNAME=apikey" \
    -e "RELAYHOST_PASSWORD=$API_KEY" \
    -e "ALLOWED_SENDER_DOMAINS=$FROM_DOMAIN" \
    -e "POSTFIX_smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination" \
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
    echo "       Run: dokku mail:sendgrid:setup $SERVICE"
    return 1
  fi

  # Validate API key format (should start with SG.)
  local API_KEY
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)
  if [[ ! "$API_KEY" =~ ^SG\. ]]; then
    echo "!     Invalid API key format (should start with SG.)"
    return 1
  fi

  return 0
}

provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local API_KEY
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)

  if [[ -z "$API_KEY" ]]; then
    echo "!     Missing SendGrid API key"
    return 1
  fi

  echo "       Verifying SendGrid configuration..."

  # Test SMTP connectivity
  if nc -z -w5 "$SENDGRID_SMTP" 587 2>/dev/null; then
    echo "       ✓ SMTP endpoint reachable"
  else
    echo "!     Cannot connect to $SENDGRID_SMTP:587"
    return 1
  fi

  # Verify API key via SendGrid API (optional)
  if command -v curl &>/dev/null; then
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $API_KEY" \
      "https://api.sendgrid.com/v3/user/profile" 2>/dev/null)

    case "$response" in
      200)
        echo "       ✓ API key valid"
        ;;
      401|403)
        echo "!     API key is invalid or lacks permissions"
        echo "       Ensure the key has 'Mail Send' permission"
        return 1
        ;;
      *)
        echo "       ? Could not verify API key (HTTP $response)"
        ;;
    esac
  else
    echo "       ✓ API key configured (install curl to verify)"
  fi

  echo "       Endpoint: $SENDGRID_SMTP:587"
  return 0
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local API_KEY FROM_DOMAIN
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "(not set)")
  FROM_DOMAIN=$(cat "$CONFIG_DIR/FROM_DOMAIN" 2>/dev/null || echo "*")

  # Mask API key
  if [[ "$API_KEY" != "(not set)" ]] && [[ ${#API_KEY} -gt 10 ]]; then
    API_KEY="${API_KEY:0:6}***${API_KEY: -4}"
  elif [[ "$API_KEY" != "(not set)" ]]; then
    API_KEY="***"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT (internal)"
  echo "       API Key: $API_KEY"
  echo "       From Domain: $FROM_DOMAIN"
  echo "       Endpoint: $SENDGRID_SMTP:587"
}

provider_doctor() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"
  local issues=0

  echo "-----> Checking SendGrid configuration..."

  local API_KEY FROM_DOMAIN
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "")
  FROM_DOMAIN=$(cat "$CONFIG_DIR/FROM_DOMAIN" 2>/dev/null || echo "*")

  if [[ -n "$API_KEY" ]]; then
    echo "       ✓ API key configured"
    if [[ "$API_KEY" =~ ^SG\. ]]; then
      echo "       ✓ API key format valid"
    else
      echo "       ✗ API key format invalid (should start with SG.)"
      ((issues++))
    fi
  else
    echo "       ✗ API key not configured"
    ((issues++))
  fi

  echo "       ✓ From domain: $FROM_DOMAIN"

  # Check SMTP connectivity
  echo "-----> Checking SendGrid connectivity..."
  if nc -z -w5 "$SENDGRID_SMTP" 587 2>/dev/null; then
    echo "       ✓ Can reach $SENDGRID_SMTP:587"
  else
    echo "       ✗ Cannot reach $SENDGRID_SMTP:587"
    ((issues++))
  fi

  # Check API key validity if curl available
  if [[ -n "$API_KEY" ]] && command -v curl &>/dev/null; then
    echo "-----> Checking API key validity..."
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $API_KEY" \
      "https://api.sendgrid.com/v3/user/profile" 2>/dev/null)

    case "$response" in
      200)
        echo "       ✓ API key valid"
        ;;
      401|403)
        echo "       ✗ API key is invalid or lacks permissions"
        ((issues++))
        ;;
      *)
        echo "       ? Could not verify API key (HTTP $response)"
        ;;
    esac
  fi

  return $issues
}
