#!/usr/bin/env bash
# Mailgun provider - relay emails through Mailgun SMTP

PROVIDER_NAME="mailgun"
PROVIDER_DISPLAY_NAME="Mailgun"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="API_KEY DOMAIN"
PROVIDER_OPTIONAL_CONFIG="REGION"

# Mailgun SMTP endpoints
MAILGUN_US_SMTP="smtp.mailgun.org"
MAILGUN_EU_SMTP="smtp.eu.mailgun.org"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"
  local NETWORK="${MAIL_NETWORK:-dokku.mail.$SERVICE}"

  # Read config
  local API_KEY DOMAIN REGION
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)
  DOMAIN=$(cat "$CONFIG_DIR/DOMAIN" 2>/dev/null)
  REGION=$(cat "$CONFIG_DIR/REGION" 2>/dev/null || echo "us")

  if [[ -z "$API_KEY" ]] || [[ -z "$DOMAIN" ]]; then
    echo "!     Missing Mailgun configuration. Run:"
    echo "      dokku mail:mailgun:setup $SERVICE <domain>"
    return 1
  fi

  # Determine SMTP endpoint based on region
  local SMTP_HOST
  case "$REGION" in
    eu|EU|europe|EUROPE)
      SMTP_HOST="$MAILGUN_EU_SMTP"
      ;;
    *)
      SMTP_HOST="$MAILGUN_US_SMTP"
      ;;
  esac

  # Mailgun SMTP auth: username is postmaster@domain, password is API key
  local SMTP_USERNAME="postmaster@$DOMAIN"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network "$NETWORK" \
    -e "RELAYHOST=$SMTP_HOST:587" \
    -e "RELAYHOST_USERNAME=$SMTP_USERNAME" \
    -e "RELAYHOST_PASSWORD=$API_KEY" \
    -e "ALLOWED_SENDER_DOMAINS=*" \
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
    echo "       Run: dokku mail:mailgun:setup $SERVICE <domain>"
    return 1
  fi

  # Validate region if set
  local REGION
  REGION=$(cat "$CONFIG_DIR/REGION" 2>/dev/null || echo "")
  if [[ -n "$REGION" ]]; then
    case "$REGION" in
      us|US|eu|EU|europe|EUROPE) ;;
      *)
        echo "!     Invalid REGION value: $REGION"
        echo "       Valid values: us, eu"
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

  local API_KEY DOMAIN REGION
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)
  DOMAIN=$(cat "$CONFIG_DIR/DOMAIN" 2>/dev/null)
  REGION=$(cat "$CONFIG_DIR/REGION" 2>/dev/null || echo "us")

  if [[ -z "$API_KEY" ]] || [[ -z "$DOMAIN" ]]; then
    echo "!     Missing Mailgun configuration"
    return 1
  fi

  # Determine endpoint
  local SMTP_HOST API_BASE
  case "$REGION" in
    eu|EU|europe|EUROPE)
      SMTP_HOST="$MAILGUN_EU_SMTP"
      API_BASE="https://api.eu.mailgun.net/v3"
      ;;
    *)
      SMTP_HOST="$MAILGUN_US_SMTP"
      API_BASE="https://api.mailgun.net/v3"
      ;;
  esac

  echo "       Verifying Mailgun configuration..."

  # Test SMTP connectivity
  if nc -z -w5 "$SMTP_HOST" 587 2>/dev/null; then
    echo "       ✓ SMTP endpoint reachable ($SMTP_HOST)"
  else
    echo "!     Cannot connect to $SMTP_HOST:587"
    return 1
  fi

  # Verify API key (optional, requires curl)
  if command -v curl &>/dev/null; then
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
      --user "api:$API_KEY" \
      "$API_BASE/domains/$DOMAIN" 2>/dev/null)

    if [[ "$response" == "200" ]]; then
      echo "       ✓ API key valid"
      echo "       ✓ Domain $DOMAIN verified"
    elif [[ "$response" == "401" ]]; then
      echo "!     API key is invalid"
      return 1
    elif [[ "$response" == "404" ]]; then
      echo "!     Domain $DOMAIN not found in Mailgun"
      echo "       Add the domain at: https://app.mailgun.com/app/sending/domains"
      return 1
    else
      echo "       ? Could not verify API key (HTTP $response)"
    fi
  else
    echo "       ✓ API key configured (install curl to verify)"
  fi

  echo "       Endpoint: $SMTP_HOST:587"
  return 0
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local API_KEY DOMAIN REGION
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "(not set)")
  DOMAIN=$(cat "$CONFIG_DIR/DOMAIN" 2>/dev/null || echo "(not set)")
  REGION=$(cat "$CONFIG_DIR/REGION" 2>/dev/null || echo "us")

  # Mask API key
  if [[ "$API_KEY" != "(not set)" ]] && [[ ${#API_KEY} -gt 10 ]]; then
    API_KEY="${API_KEY:0:6}***${API_KEY: -4}"
  elif [[ "$API_KEY" != "(not set)" ]]; then
    API_KEY="***"
  fi

  # Determine endpoint
  local SMTP_HOST
  case "$REGION" in
    eu|EU|europe|EUROPE)
      SMTP_HOST="$MAILGUN_EU_SMTP"
      ;;
    *)
      SMTP_HOST="$MAILGUN_US_SMTP"
      ;;
  esac

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT (internal)"
  echo "       Domain: $DOMAIN"
  echo "       Region: $REGION"
  echo "       API Key: $API_KEY"
  echo "       Endpoint: $SMTP_HOST:587"
}

