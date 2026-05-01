#!/usr/bin/env bash
# AWS SES provider - uses Postfix to relay emails to Amazon SES
# shellcheck source=../../functions
source "$PLUGIN_BASE_PATH/functions"

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
  local NETWORK="${MAIL_NETWORK:-dokku.mail.$SERVICE}"

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

  # shellcheck disable=SC2046
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network "$NETWORK" \
    $(get_expose_flags "$SERVICE") \
    -e "RELAYHOST=$SES_ENDPOINT:587" \
    -e "RELAYHOST_USERNAME=$SMTP_USERNAME" \
    -e "RELAYHOST_PASSWORD=$SMTP_PASSWORD" \
    -e "ALLOWED_SENDER_DOMAINS=*" \
    -e "POSTFIX_smtpd_recipient_restrictions=permit_mynetworks,reject_unauth_destination" \
    -e "POSTFIX_smtpd_tls_security_level=none" \
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
  for key in $PROVIDER_REQUIRED_CONFIG; do
    if [[ ! -f "$CONFIG_DIR/$key" ]] || [[ -z "$(cat "$CONFIG_DIR/$key" 2>/dev/null)" ]]; then
      echo "!     Missing required config: $key"
      ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "       Run: dokku mail:aws:setup $SERVICE <domain>"
    return 1
  fi

  # Validate AWS region format
  local AWS_REGION
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null)
  if [[ ! "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
    echo "!     Invalid AWS_REGION format: $AWS_REGION"
    return 1
  fi

  return 0
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

provider_doctor() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local CONFIG_DIR="$SERVICE_ROOT/provider-config"
  local issues=0

  echo "-----> Checking AWS SES configuration..."

  local SMTP_USERNAME SMTP_PASSWORD AWS_REGION SENDER_DOMAIN
  SMTP_USERNAME=$(cat "$CONFIG_DIR/SMTP_USERNAME" 2>/dev/null || echo "")
  SMTP_PASSWORD=$(cat "$CONFIG_DIR/SMTP_PASSWORD" 2>/dev/null || echo "")
  AWS_REGION=$(cat "$CONFIG_DIR/AWS_REGION" 2>/dev/null || echo "")
  SENDER_DOMAIN=$(cat "$CONFIG_DIR/SENDER_DOMAIN" 2>/dev/null || echo "")

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

  if [[ -n "$AWS_REGION" ]]; then
    echo "       ✓ AWS region: $AWS_REGION"
    if [[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
      echo "       ✓ Region format valid"
    else
      echo "       ✗ Region format invalid"
      ((issues++))
    fi
  else
    echo "       ✗ AWS region not configured"
    ((issues++))
  fi

  if [[ -n "$SENDER_DOMAIN" ]]; then
    echo "       ✓ Sender domain: $SENDER_DOMAIN"
  else
    echo "       ! Sender domain not configured (test emails may fail)"
  fi

  # Check SMTP connectivity
  if [[ -n "$AWS_REGION" ]]; then
    local SES_ENDPOINT="email-smtp.$AWS_REGION.amazonaws.com"
    echo "-----> Checking SES connectivity..."
    if nc -z -w5 "$SES_ENDPOINT" 587 2>/dev/null; then
      echo "       ✓ Can reach $SES_ENDPOINT:587"
    else
      echo "       ✗ Cannot reach $SES_ENDPOINT:587"
      ((issues++))
    fi
  fi

  # Extended AWS CLI checks (optional)
  if command -v aws &>/dev/null; then
    echo "       ✓ AWS CLI available"

    # Check SES identity
    if [[ -n "$SENDER_DOMAIN" ]] && [[ -n "$AWS_REGION" ]]; then
      echo "-----> Checking SES identity..."
      local IDENTITY_STATUS
      if IDENTITY_STATUS=$(aws sesv2 get-email-identity --email-identity "$SENDER_DOMAIN" --region "$AWS_REGION" 2>/dev/null); then
        echo "       ✓ SES identity exists: $SENDER_DOMAIN"

        # Check DKIM
        local DKIM_STATUS
        DKIM_STATUS=$(echo "$IDENTITY_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('DkimAttributes',{}).get('Status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
        if [[ "$DKIM_STATUS" == "SUCCESS" ]]; then
          echo "       ✓ DKIM verified"
        elif [[ "$DKIM_STATUS" == "PENDING" ]]; then
          echo "       ! DKIM pending verification"
        else
          echo "       ✗ DKIM status: $DKIM_STATUS"
          ((issues++))
        fi

        # Check if verified for sending
        local VERIFIED
        VERIFIED=$(echo "$IDENTITY_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('VerifiedForSendingStatus',False))" 2>/dev/null || echo "False")
        if [[ "$VERIFIED" == "True" ]]; then
          echo "       ✓ Domain verified for sending"
        else
          echo "       ✗ Domain not verified for sending"
          ((issues++))
        fi
      else
        echo "       ✗ SES identity not found: $SENDER_DOMAIN"
        ((issues++))
      fi
    fi

    # Check sandbox mode
    if [[ -n "$AWS_REGION" ]]; then
      echo "-----> Checking SES account status..."
      local ACCOUNT_STATUS
      if ACCOUNT_STATUS=$(aws sesv2 get-account --region "$AWS_REGION" 2>/dev/null); then
        local PRODUCTION_ACCESS
        PRODUCTION_ACCESS=$(echo "$ACCOUNT_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ProductionAccessEnabled',False))" 2>/dev/null || echo "False")
        if [[ "$PRODUCTION_ACCESS" == "True" ]]; then
          echo "       ✓ SES production access enabled"
        else
          echo "       ! SES in SANDBOX MODE - can only send to verified addresses"
        fi

        # Check sending quota
        local SEND_QUOTA
        SEND_QUOTA=$(echo "$ACCOUNT_STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin).get('SendQuota',{}); print(f\"{d.get('SentLast24Hours',0):.0f}/{d.get('Max24HourSend',0):.0f}\")" 2>/dev/null || echo "unknown")
        echo "       ✓ Send quota (24h): $SEND_QUOTA"
      else
        echo "       ? Cannot check SES account status (missing ses:GetAccount permission)"
      fi
    fi

    # Check IAM user
    echo "-----> Checking IAM user..."
    local IAM_USER="ses-smtp-user-dokku-mail-$SERVICE"
    if aws iam get-user --user-name "$IAM_USER" &>/dev/null; then
      echo "       ✓ IAM user exists: $IAM_USER"

      # Check access key matches
      local CURRENT_KEYS
      CURRENT_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null || echo "")
      if echo "$CURRENT_KEYS" | grep -q "$SMTP_USERNAME"; then
        echo "       ✓ Access key matches configured SMTP username"
      else
        echo "       ✗ Access key drift detected - configured key not found in IAM"
        echo "         Configured: $SMTP_USERNAME"
        echo "         IAM keys: $CURRENT_KEYS"
        echo "         Run: dokku mail:provider:reset $SERVICE && dokku mail:aws:setup $SERVICE $SENDER_DOMAIN"
        ((issues++))
      fi
    else
      echo "       ? IAM user not found: $IAM_USER (may have been created manually)"
    fi
  else
    echo "       ? AWS CLI not available - skipping extended AWS checks"
  fi

  return $issues
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
