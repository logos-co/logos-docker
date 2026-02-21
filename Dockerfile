FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /app

# Build logos and package manager
RUN nix build github:logos-co/logos-liblogos/properly-handle-portable-modules --out-link ./logos --refresh
RUN nix build github:logos-co/logos-package-manager-module/properly-handle-portable-modules#cli --out-link ./package-manager --refresh

# Build logos-waku-module LGX package
RUN nix bundle --bundler github:logos-co/nix-bundle-lgx github:logos-co/logos-waku-module#lib --out-link ./waku-module --refresh
# Build logos-storage-module LGX package
RUN nix bundle --bundler github:logos-co/nix-bundle-lgx github:logos-co/logos-storage-module#lib --out-link ./storage-module --refresh

# Setup modules and config
RUN mkdir modules \
    && ./package-manager/bin/lgpm --modules-dir ./modules/ install --file ./waku-module/logos-waku-module-lib.lgx
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

# Logos Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install --file ./storage-module/logos-storage-module-lib.lgx
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config_test.json .

# Run
CMD ["./logos/bin/logoscore", "-m", "./modules", "--load-modules", "waku_module,storage_module", "-c", "waku_module.initWaku(@waku_config.json)", "-c", "waku_module.startWaku()", "-c", "storage_module.init(@storage_config_test.json)", "-c", "storage_module.start()", "-c", "storage_module.importFiles('/tmp/storage_files')"]
