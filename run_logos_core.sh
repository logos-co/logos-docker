#!/bin/sh

echo "I am a logos-core node"

exec ./logos/bin/logoscore \
        -m ./modules \
        --load-modules waku_module,storage_module \
        -c "waku_module.initWaku(@/logos/cfg/delivery-config.json)" \
        -c "waku_module.startWaku()" \
        -c "storage_module.init(@/logos/cfg/storage-config.json)" \
        -c "storage_module.start()" \
        -c "storage_module.importFiles('/tmp/storage_files')"