provider_doctor() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"
  local issues=0

  echo "-----> Checking Mailgun configuration..."

  local API_KEY DOMAIN REGION
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "")
  DOMAIN=$(cat "$CONFIG_DIR/DOMAIN" 2>/dev/null || echo "")
  REGION=$(cat "$CONFIG_DIR/REGION" 2>/dev/null || echo "us")

  if [[ -n "$API_KEY" ]]; then
    echo "       ✓ API key configured"
  else
    echo "       ✗ API key not configured"
    ((issues++))
  fi

  if [[ -n "$DOMAIN" ]]; then
    echo "       ✓ Domain: $DOMAIN"
  else
    echo "       ✗ Domain not configured"
    ((issues++))
  fi

  echo "       ✓ Region: $REGION"

  # Determine endpoint
  local SMTP_HOST API_BASE
  case "$REGION" in
    eu|EU|europe|EUROPE)
      SMTP_HOST="$MAILGUN_EU_SMTP"
      API_BASE="https://api.eu.mailgun.net/v3"
      ;;
    *)
      SMTP_HOST="$MAILGUN_US_SMTP"
      API_BASE="https://api.mailgun.net/v3"
      ;;
  esac

  # Check SMTP connectivity
  echo "-----> Checking Mailgun connectivity..."
  if nc -z -w5 "$SMTP_HOST" 587 2>/dev/null; then
    echo "       ✓ Can reach $SMTP_HOST:587"
  else
    echo "       ✗ Cannot reach $SMTP_HOST:587"
    ((issues++))
  fi

  # Check domain status via API if curl available
  if [[ -n "$API_KEY" ]] && [[ -n "$DOMAIN" ]] && command -v curl &>/dev/null; then
    echo "-----> Checking domain status..."
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
      --user "api:$API_KEY" \
      "$API_BASE/domains/$DOMAIN" 2>/dev/null)

    case "$response" in
      200)
        echo "       ✓ Domain verified in Mailgun"
        ;;
      401)
        echo "       ✗ API key is invalid"
        ((issues++))
        ;;
      404)
        echo "       ✗ Domain not found in Mailgun account"
        ((issues++))
        ;;
      *)
        echo "       ? Could not verify domain status (HTTP $response)"
        ;;
    esac
  fi

  return $issues
}
