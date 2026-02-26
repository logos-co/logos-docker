#!/bin/sh
set -e

# ---- Checks ----

missing=""

[ -z "$LOGOS_BLOCKCHAIN_PARAMETERS" ] && missing="$missing LOGOS_BLOCKCHAIN_PARAMETERS"
[ -z "$LOGOS_BLOCKCHAIN_CONFIG_PATH" ] && missing="$missing LOGOS_BLOCKCHAIN_CONFIG_PATH"

if [ -n "$missing" ]; then
  echo "ERROR: Missing required environment variables:$missing" >&2
  exit 1
fi

# ---- Run ----

exec ./logos/bin/logoscore \
  -m ./modules \
  #--load-modules waku_module,storage_module,logos_blockchain_module \
  --load-modules logos_blockchain_module \
  #-c "waku_module.initWaku(@waku_config.json)" \
  #-c "waku_module.startWaku()" \
  #-c "storage_module.init(@storage_config_test.json)" \
  #-c "storage_module.start()" \
  #-c "storage_module.importFiles('/tmp/storage_files')" \
  #-c "logos_blockchain_module.generate_user_config_from_str($LOGOS_BLOCKCHAIN_PARAMETERS)" \
  #-c "logos_blockchain_module.start($LOGOS_BLOCKCHAIN_CONFIG_PATH)"
  -c "logos_blockchain_module.name()"

