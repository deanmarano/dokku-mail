#!/usr/bin/env bash
# Resend provider - uses Postfix to relay emails to Resend

PROVIDER_NAME="resend"
PROVIDER_DISPLAY_NAME="Resend"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="API_KEY SENDER_DOMAIN"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read config
  local API_KEY SENDER_DOMAIN
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)
  SENDER_DOMAIN=$(cat "$CONFIG_DIR/SENDER_DOMAIN" 2>/dev/null)

  if [[ -z "$API_KEY" ]]; then
    echo "!     Missing Resend API key. Run:"
    echo "      dokku mail:resend:setup $SERVICE <domain>"
    return 1
  fi

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "RELAYHOST=smtp.resend.com:587" \
    -e "RELAYHOST_USERNAME=resend" \
    -e "RELAYHOST_PASSWORD=$API_KEY" \
    -e "ALLOWED_SENDER_DOMAINS=*" \
    -e "POSTFIX_smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}

provider_get_smtp_port() {
  echo "$PROVIDER_SMTP_PORT"
}

provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local API_KEY
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null)

  if [[ -z "$API_KEY" ]]; then
    echo "!     Missing Resend API key"
    return 1
  fi

  echo "       Verifying connection to smtp.resend.com..."

  if nc -z -w5 smtp.resend.com 587 2>/dev/null; then
    echo "       ✓ Resend SMTP endpoint reachable"
    echo "       ✓ API key configured"
    return 0
  else
    echo "!     Cannot connect to smtp.resend.com:587"
    return 1
  fi
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local API_KEY SENDER_DOMAIN
  API_KEY=$(cat "$CONFIG_DIR/API_KEY" 2>/dev/null || echo "(not set)")
  SENDER_DOMAIN=$(cat "$CONFIG_DIR/SENDER_DOMAIN" 2>/dev/null || echo "(not set)")

  # Mask the API key
  if [[ "$API_KEY" != "(not set)" ]]; then
    API_KEY="${API_KEY:0:6}***${API_KEY: -4}"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Sender Domain: $SENDER_DOMAIN"
  echo "       API Key: $API_KEY"
  echo "       Endpoint: smtp.resend.com:587"
}
