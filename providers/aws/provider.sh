#!/usr/bin/env bash
# AWS SES provider - uses Postfix to relay emails to Amazon SES

PROVIDER_NAME="aws"
PROVIDER_DISPLAY_NAME="AWS SES"
PROVIDER_IMAGE="boky/postfix"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="25"
PROVIDER_REQUIRED_CONFIG="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION"

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  # Read config
  local AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
  AWS_ACCESS_KEY_ID=$(cat "$CONFIG_DIR/AWS_ACCESS_KEY_ID" 2>/dev/null)
  AWS_SECRET_ACCESS_KEY=$(cat "$CONFIG_DIR/AWS_SECRET_ACCESS_KEY" 2>/dev/null)
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null)

  if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]] || [[ -z "$AWS_REGION" ]]; then
    echo "!     Missing AWS configuration. Run:"
    echo "      dokku mail:provider:config $SERVICE AWS_ACCESS_KEY_ID=<key>"
    echo "      dokku mail:provider:config $SERVICE AWS_SECRET_ACCESS_KEY=<secret>"
    echo "      dokku mail:provider:config $SERVICE AWS_REGION=<region>"
    return 1
  fi

  # Generate SMTP password from IAM secret key
  local SMTP_PASSWORD
  SMTP_PASSWORD=$(generate_ses_smtp_password "$AWS_SECRET_ACCESS_KEY" "$AWS_REGION")

  local SES_ENDPOINT="email-smtp.$AWS_REGION.amazonaws.com"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -e "RELAYHOST=$SES_ENDPOINT:587" \
    -e "RELAYHOST_USERNAME=$AWS_ACCESS_KEY_ID" \
    -e "RELAYHOST_PASSWORD=$SMTP_PASSWORD" \
    -e "ALLOWED_SENDER_DOMAINS=*" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}

provider_get_smtp_port() {
  echo "$PROVIDER_SMTP_PORT"
}

provider_verify() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
  AWS_ACCESS_KEY_ID=$(cat "$CONFIG_DIR/AWS_ACCESS_KEY_ID" 2>/dev/null)
  AWS_SECRET_ACCESS_KEY=$(cat "$CONFIG_DIR/AWS_SECRET_ACCESS_KEY" 2>/dev/null)
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null)

  if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]] || [[ -z "$AWS_REGION" ]]; then
    echo "!     Missing AWS configuration"
    return 1
  fi

  echo "       Verifying AWS SES access..."

  # Try to get send quota using AWS CLI
  if command -v aws &>/dev/null; then
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION="$AWS_REGION"
    if aws ses get-send-quota &>/dev/null; then
      local QUOTA
      QUOTA=$(aws ses get-send-quota --output text)
      echo "       ✓ AWS SES credentials valid"
      echo "       Send quota: $QUOTA"
      return 0
    else
      echo "!     AWS SES access denied - check credentials and permissions"
      return 1
    fi
  else
    echo "       ⚠ AWS CLI not installed - cannot verify credentials"
    echo "       Assuming credentials are correct"
    return 0
  fi
}

provider_info() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"

  local AWS_ACCESS_KEY_ID AWS_REGION
  AWS_ACCESS_KEY_ID=$(cat "$CONFIG_DIR/AWS_ACCESS_KEY_ID" 2>/dev/null || echo "(not set)")
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null || echo "(not set)")

  # Mask the key
  if [[ "$AWS_ACCESS_KEY_ID" != "(not set)" ]]; then
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:0:4}***${AWS_ACCESS_KEY_ID: -4}"
  fi

  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Region: $AWS_REGION"
  echo "       Access Key: $AWS_ACCESS_KEY_ID"
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
