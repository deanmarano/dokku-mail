#!/usr/bin/env bash
# Mock provider - uses MailHog to capture emails (no external delivery)

PROVIDER_NAME="mock"
PROVIDER_DISPLAY_NAME="Mock (MailHog)"
PROVIDER_IMAGE="mailhog/mailhog"
PROVIDER_IMAGE_VERSION="latest"
PROVIDER_SMTP_PORT="1025"
PROVIDER_WEB_PORT="8025"
PROVIDER_REQUIRED_CONFIG=""

provider_create_container() {
  local SERVICE="$1"
  local CONTAINER_NAME="dokku.mail.$SERVICE"

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network bridge \
    -p "$PROVIDER_WEB_PORT:8025" \
    "$PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
}

provider_get_smtp_port() {
  local SERVICE="$1"
  echo "$PROVIDER_SMTP_PORT"
}

provider_validate_config() {
  local SERVICE="$1"
  # Mock provider has no required config
  return 0
}

provider_verify() {
  local SERVICE="$1"
  echo "       Mock provider is always ready"
  echo "       Emails are captured locally (not delivered externally)"
  echo "       Web UI: http://localhost:$PROVIDER_WEB_PORT"
  return 0
}

provider_info() {
  local SERVICE="$1"
  echo "       Provider: $PROVIDER_DISPLAY_NAME"
  echo "       Image: $PROVIDER_IMAGE:$PROVIDER_IMAGE_VERSION"
  echo "       SMTP Port: $PROVIDER_SMTP_PORT"
  echo "       Web UI: http://localhost:$PROVIDER_WEB_PORT"
  echo "       Mode: Capture only (no external delivery)"
}

provider_doctor() {
  local SERVICE="$1"
  local issues=0

  echo "-----> Checking mock provider..."
  echo "       ✓ Using mock provider (MailHog)"
  echo "       ✓ Web UI: http://localhost:$PROVIDER_WEB_PORT"
  echo "       ✓ Emails are captured locally (not delivered)"

  return $issues
}
