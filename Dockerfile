FROM nixos/nix:latest

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /app

# Build logos and package manager
RUN nix build github:logos-co/logos-liblogos --out-link ./logos --refresh
RUN nix build github:logos-co/logos-package-manager-module#cli --out-link ./package-manager --refresh

RUN mkdir modules

# Logos Delivery
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module

# Logos Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module

# Run
ENTRYPOINT ["./logos/bin/logoscore"]
