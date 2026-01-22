#!/usr/bin/env bash
# Provider loader - sources the appropriate provider based on service config

load_provider() {
  local SERVICE="$1"
  local SERVICE_ROOT="$PLUGIN_DATA_ROOT/$SERVICE"
  local PROVIDER

  if [[ -f "$SERVICE_ROOT/PROVIDER" ]]; then
    PROVIDER=$(cat "$SERVICE_ROOT/PROVIDER")
  else
    PROVIDER="mock"
  fi

  local PROVIDER_PATH="$PLUGIN_BASE_PATH/providers/$PROVIDER/provider.sh"
  if [[ -f "$PROVIDER_PATH" ]]; then
    source "$PROVIDER_PATH"
  else
    echo "!     Unknown provider: $PROVIDER"
    exit 1
  fi
}

list_providers() {
  for provider_dir in "$PLUGIN_BASE_PATH/providers"/*/; do
    local provider_name
    provider_name=$(basename "$provider_dir")
    # Skip _template directory
    [[ "$provider_name" == "_template" ]] && continue
    if [[ -f "$provider_dir/provider.sh" ]]; then
      echo "$provider_name"
    fi
  done
}
