#!/usr/bin/env bash
# AWS SES provider - uses Postfix to relay emails to Amazon SES

PROVIDER_NAME="aws"
PROVIDER_DISPLAY_NAME="AWS SES"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
# Use SMTP credentials from SES console (easier) or IAM credentials (auto-derive password)
PROVIDER_REQUIRED_CONFIG="SMTP_USERNAME SMTP_PASSWORD AWS_REGION"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read config
  local SMTP_USERNAME SMTP_PASSWORD AWS_REGION
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null)
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null)
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null)

  if [[ -z "$SMTP_USERNAME" ]] || [[ -z "$SMTP_PASSWORD" ]] || [[ -z "$AWS_REGION" ]]; then
    echo "!     Missing AWS SES configuration. Run:"
    echo "      dokku mail:provider:config $SERVICE SMTP_USERNAME=<username>"
    echo "      dokku mail:provider:config $SERVICE SMTP_PASSWORD=<password>"
    echo "      dokku mail:provider:config $SERVICE AWS_REGION=<region>"
    return 1
  fi

  local SES_ENDPOINT="email-smtp.$AWS_REGION.amazonaws.com"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "RELAYHOST=$SES_ENDPOINT:587" \
    -e "RELAYHOST_USERNAME=$SMTP_USERNAME" \
    -e "RELAYHOST_PASSWORD=$SMTP_PASSWORD" \
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

  local SMTP_USERNAME SMTP_PASSWORD AWS_REGION
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null)
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null)
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null)

  if [[ -z "$SMTP_USERNAME" ]] || [[ -z "$SMTP_PASSWORD" ]] || [[ -z "$AWS_REGION" ]]; then
    echo "!     Missing AWS SES configuration"
    return 1
  fi

  local SES_ENDPOINT="email-smtp.$AWS_REGION.amazonaws.com"

  echo "       Verifying connection to $SES_ENDPOINT..."

  # Test TCP connection to SES SMTP endpoint
  if nc -z -w5 "$SES_ENDPOINT" 587 2>/dev/null; then
    echo "       ✓ SES endpoint reachable"
    echo "       ✓ SMTP credentials configured"
    echo "       Endpoint: $SES_ENDPOINT:587"
    return 0
  else
    echo "!     Cannot connect to $SES_ENDPOINT:587"
    return 1
  fi
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local SMTP_USERNAME AWS_REGION
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null || echo "(not set)")
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null || echo "(not set)")

  # Mask the username
  if [[ "$SMTP_USERNAME" != "(not set)" ]]; then
    SMTP_USERNAME="${SMTP_USERNAME:0:4}***${SMTP_USERNAME: -4}"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Region: $AWS_REGION"
  echo "       SMTP Username: $SMTP_USERNAME"
  echo "       Endpoint: email-smtp.$AWS_REGION.amazonaws.com:587"
}

# Generate SES SMTP password from IAM secret access key
# Based on AWS documentation: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
generate_ses_smtp_password() {
  local SECRET_KEY="$1"
  local REGION="$2"

  # AWS SES SMTP password derivation algorithm
  local DATE="11111111"
  local SERVICE="ses"
  local TERMINAL="aws4_request"
  local MESSAGE="SendRawEmail"
  local VERSION_BYTE=$'\x04'

  # HMAC-SHA256 chain
  local kDate kRegion kService kTerminal kMessage signature

  kDate=$(echo -n "$DATE" | openssl dgst -sha256 -hmac "AWS4${SECRET_KEY}" -binary)
  kRegion=$(echo -n "$REGION" | openssl dgst -sha256 -hmac "$kDate" -binary)
  kService=$(echo -n "$SERVICE" | openssl dgst -sha256 -hmac "$kRegion" -binary)
  kTerminal=$(echo -n "$TERMINAL" | openssl dgst -sha256 -hmac "$kService" -binary)
  kMessage=$(echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$kTerminal" -binary)

  # Prepend version byte and base64 encode
  echo -n "${VERSION_BYTE}${kMessage}" | base64
}
