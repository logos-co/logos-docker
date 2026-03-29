#!/bin/sh
set -e

# ---- Checks ----

missing=""

[ -z "$LOGOS_BLOCKCHAIN_PARAMETERS" ] && missing="$missing LOGOS_BLOCKCHAIN_PARAMETERS"
[ -z "$LOGOS_BLOCKCHAIN_CONFIG_PATH" ] && missing="$missing LOGOS_BLOCKCHAIN_CONFIG_PATH"
[ -z "$LOGOS_BLOCKCHAIN_DEPLOYMENT" ] && missing="$missing LOGOS_BLOCKCHAIN_DEPLOYMENT"

if [ -n "$missing" ]; then
  echo "ERROR: Missing required environment variables:$missing" >&2
  exit 1
fi

# ---- Generate config if missing ----

LOGOS_BLOCKCHAIN_GENERATE_USER_CONFIG_CMD=""

if [ ! -f "$LOGOS_BLOCKCHAIN_CONFIG_PATH" ]; then
  echo "[Blockchain] No user config found at $LOGOS_BLOCKCHAIN_CONFIG_PATH, generating..."
  LOGOS_BLOCKCHAIN_GENERATE_USER_CONFIG_CMD="-c liblogos_blockchain_module.generate_user_config_from_str('${LOGOS_BLOCKCHAIN_PARAMETERS}')"
else
  echo "[Blockchain] Using existing user config at $LOGOS_BLOCKCHAIN_CONFIG_PATH"
fi

# ---- Run ----

exec ./logos/bin/logoscore \
  -m ./modules \
  --load-modules waku_module,storage_module,liblogos_blockchain_module \
  -c "waku_module.initWaku(@waku_config.json)" \
  -c "waku_module.startWaku()" \
  -c "storage_module.init(@storage_config_test.json)" \
  -c "storage_module.start()" \
  -c "storage_module.importFiles('/tmp/storage_files')" \
  "$LOGOS_BLOCKCHAIN_GENERATE_USER_CONFIG_CMD" \
  -c "liblogos_blockchain_module.start('${LOGOS_BLOCKCHAIN_CONFIG_PATH}', '${LOGOS_BLOCKCHAIN_DEPLOYMENT}')"

