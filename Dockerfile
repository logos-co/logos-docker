FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /app

# Build logos and package manager
RUN nix build github:logos-co/logos-liblogos --out-link ./logos
RUN nix build github:logos-co/logos-package-manager-module#cli --out-link ./package-manager

# Setup modules and config
RUN mkdir modules \
    && ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

# Run
CMD ["./logos/bin/logoscore", "-m", "./modules", "--load-modules", "waku_module", "-c", "waku_module.initWaku(@waku_config.json)", "-c", "waku_module.startWaku()"]
