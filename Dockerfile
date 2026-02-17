FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /app

# Build logos and package manager
RUN nix build github:logos-co/logos-liblogos --out-link ./logos --refresh
RUN nix build github:logos-co/logos-package-manager-module#cli --out-link ./package-manager --refresh

# Setup modules and config
RUN mkdir modules \
    && ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

# Run
CMD ["./logos/bin/logoscore", "-m", "./modules", "--load-modules", "waku_module", "-c", "waku_module.initWaku(@waku_config.json)", "-c", "waku_module.startWaku()"]

# Logos Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config.json .

# Run
CMD ["./logos/bin/logoscore", "-m", "./modules", "--load-modules", "storage_module", "-c", "storage_module.init(@storage_config.json)", "-c", "storage_module.start()", "-c", "storage_module.importFiles(/tmp/storage_files)"]
